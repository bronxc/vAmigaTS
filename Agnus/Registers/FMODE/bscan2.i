; bscan2.i -- shared body for the Agnus/Registers/FMODE bscan2 tests.
;
; The including file must define, before "include"-ing this:
;   FMODE_B      the FMODE value for the region under test
;   MOD1_B       BPL1MOD for the region under test
;   MOD2_B       BPL2MOD for the region under test
;   REGB_SHIFT   0 or 1, moves the region under test down by a raster line
;
;
; WHAT IS UNDER TEST
; ------------------
;
; BSCAN2, bit 14 of FMODE, an AGA feature the suite had no test for.
;
; Normally BPL1MOD belongs to the odd bitplanes and BPL2MOD to the even ones.
; BSCAN2 throws that away and selects the modulo by the PARITY OF THE RASTER
; LINE instead, the same modulo then applying to every plane. That is what
; makes scan doubling possible: give one parity a modulo that rewinds the
; pointers by exactly one line's worth of data and the other a modulo of
; zero, and every line is fetched twice and displayed twice.
;
; The parity is not counted from the top of the fetch region. It is anchored
; at the vertical start of the display window, so the first displayed line is
; always the first line of a doubled pair:
;
;     modulo = (line parity == DIWSTRT vstart parity) ? BPL1MOD : BPL2MOD
;
; That anchoring is the part most likely to be got wrong, and REGB_SHIFT
; exists to probe it.
;
;
; THE PICTURE
; -----------
;
; Two regions of 64 raster lines, separated by a white bar. Both fetch the
; same bitmap from the same starting address:
;
;   region A   BSCAN2 off, both modulos zero -- the control
;   region B   whatever the including file asks for -- under test
;
; The bitmap is three bitplanes of solid horizontal bands, two source lines
; per band, cycling through the eight colours black, red, green, blue,
; yellow, magenta, cyan, white. So region A repeats every 16 raster lines
; and shows four cycles. Under scan doubling region B repeats every 32 and
; shows two, with every band four raster lines tall instead of two.
;
; Reading the answer off a photograph therefore does not need a ruler: it is
; the number of colour cycles in the lower region against the number in the
; upper one, and the two regions are the same height. Nothing here depends on
; CPU timing -- the CPU builds the bitmap once and then idles, and every
; register the picture depends on is written by the Copper.
;
; Each test also runs on an A500+, and that is not the null result it might
; sound like. FMODE does not exist before AGA, so BSCAN2 cannot be set, and
; the two modulos go back to meaning what they always meant: BPL1MOD for the
; odd planes and BPL2MOD for the even ones. Handing the same pair of modulos
; to an ECS machine therefore rewinds planes 1 and 3 every line while plane 2
; runs on, and region B breaks into bands of a single colour. Same registers,
; same bitmap, completely different picture -- which is the clearest statement
; of what BSCAN2 actually changes: not the modulos, but which modulo is
; picked.

FMODEREG            equ $1FC          ; AGA only

BYTES_PER_LINE      equ 40            ; 320 lores pixels
SRC_LINES           equ 128           ; source lines per plane
PLANE_SIZE          equ BYTES_PER_LINE*SRC_LINES

REGA_LINE           equ $30           ; first line of the control region
REGION_LINES        equ 64
BAR_LINE            equ REGA_LINE+REGION_LINES
BAR_LINES           equ 4
REGB_LINE           equ BAR_LINE+BAR_LINES+REGB_SHIFT
END_LINE            equ REGB_LINE+REGION_LINES

DIW_START           equ (REGA_LINE<<8)|$81
DIW_STOP            equ (END_LINE<<8)|$C1

BPL_OFF             equ $0200         ; no bitplanes
BPL_ON              equ $3200         ; three bitplanes, lores

	; DIWSTOP's vertical bit 8 is the complement of bit 7, so a stop
	; line below 128 would not mean what it says here.
	iflt    END_LINE-128
	FAIL    "END_LINE must be 128 or greater"
	endc


MAIN:
	lea     CUSTOM,a1

	move.w  #BPL_OFF,BPLCON0(a1)
	move.w  #$7FFF,INTENA(a1)
	move.w  #$7FFF,DMACON(a1)
	move.b  #$7F,$BFDD00
	move.b  #$7F,$BFED01

	; Build the bitmap: source line k carries colour index (k >> 1) & 7,
	; so each colour covers two source lines and the eight of them cycle
	; every sixteen.
	lea     plane1(pc),a0
	moveq   #0,d3
	bsr     .fillPlane
	lea     plane2(pc),a0
	moveq   #1,d3
	bsr     .fillPlane
	lea     plane3(pc),a0
	moveq   #2,d3
	bsr     .fillPlane

	; The palette. Index 0 is black and index 7 white, so the ends of
	; each cycle are unmistakable even on a photograph.
	lea     COLOR00(a1),a0
	move.w  #$000,(a0)+
	move.w  #$F00,(a0)+
	move.w  #$0F0,(a0)+
	move.w  #$00F,(a0)+
	move.w  #$FF0,(a0)+
	move.w  #$F0F,(a0)+
	move.w  #$0FF,(a0)+
	move.w  #$FFF,(a0)+

	; Patch the two sets of bitplane pointers into the copper list
	lea     ptrA(pc),a0
	bsr     .patchPtrs
	lea     ptrB(pc),a0
	bsr     .patchPtrs

	lea     copper(pc),a0
	move.l  a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0

	move.w  #$8080,DMACON(a1)     ; Copper DMA
	move.w  #$8100,DMACON(a1)     ; Bitplane DMA
	move.w  #$8200,DMACON(a1)     ; DMA enable

