;
; cacheflush -- a cache line filled immediately behind a straddling MOVEC
; does not survive the call that filled it.
;
; This is hardware behaviour that no reading of the 68020 documentation
; predicts. It was found by comparing icache against a real Amiga 1200 and
; narrowed over thirteen probe disks. It is in the suite because vAmiga now
; models it, and because getting here cost enough that it should not be free
; to regress.
;
;
; THE BEHAVIOUR
; -------------
;
; A cache entry covers exactly one longword-aligned longword, so one fetch
; can never fill two entries. But a four byte instruction placed at an odd
; word SPANS two entries and needs two fetches to read. `movec Dn,cacr` is
; four bytes, so it straddles exactly when it sits on an odd word.
;
; On a real 68EC020, a line filled by a JSR's target fetch fails to stay
; valid when BOTH
;
;   - nothing separates the CACR write that cleared the cache from the JSR,
;     so the call runs in the instruction immediately behind the flush, and
;   - that MOVEC straddles a longword boundary.
;
; It is the flushing MOVEC's alignment that decides this, not the JSR's --
; which is what stripes 19-24 below exist to establish, because the two
; cannot be told apart otherwise: MOVEC and an adjacent JSR are both four
; bytes, so with nothing between them they always share alignment.
;
; The likely reading is that a straddling MOVEC must fetch the following
; longword to complete itself, so the words the next instruction needs are
; already in the pipe -- and already cached -- when the flush runs. A real
; three-word 68020 prefetch pipe would probably produce this on its own.
; Moira's queue is two words wide, the 68000 shape, for every core, so it
; stands in for that with an explicit flag in execJsr.
;
;
; WHAT THE PICTURE SHOWS
; ----------------------
;
; The stub, the prime/test recipe and the two colours are icache's, so read
; that test first. Yellow means the CPU executed the instruction just
; written; black means it executed the cached one.
;
; JSR comes in three lengths, which is what breaks the tie:
;
;   jsr (d16,PC)   4 bytes   straddles only at an odd word
;   jsr (xxx).L    6 bytes   straddles at ANY alignment
;   jsr (An)       2 bytes   never straddles
;
;   stripes 13-15  movec aligned    jsr (d16,PC) aligned    black
;   stripes 16-18  movec straddles  jsr (d16,PC) straddles  YELLOW
;   stripes 19-21  movec ALIGNED    jsr (xxx).L  STRADDLES  black
;   stripes 22-24  movec STRADDLES  jsr (An)     aligned    YELLOW
;
; The last two are the discriminating pair. A JSR that cannot straddle
; still loses the line behind a straddling MOVEC; a JSR that always
; straddles keeps it behind an aligned one. Confirmed against an Amiga 1200
; -- cacheflush_A1200.jpeg in this directory.
;
; Stripes 1-3 are reference swatches: a never-written grey, then the exact
; BLACK and YELLOW a trial can produce. They exist because reading colour
; off a photograph of a CRT is unreliable -- this monitor renders $006 with
; a blue channel of 235 where linear would give 102 -- so an ambiguous
; stripe can be compared against known ones in the same frame at the same
; exposure. An earlier probe was misread for want of them, and a conclusion
; drawn from it had to be retracted.
;
; Everything runs in the level 1 handler; results reach the screen through
; the Copper list at the next vertical blank, as in icache.
;
	include "../../../../include/registers.i"
	include "../../../../include/ministartup.i"

LVL1_INT_VECTOR     equ $64
LVL3_INT_VECTOR     equ $6C

LINE0               equ $28
TOPRULE             equ 2
STRIPELINES         equ 7
STRIPES             equ 24
TRIALS              equ 12

HP_BASE             equ $01
HP_IRQ              equ $E1

PENDING_COLOR       equ $444
RULE_COLOR          equ $FFF
FRAME_COLOR         equ $006

BLACK               equ $0000
YELLOW              equ $0FF0

CACR_PRIME          equ $0009
CACR_ON             equ $0001

STRIPEBLK           equ 24
SLOTOFF             equ 6

MAIN:
	lea     CUSTOM,a1

	move.w  #$0200,BPLCON0(a1)
	move.w  #$7FFF,INTENA(a1)
	move.w  #$7FFF,DMACON(a1)
	move.b  #$7F,$BFDD00
	move.b  #$7F,$BFED01

	lea     irq1(pc),a0
	move.l  a0,LVL1_INT_VECTOR
	lea     irq3(pc),a0
	move.l  a0,LVL3_INT_VECTOR

	lea     stub(pc),a2
	addq.w  #2,a2
	lea     scratch(pc),a3
	lea     vartab(pc),a4
	lea     results(pc),a5

	lea     copper(pc),a0
	move.l  a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0

	move.w  #$8280,DMACON(a1)
	move.w  #$C024,INTENA(a1)

