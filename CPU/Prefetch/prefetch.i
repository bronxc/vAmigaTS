;
; prefetch.i -- shared body of the CPU/Prefetch tests
;
; Question: does the one prefetch (np) of a long-running register-only
; instruction happen at the beginning or at the end of that instruction?
; The total cycle count doesn't answer it, but anyone else on the bus can.
;
; Every test defines, before including this file:
;
;   TESTINSTR   a macro that expands to exactly one instruction word,
;               e.g. divu.w d1,d2. d1 is the source, d2 the destination.
;   OP_SRC      the value loaded into d1 before each trial
;   OP_DST      the value loaded into d2 before each trial
;
;
; THE TRIAL
; ---------
;
; The code under test is laid out like this (the TESTINSTR word sits on a
; longword boundary):
;
;   sled:     nop ... nop       SLEDLEN nops, entered at a varying offset
;   sledend:  TESTINSTR         A
;             nop               A+2
;   target:   moveq #1,d0       A+4
;
; When TESTINSTR starts, the prefetch queue already holds A+2. The single
; bus read TESTINSTR performs is the one that fetches A+4. So the word at
; `target` is read exactly once, and it's read by the instruction under
; test. Whatever that read returns is what ends up in d0.
;
; Meanwhile, the Blitter rewrites `target`. It runs an A->D blit of
; BLITROWS rows, one word wide, with BLTDMOD = -2, so every row writes the
; same word: `target`. The first BLITROWS-1 rows write `moveq #1,d0`, which
; changes nothing. Only the last row writes `moveq #0,d0`. The Blitter is
; therefore just a timer that flips the instruction at a fixed point in
; time T after the BLTSIZE write. BLITROWS (BLITROWS_000 or BLITROWS_020)
; sets T.
;
; The CPU starts the Blitter, jumps into the nop sled, runs k nops, and
; executes TESTINSTR. If the read of `target` happens after T, d0 = 0. If
; it happens before T, d0 = 1.
;
; One stripe per k: stripe i runs k = i * STEP nops (STEP_000 or STEP_020).
; Moving down the screen, TESTINSTR starts later and later, so the stripes switch from
; "old" (fetched before T) to "new" (fetched after T) at some stripe. The
; position of that switch is what the test measures:
;
;   prefetch at the END of the instruction    -> the switch happens early,
;                                                because the read is late
;   prefetch at the START of the instruction  -> the switch happens later,
;                                                by roughly the
;                                                instruction's length
;                                                divided by the time per nop
;
;
; WHY EVERYTHING RUNS IN VERTICAL BLANK
; -------------------------------------
;
; As in CPU/68020/ICache: all trials run back to back in the level 3
; handler, once per frame, and none of them touch COLOR00. Each writes its
; answer into a data word of the Copper list, and the Copper paints the
; stripes afterwards. The handler's runtime is different for every stripe
; (that's the whole point of the sled), so it can't race the beam.
;
;
; COLOURS
; -------
;
;   blue    d0 = 1   target read BEFORE the Blitter changed it
;   yellow  d0 = 0   target read AFTER the Blitter changed it
;   red     d0 = -1  target never executed (should never be seen)
;   magenta anything else
;
; 68020: the instruction cache is switched off at the start of the handler
; (if exec says the CPU is a 68020), since a cached `target` would hide the
; Blitter's write entirely.
;

	include "../../../include/registers.i"
	include "../../../include/ministartup.i"

LVL3_INT_VECTOR     equ $6C

AttnFlags           equ 296             ; ExecBase->AttnFlags
AFB_68020           equ 1

LINE0               equ $28             ; first line of the top rule
TOPRULE             equ 2
STRIPELINES         equ 5
STRIPES             equ 32

HP_BASE             equ $01             ; HP $00, start of line

PENDING_COLOR       equ $444            ; dark grey: the handler never ran
RULE_COLOR          equ $FFF
FRAME_COLOR         equ $006

; Calibration. The 68020 in an A1200 runs at twice the clock of a 68000 in
; an A500 and needs far fewer cycles per instruction, while the Blitter
; runs at the same speed in both. So it gets its own timer length and its
; own step, picked at runtime from exec's AttnFlags. Both pairs can be
; overridden from the command line (-DSTEP_000=... and so on).

	ifnd    STEP_000
STEP_000            equ 2               ; nops added per stripe, 68000/68010
	endc
	ifnd    STEP_020
STEP_020            equ 2               ; nops added per stripe, 68020
	endc
	ifnd    BLITROWS_000
BLITROWS_000        equ 64              ; Blitter timer length, 68000/68010
	endc
	ifnd    BLITROWS_020
BLITROWS_020        equ 24              ; Blitter timer length, 68020
	endc

	ifgt    STEP_020-STEP_000
SLEDLEN             equ STRIPES*STEP_020
	else
SLEDLEN             equ STRIPES*STEP_000
	endc
	ifgt    BLITROWS_020-BLITROWS_000
BLITMAX             equ BLITROWS_020
	else
BLITMAX             equ BLITROWS_000
	endc

OLDOP               equ $7001           ; moveq #1,d0
NEWOP               equ $7000           ; moveq #0,d0
NOPOP               equ $4E71           ; nop

BLTCON0_VAL         equ $09F0           ; USEA, USED, D = A

STRIPEBLK           equ 16              ; bytes of Copper list per stripe
SLOTOFF             equ 6               ; offset of the colour word in a block

BLTWAIT	MACRO
	tst.b   DMACONR(a1)
.\@	btst    #6,DMACONR(a1)
	bne.b   .\@
	ENDM

MAIN:
	lea     CUSTOM,a1

	; Silence the machine
	move.w  #$0200,BPLCON0(a1)
	move.w  #$7FFF,INTENA(a1)
	move.w  #$7FFF,DMACON(a1)
	move.b  #$7F,$BFDD00
	move.b  #$7F,$BFED01

	; The only handler in this test
	lea     irq3(pc),a0
	move.l  a0,LVL3_INT_VECTOR

	lea     copper(pc),a0
	move.l  a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0

	move.w  #$82C0,DMACON(a1)       ; Copper and Blitter DMA, no BLTPRI
	move.w  #$C020,INTENA(a1)       ; master, VBlank (3)

.mainLoop:
	bra.b   .mainLoop


; ---------------------------------------------------------------------------
; Level 3, vertical blank -- every trial for every stripe runs here
;
; a1 = CUSTOM, a2 = sled entry point of the current trial, a3 = target,
; a4 = Blitter source, a5 = the Copper-list word to answer into,
; d5 = BLTSIZE, d6 = sled step, d7 = stripe counter,
; a0/d0 scratch, d1/d2 the operands of TESTINSTR.
; ---------------------------------------------------------------------------

irq3:
	movem.l d0-a6,-(sp)

	; Pick the calibration: d5 = BLTSIZE, d6 = sled step (bytes, negative),
	; a4 = first word of the Blitter's source (the table is read from its
	; end, so a shorter blit simply starts further in).
	move.w  #(BLITROWS_000<<6)|1,d5
	move.w  #-2*STEP_000,d6
	lea     blitsrc+2*(BLITMAX-BLITROWS_000)(pc),a4

	move.l  4.w,a0
	btst    #AFB_68020,AttnFlags+1(a0)
	beq.b   .not020

	; 68020: no instruction cache. MOVEC is privileged, which is why this
	; lives in the handler and not in MAIN.
	moveq   #0,d0
	movec   d0,cacr

	move.w  #(BLITROWS_020<<6)|1,d5
	move.w  #-2*STEP_020,d6
	lea     blitsrc+2*(BLITMAX-BLITROWS_020)(pc),a4
