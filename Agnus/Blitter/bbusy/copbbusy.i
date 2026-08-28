	include "../../../../include/registers.i"
	include "../../../../include/ministartup.i"

;
; copbbusy -- BBUSY timing with the CPU taken out of the measurement.
;
; This is the bbusy test with one thing changed: the Blitter is started by
; the Copper, not by the CPU.
;
; The bbusyX tests raise a Copper interrupt, and the handler sets the
; background colour, writes BLTSIZE, spins on DMACONR bit 6 and repaints
; when it clears. The bar that produces is the Blitter's behaviour plus the
; CPU's -- instruction timing, interrupt latency, and every bus cycle the
; spin loop steals from the Blitter while it waits. Comparing two emulators
; on that picture compares their CPUs as much as their Blitters, which is a
; problem when the question is about the Blitter.
;
; Here the Copper does all of it:
;
;   dc.w    COLOR00,COLn        ; bar starts
;   dc.w    BLTSIZE,BLTSIZEn    ; start the blit  (needs CDANG)
;   dc.w    $0001,$7FFE         ; wait for BBUSY  (BFD clear)
;   dc.w    COLOR00,$FFF
;   dc.w    COLOR00,$000        ; bar ends
;
; The WAIT compares against VP=0, HP=0, which every position already
; satisfies, so the Blitter going idle is the only thing it waits for. That
; couples the Copper straight to BBUSY with no software in between, and the
; bar length is Blitter time and Copper overhead only.
;
; The CPU is used once per frame, in the vertical blank handler, to set the
; Blitter up -- pointers, modulos, BLTCON -- exactly as bbusy's prepareblit
; does. It then executes STOP and sleeps until the next vertical blank.
;
; STOP rather than a loop: a stopped 68000 issues no bus cycles at all, so
; it cannot steal a slot from the Blitter or shift its timing by a single
; cycle. A tight loop would still fetch, and on a 68000 there is no
; instruction cache to fetch from. STOP is exact on every CPU this suite
; runs on, and it needs no cache, no alignment and no assumptions.
;
; The stack pointer is reset at the top of the handler. The CPU is woken by
; an interrupt and stopped again without ever returning, so the exception
; frames would otherwise pile up for as long as the test runs.
;
; There is no synccpu here and no magenta bar: nothing in the measurement
; depends on where the CPU happens to be, so there is nothing to sync.
;
; Each bar's WAIT is placed well inside the visible screen (see HPOS below),
; not at the left edge, so black is visible before it starts. That gives a
; second thing to check: the moment the bar's colour first appears is itself
; a Blitter-launch-latency measurement, exactly as the moment BBUSY clears
; (marked by the brief white flash) is a BBUSY-release measurement. A
; picture is: black, then colour for the blit's duration, then one white
; line marking the instant BBUSY cleared, then black again.
;

LVL3_INT_VECTOR		equ $6c

COL1                equ $FD3
COL2                equ $FC4
COL3                equ $FB5
COL4                equ $FA6
COL5                equ $F97
COL6                equ $F88

COL1_2              equ $E89
COL2_2              equ $D8A
COL3_2              equ $C8B
COL4_2              equ $B8C
COL5_2              equ $A8D
COL6_2              equ $98E

; The bar-start WAIT's horizontal position. Chosen so the bar begins inside
; the visible screen, with black to its left -- rather than at $11, which
; sits before the display window and so is already showing the bar's colour
; by the time the border becomes visible, leaving no black margin at all.
;
; This must stay ODD. Bit 0 of a Copper WAIT's first word is not part of
; the horizontal compare value; it is fixed at 1 to mark the instruction as
; a WAIT rather than a MOVE (whose first word is always an even register
; address). Every other HP constant in this suite (HP_BASE, HP_IRQ, and the
; original HPOS) already follows this. An even value here does not fail to
; assemble -- it assembles into something that is no longer a WAIT at the
; intended position, and the effect is not a shifted bar but a garbled one:
; measured directly, $20/$30/$40/$50/$80 all left rows colliding into each
; other instead of landing on their own raster lines.
HPOS                equ $41

; One measurement: colour, start the blit, wait for BBUSY, colour back.
BLIT	MACRO
	dc.w    (\1)<<8|HPOS,$FFFE
	dc.w    COLOR00,\2
	dc.w    BLTSIZE,\3
	dc.w    $0001,$7FFE
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	ENDM

MAIN:
	lea     CUSTOM,a1
	lea     CUSTOM,a6

	; Disable interrupts, DMA and bitplanes
	move.w  #$7FFF,INTENA(a1)
	move.w  #$7FFF,DMACON(a1)
	move.w  #$200,BPLCON0(a1)

	; Disable CIA interrupts
	move.b  #$7F,$BFDD00  ; CIA B
	move.b  #$7F,$BFED01  ; CIA A

	; Setup bitplane pointers
	lea     bitplanes(pc),a2
	lea     copper(pc),a3
	moveq	#5,d0