.mainLoop:
	bra.b   .mainLoop

scratch:
	dc.w    PENDING_COLOR

	cnop    0,4
span:
stub:
	move.w  #$BEEF,(a3)
	rts

irq1:
	move.l  (a4)+,a0
	jmp     (a0)

; --- W0: movec aligned, jsr (d16,PC) aligned -- control, expect black ---
	cnop    0,4
V0:
	nop                             ; lead: puts movec and jsr on longwords
	move.w  #BLACK,(a2)
	move.w  #CACR_PRIME,d0
	movec   d0,cacr                 ; aligned
	jsr     stub(pc)                ; 4 bytes, aligned -> no straddle
	move.w  #CACR_ON,d0
	movec   d0,cacr
	move.w  #YELLOW,(a2)
	jsr     stub(pc)
	move.w  (a3),(a5)+
	move.w  #$0004,INTREQ(a1)
	rte

; --- W1: movec straddles, jsr (d16,PC) straddles -- control, expect yellow ---
	cnop    0,4
V1:
	move.w  #BLACK,(a2)
	move.w  #CACR_PRIME,d0
	movec   d0,cacr                 ; straddles
	jsr     stub(pc)                ; 4 bytes at an odd word -> straddles
	move.w  #CACR_ON,d0
	movec   d0,cacr
	move.w  #YELLOW,(a2)
	jsr     stub(pc)
	move.w  (a3),(a5)+
	move.w  #$0004,INTREQ(a1)
	rte

; --- W2: movec ALIGNED, jsr (xxx).L STRADDLES -- decides ---------------
	cnop    0,4
V2:
	nop                             ; lead
	move.w  #BLACK,(a2)
	move.w  #CACR_PRIME,d0
	movec   d0,cacr                 ; aligned
	jsr     (stub).l                ; 6 bytes -> straddles at any alignment
	move.w  #CACR_ON,d0
	movec   d0,cacr
	move.w  #YELLOW,(a2)
	jsr     stub(pc)
	move.w  (a3),(a5)+
	move.w  #$0004,INTREQ(a1)
	rte

; --- W3: movec STRADDLES, jsr (An) aligned -- decides ------------------
	cnop    0,4
V3:
	lea     stub(pc),a0             ; the target, reached through a register
	move.w  #BLACK,(a2)
	move.w  #CACR_PRIME,d0
	movec   d0,cacr                 ; straddles
	jsr     (a0)                    ; 2 bytes -> cannot straddle
	move.w  #CACR_ON,d0
	movec   d0,cacr
	move.w  #YELLOW,(a2)
	jsr     (a0)
	move.w  (a3),(a5)+
	move.w  #$0004,INTREQ(a1)
	rte

spanend:
	ifgt    (spanend-span)-250
	FAIL    "stub and the four blocks span 256 bytes or more: they can alias"
	endc

vartab:
	dc.l    V0,V0,V0
	dc.l    V1,V1,V1
	dc.l    V2,V2,V2
	dc.l    V3,V3,V3


irq3:
	lea     slots(pc),a0
	move.w  #PENDING_COLOR,SLOTOFF+0*STRIPEBLK(a0)
	move.w  #BLACK,SLOTOFF+1*STRIPEBLK(a0)
	move.w  #YELLOW,SLOTOFF+2*STRIPEBLK(a0)

	lea     SLOTOFF+12*STRIPEBLK(a0),a0
	lea     results(pc),a4
	moveq   #TRIALS-1,d7
.publish:
	move.w  (a4)+,(a0)
	lea     STRIPEBLK(a0),a0
	dbra    d7,.publish

	lea     vartab(pc),a4
	lea     results(pc),a5

	move.w  #$0020,INTREQ(a1)
	rte


copper:
	dc.w    BPLCON0,$0200
	dc.w    COLOR00,FRAME_COLOR

CLINE   set     LINE0

	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00,RULE_COLOR
CLINE   set     CLINE+TOPRULE

slots:
	rept    TRIALS
	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00
	dc.w    PENDING_COLOR
	dc.w    ((CLINE<<8)|HP_IRQ),$FFFE
	dc.w    INTREQ,$8004
CLINE   set     CLINE+STRIPELINES
	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00,RULE_COLOR
CLINE   set     CLINE+1
	endr

	rept    STRIPES-TRIALS
	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00
	dc.w    PENDING_COLOR
	dc.w    ((CLINE<<8)|HP_IRQ),$FFFE
	dc.w    INTREQ,$0004
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

results:
	dcb.w   64,PENDING_COLOR