.not020:

	; Blitter registers that stay the same for all trials
	BLTWAIT
	move.w  #BLTCON0_VAL,BLTCON0(a1)
	move.w  #0,BLTCON1(a1)
	move.w  #$FFFF,BLTAFWM(a1)
	move.w  #$FFFF,BLTALWM(a1)
	move.w  #0,BLTAMOD(a1)
	move.w  #-2,BLTDMOD(a1)         ; every row hits the same word

	lea     target(pc),a3
	lea     sledend(pc),a2          ; stripe 0 runs no nops at all
	lea     slots(pc),a5
	addq.w  #SLOTOFF,a5             ; -> the first stripe's colour word
	moveq   #STRIPES-1,d7

trialLoop:
	; RESTORE: target is moveq #1,d0 again
	move.w  #OLDOP,(a3)

	; Arm the Blitter
	move.l  a4,BLTAPT(a1)
	move.l  a3,BLTDPT(a1)

	; Operands
	move.l  #OP_SRC,d1
	move.l  #OP_DST,d2
	moveq   #-1,d0

	; GO: start the Blitter and enter the sled
	move.w  d5,BLTSIZE(a1)
	jmp     (a2)

	cnop    0,4
sled:
	dcb.w   SLEDLEN,NOPOP
sledend:
	TESTINSTR
	nop
target:
	moveq   #1,d0                   ; <- the Blitter's target

	BLTWAIT

	; The answer is the colour. It goes into the Copper list.
	lea     palette(pc),a0
	addq.w  #1,d0                   ; -1 -> 0, 0 -> 1, 1 -> 2
	cmp.w   #3,d0
	bls.b   .inRange
	moveq   #3,d0
.inRange:
	add.w   d0,d0
	move.w  (a0,d0.w),(a5)

	adda.w  d6,a2                   ; next stripe: a few more nops
	lea     STRIPEBLK(a5),a5
	dbra    d7,trialLoop

	move.w  #$0020,INTREQ(a1)
	move.w  #$0020,INTREQ(a1)
	movem.l (sp)+,d0-a6
	rte

	; TESTINSTR must be one word on a longword boundary (on the 68020 the
	; longword holding target must not have been fetched before TESTINSTR
	; runs), and the stripe loop must not step out of the sled.
	ifne    (sledend-sled)&3
	FAIL    "TESTINSTR is not longword aligned"
	endc
	ifne    target-sledend-4
	FAIL    "TESTINSTR must be exactly one word"
	endc

palette:
	dc.w    $F00                    ; d0 = -1  red:     target not executed
	dc.w    $FF0                    ; d0 =  0  YELLOW:  read after the blit
	dc.w    $00F                    ; d0 =  1  BLUE:    read before the blit
	dc.w    $F0F                    ; other    magenta

blitsrc:
	dcb.w   BLITMAX-1,OLDOP
	dc.w    NEWOP


; ---------------------------------------------------------------------------
; The Copper list
; ---------------------------------------------------------------------------

copper:
	dc.w    BPLCON0,$0200
	dc.w    COLOR00,FRAME_COLOR

CLINE   set     LINE0

	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00,RULE_COLOR
CLINE   set     CLINE+TOPRULE

slots:
	rept    STRIPES

	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00
	dc.w    PENDING_COLOR           ; <- the word the handler rewrites
CLINE   set     CLINE+STRIPELINES

	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00,RULE_COLOR
CLINE   set     CLINE+1

	endr

slotsend:

	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00,FRAME_COLOR

	ifne    (slotsend-slots)-(STRIPES*STRIPEBLK)
	FAIL    "STRIPEBLK does not match the Copper list's stripe block"
	endc

	ifgt    CLINE-255
	FAIL    "the band runs past raster line 255"
	endc

	dc.l    $FFFFFFFE