.bitplaneloop:
	move.l 	a2,d1
	move.w	d1,2(a3)
	swap	d1
	move.w  d1,6(a3)
	addq	#8,a3
	dbra	d0,.bitplaneloop

	; Set up playfield
	move.w  #$2C81,DIWSTRT(a1)
	move.w	#$572C,DIWSTOP(a1)
	move.w	#$0,BPL1MOD(a1)
	move.w	#$0,BPL2MOD(a1)

	; Install the only interrupt handler this test needs
	lea	    irq3(pc),a3
 	move.l	a3,LVL3_INT_VECTOR

	; Setup Copper
	lea	    copper(pc),a0
	move.l	a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0
	move.w  #$8003,COPCON(a1)   ; Allow Copper to write Blitter registers

	; Enable DMA
	move.w	#$8040,DMACON(a1)   ; Blitter DMA
	move.w	#$8080,DMACON(a1)   ; Copper DMA
	move.w	#$8100,DMACON(a1)   ; Bitplane DMA
	move.w	#$8200,DMACON(a1)   ; DMAEN
	move.w	#$8400,DMACON(a1)   ; BLTPRI

	; Enable the vertical blank interrupt only
	move.w	#$C020,INTENA(a1)

.wait:
	bra.b	.wait               ; until the first vertical blank


; ---------------------------------------------------------------------------
; Vertical blank: set the Blitter up for this frame, then get off the bus.
; ---------------------------------------------------------------------------

irq3:
	lea     sstack,a7           ; the handler never returns; keep the stack
	lea     CUSTOM,a1           ; bounded
	move.w  #$0020,INTREQ(a1)   ; acknowledge

	bsr     prepareblit

	stop    #$2000              ; no bus cycles until the next vertical blank

prepareblit:
	bsr     blitWait
	move.w  #BLIT_BLTCON1,d0
	btst    #0,d0
	bne     .prepareline

	; Prepare the copy Blitter
	move.w  #BLIT_BLTCON0,BLTCON0(a1)
	move.w  #BLIT_BLTCON1,BLTCON1(a1)
	move.l  #$ffffffff,BLTAFWM(a1)
	move.w  #0,BLTAMOD(a1)
	move.w  #0,BLTBMOD(a1)
	move.w  #0,BLTCMOD(a1)
	move.w  #0,BLTDMOD(a1)
	move.l  #spare,BLTAPTH(a1)
	move.l  #spare,BLTBPTH(a1)
	move.l  #spare,BLTCPTH(a1)
	move.l  #spare,BLTDPTH(a1)
	rts

.prepareline:
	; Prepare the line Blitter
	move.w  #BLIT_BLTCON0,BLTCON0(a1)
	move.w  #BLIT_BLTCON1,BLTCON1(a1)
	move.l  #$ffffffff,BLTAFWM(a1)
	move.w  #40,BLTCMOD(a1)
	move.w  #40,BLTDMOD(a1)
	move.w  #-100,BLTAPTL(a1)
	move.w  #-200,BLTAMOD(a1)
	move.w  #0,BLTBMOD(a1)
	move.w  #$8000,BLTADAT(a1)
	move.l  #spare,BLTBPTH(a1)
	move.l  #spare,BLTCPTH(a1)
	move.l  #spare,BLTDPTH(a1)
	rts

blitWait:
	tst     DMACONR(a1)         ; for compatibility
.waitblit:
	btst    #6,DMACONR(a1)
	bne.s   .waitblit
	rts


; ---------------------------------------------------------------------------
; The copper list
; ---------------------------------------------------------------------------