.mainLoop:
	bra.b   .mainLoop

	; Fills one plane. d3 selects which bit of the colour index this
	; plane carries, a0 points at the buffer.
.fillPlane:
	moveq   #0,d0                 ; source line
.flLine:
	move.w  d0,d1
	lsr.w   #1,d1
	and.w   #7,d1                 ; colour index
	lsr.w   d3,d1
	btst    #0,d1
	bne.s   .flOnes
	moveq   #0,d2
	bra.s   .flFill
.flOnes:
	move.l  #$FFFFFFFF,d2
.flFill:
	move.w  #(BYTES_PER_LINE/4)-1,d4
.flWord:
	move.l  d2,(a0)+
	dbra    d4,.flWord
	addq.w  #1,d0
	cmp.w   #SRC_LINES,d0
	bne.s   .flLine
	rts

	; Writes the three bitplane start addresses into a block of six
	; copper MOVEs (BPL1PTH, BPL1PTL, BPL2PTH, ... ) at a0.
.patchPtrs:
	lea     plane1(pc),a2
	bsr     .patchOne
	lea     plane2(pc),a2
	bsr     .patchOne
	lea     plane3(pc),a2
	bsr     .patchOne
	rts
.patchOne:
	move.l  a2,d1
	swap    d1
	move.w  d1,2(a0)              ; high word
	swap    d1
	move.w  d1,6(a0)              ; low word
	lea     8(a0),a0
	rts


; ---------------------------------------------------------------------------
; The copper list
; ---------------------------------------------------------------------------

copper:
	dc.w    DIWSTRT,DIW_START
	dc.w    DIWSTOP,DIW_STOP
	dc.w    DDFSTRT,$0038
	dc.w    DDFSTOP,$00D0
	dc.w    BPLCON1,$0000
	dc.w    BPLCON2,$0024
	dc.w    BPLCON0,BPL_OFF
	dc.w    COLOR00,$0000

	;
	; Region A -- the control. BSCAN2 off, both modulos zero, so the
	; pointers simply run from one line into the next.
	;

	dc.w    (((REGA_LINE-2)<<8)|$01),$FFFE
	dc.w    FMODEREG,$0000
	dc.w    BPL1MOD,$0000
	dc.w    BPL2MOD,$0000
ptrA:
	dc.w    BPL1PTH,$0000
	dc.w    BPL1PTL,$0000
	dc.w    BPL2PTH,$0000
	dc.w    BPL2PTL,$0000
	dc.w    BPL3PTH,$0000
	dc.w    BPL3PTL,$0000

	dc.w    (((REGA_LINE-1)<<8)|$01),$FFFE
	dc.w    BPLCON0,BPL_ON

	;
	; The bar, and the setup for region B. Everything the region under
	; test needs is written while the bitplanes are switched off, so the
	; region itself begins with a single BPLCON0 write and nothing else.
	;

	dc.w    ((BAR_LINE<<8)|$01),$FFFE
	dc.w    BPLCON0,BPL_OFF
	dc.w    COLOR00,$0FFF
	dc.w    FMODEREG,FMODE_B
	dc.w    BPL1MOD,MOD1_B
	dc.w    BPL2MOD,MOD2_B
ptrB:
	dc.w    BPL1PTH,$0000
	dc.w    BPL1PTL,$0000
	dc.w    BPL2PTH,$0000
	dc.w    BPL2PTL,$0000
	dc.w    BPL3PTH,$0000
	dc.w    BPL3PTL,$0000

	dc.w    (((REGB_LINE-1)<<8)|$01),$FFFE
	dc.w    COLOR00,$0000

	;
	; Region B -- under test
	;

	dc.w    ((REGB_LINE<<8)|$01),$FFFE
	dc.w    BPLCON0,BPL_ON

	dc.w    ((END_LINE<<8)|$01),$FFFE
	dc.w    BPLCON0,BPL_OFF
	dc.w    FMODEREG,$0000

	dc.l    $FFFFFFFE


	cnop    0,8
plane1: ds.b PLANE_SIZE
	cnop    0,8
plane2: ds.b PLANE_SIZE
	cnop    0,8
plane3: ds.b PLANE_SIZE