copper:
	dc.w	BPL1PTL,0
	dc.w	BPL1PTH,0
	dc.w	BPL2PTL,0
	dc.w	BPL2PTH,0
	dc.w	BPL3PTL,0
	dc.w	BPL3PTH,0
	dc.w	BPL4PTL,0
	dc.w	BPL4PTH,0
	dc.w	BPL5PTL,0
	dc.w	BPL5PTH,0
	dc.w	BPL6PTL,0
	dc.w	BPL6PTH,0

	dc.w    DDFSTRT,$38
	dc.w    DDFSTOP,$D0
	dc.w    BPLCON0, (0<<12)|$200

    ;
    ; Section 1
    ;

  	dc.w    $4039, $FFFE
	include "../copperline.i"
	dc.w    BPLCON0, (0<<12)|$200
	BLIT    $42,COL1,BLTSIZE1
	BLIT    $44,COL2,BLTSIZE2
	BLIT    $46,COL3,BLTSIZE3
	BLIT    $48,COL4,BLTSIZE4
	BLIT    $4A,COL5,BLTSIZE5
	BLIT    $4C,COL6,BLTSIZE6

    ;
    ; Section 2
    ;

  	dc.w    $5039, $FFFE
	include "../copperline.i"
	dc.w    BPLCON0, (0<<12)|$200
	BLIT    $52,COL1_2,BLTSIZE1
	BLIT    $54,COL2_2,BLTSIZE2
	BLIT    $56,COL3_2,BLTSIZE3
	BLIT    $58,COL4_2,BLTSIZE4
	BLIT    $5A,COL5_2,BLTSIZE5
	BLIT    $5C,COL6_2,BLTSIZE6

    ;
    ; Section 3
    ;

  	dc.w    $6039, $FFFE
	include "../copperline.i"
	dc.w    BPLCON0, (1<<12)|$200
	BLIT    $62,COL1,BLTSIZE1
	BLIT    $64,COL2,BLTSIZE2
	BLIT    $66,COL3,BLTSIZE3
	BLIT    $68,COL4,BLTSIZE4
	BLIT    $6A,COL5,BLTSIZE5
	BLIT    $6C,COL6,BLTSIZE6

    ;
    ; Section 4
    ;

  	dc.w    $7039, $FFFE
	include "../copperline.i"
	dc.w    BPLCON0, (1<<12)|$200
	BLIT    $72,COL1_2,BLTSIZE1
	BLIT    $74,COL2_2,BLTSIZE2
	BLIT    $76,COL3_2,BLTSIZE3
	BLIT    $78,COL4_2,BLTSIZE4
	BLIT    $7A,COL5_2,BLTSIZE5
	BLIT    $7C,COL6_2,BLTSIZE6

    ;
    ; Section 5
    ;

  	dc.w    $8039, $FFFE
	include "../copperline.i"
	dc.w    BPLCON0, (2<<12)|$200
	BLIT    $82,COL1,BLTSIZE1
	BLIT    $84,COL2,BLTSIZE2
	BLIT    $86,COL3,BLTSIZE3
	BLIT    $88,COL4,BLTSIZE4
	BLIT    $8A,COL5,BLTSIZE5
	BLIT    $8C,COL6,BLTSIZE6

    ;
    ; Section 6
    ;

  	dc.w    $9039, $FFFE
	include "../copperline.i"
	dc.w    BPLCON0, (2<<12)|$200
	BLIT    $92,COL1_2,BLTSIZE1
	BLIT    $94,COL2_2,BLTSIZE2
	BLIT    $96,COL3_2,BLTSIZE3
	BLIT    $98,COL4_2,BLTSIZE4
	BLIT    $9A,COL5_2,BLTSIZE5
	BLIT    $9C,COL6_2,BLTSIZE6

    ;
    ; Section 7
    ;

  	dc.w    $A039, $FFFE
	include "../copperline.i"
	dc.w    BPLCON0, (3<<12)|$200
	BLIT    $A2,COL1,BLTSIZE1
	BLIT    $A4,COL2,BLTSIZE2
	BLIT    $A6,COL3,BLTSIZE3
	BLIT    $A8,COL4,BLTSIZE4
	BLIT    $AA,COL5,BLTSIZE5
	BLIT    $AC,COL6,BLTSIZE6

    ;
    ; Section 8
    ;

  	dc.w    $B039, $FFFE
	include "../copperline.i"
	dc.w    BPLCON0, (3<<12)|$200
	BLIT    $B2,COL1_2,BLTSIZE1
	BLIT    $B4,COL2_2,BLTSIZE2
	BLIT    $B6,COL3_2,BLTSIZE3
	BLIT    $B8,COL4_2,BLTSIZE4
	BLIT    $BA,COL5_2,BLTSIZE5
	BLIT    $BC,COL6_2,BLTSIZE6

    ;
    ; Section 9
    ;

  	dc.w    $C039, $FFFE
	include "../copperline.i"
	dc.w    BPLCON0, (4<<12)|$200
	BLIT    $C2,COL1,BLTSIZE1
	BLIT    $C4,COL2,BLTSIZE2
	BLIT    $C6,COL3,BLTSIZE3
	BLIT    $C8,COL4,BLTSIZE4
	BLIT    $CA,COL5,BLTSIZE5
	BLIT    $CC,COL6,BLTSIZE6

    ;
    ; Section 10
    ;

  	dc.w    $D039, $FFFE
	include "../copperline.i"
	dc.w    BPLCON0, (4<<12)|$200
	BLIT    $D2,COL1_2,BLTSIZE1
	BLIT    $D4,COL2_2,BLTSIZE2
	BLIT    $D6,COL3_2,BLTSIZE3
	BLIT    $D8,COL4_2,BLTSIZE4
	BLIT    $DA,COL5_2,BLTSIZE5
	BLIT    $DC,COL6_2,BLTSIZE6

	; Cross vertical boundary
	dc.w    $ffdf,$fffe

	dc.l    $fffffffe

	ds.l    64
sstack:
spare:
	ds.w    1024,$00
bitplanes:
	ds.b    32768,$00
