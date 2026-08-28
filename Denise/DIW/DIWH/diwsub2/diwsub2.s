;
; diwsub2 -- sub-lores positioning of the display window (DIWHIGH, AGA)
;
; A successor to diwsub in this directory. Same subject, different picture.
;
; DIWSTRT and DIWSTOP hold their horizontal coordinate in LORES pixels, so
; the display window can only be placed on even hires pixels and on
; multiples of four in super hires. AGA adds two two-bit fields to DIWHIGH
; that supply the missing low bits:
;
;   DIWHIGH bits  4  3    the two low bits of the DIWSTRT coordinate
;   DIWHIGH bits 12 11    the two low bits of the DIWSTOP coordinate
;   DIWHIGH bit   5       DIWSTRT bit 8   (ECS and AGA)
;   DIWHIGH bit  13       DIWSTOP bit 8   (ECS and AGA)
;
; vAmiga implements bits 5 and 13 and nothing else, so the four low bits
; have no effect at all. This test is built to make that obvious.
;
;
; WHY A SECOND TEST
; -----------------
;
; diwsub walks the four settings down the screen once per section, one
; long block each. The effect it is chasing is at most three super hires
; pixels wide, and on a CRT the picture tube bows the left edge of the
; image by considerably more than that over the height of a section. In
; the A1200 photograph of diwsub the control section -- lores, where
; nothing may move -- drifts by fourteen camera pixels all by itself, which
; is wider than the signal. The photograph cannot answer the question it
; was taken for.
;
; This test fixes that by changing two things:
;
;   1. The setting is ramped fast, not once per screen. Each ramp is
;      eighteen rasterlines tall and every ramp is repeated, so the
;      picture carries a sawtooth of a known short period. Tube geometry
;      is smooth over that distance and cannot fake a sawtooth.
;
;   2. Every ramp opens with two white lines drawn with all four low bits
;      cleared. They are the baseline, right next to the steps being
;      judged, so the comparison is local instead of spanning half the
;      screen.
;
;
; WHAT TO EXPECT
; --------------
;
; Both window edges are compared in super hires units, but the comparison
; is masked down to the resolution actually being displayed. The added
; bits therefore survive only as far as the current mode can resolve them:
;
;   lores         all four settings identical, no edge movement at all
;   hires         0 and 1 identical, 2 and 3 identical, one hires pixel
;                 apart from each other
;   super hires   four distinct positions, one super hires pixel apart
;
; So on AGA the lores section is a straight edge, the hires section is a
; square wave of amplitude one hires pixel, and the super hires section is
; a four-step staircase. On OCS and ECS all three sections are straight,
; because these are AGA fields.
;
; On vAmiga in AGA mode, today, all three sections are straight as well --
; the AGA picture is pixel for pixel the ECS picture. That equality is the
; flaw, and it is the thing to re-check once DIWHIGH is implemented.
;
; The regression reference resolves one hires pixel per texel, so it shows
; the hires square wave exactly and shows the super hires staircase as two
; pairs rather than four steps. All four steps are visible on a real
; machine, which is what the A1200 photograph is for.
;
;
; READING THE PICTURE
; -------------------
;
; One bitplane, its buffer filled with $FFFF, so the window interior is a
; flat colour and its edges are colour against the black of COLOR00. There
; is no BRDRBLNK anywhere in this test, deliberately: the border and
; COLOR00 are both black, the test runs unchanged on OCS, and the edges
; stay readable because the bitplane data covers the window end to end.
;
; Three sections, top to bottom: lores, hires, super hires. Each section
; holds two halves. The first half ramps the DIWSTRT field and leaves the
; DIWSTOP field at zero, so the LEFT edge is the one that moves. The second
; half does the reverse and moves the RIGHT edge. The lores section has one
; ramp per half, the other two have two.
;
; Each section opens with a three line tag stripe that names it: dark red
; for lores, dark green for hires, dark blue for super hires. Within a ramp
; the four settings are colour coded, always the same way:
;
;   white   the baseline, both fields zero
;   blue    setting 0
;   green   setting 1
;   yellow  setting 2
;   purple  setting 3
;
; DIWSTRT sits at lores $90, deliberately RIGHT of the first bitplane
; pixel. The display window does not open at DIWSTRT but at the first
; BPL1DAT write, so a DIWSTRT left of the data would be invisible and the
; test would measure nothing (see Denise/Sprites/clip/diwclip). Placing it
; inside the data makes DIWSTRT the edge that shows.
;

	include "../../../../include/registers.i"
	include "../../../../include/ministartup.i"

LVL3_INT_VECTOR     equ $6C
DIWHIGH             equ $1E4           ; ECS and AGA

BPLCON0_OFF         equ $0201
LORES_BITS          equ $1201          ; one bitplane, ECSENA set
HIRES_BITS          equ $9201          ; bit 15 selects hires
SHRES_BITS          equ $1241          ; bit 6 alone selects super hires

; The vertical window is chosen so that it is unambiguous on every
; chipset. DIWSTOP's high byte has bit 7 set, so the OCS rule V8 = !V7 and
; the ECS rule V8 = DIWHIGH bit 8 agree on line $F0.
DIW_START           equ $2890          ; line $28, lores pixel $90
DIW_STOP            equ $F080          ; line $F0, lores pixel $180

; DIWHIGH template. Bit 13 restores DIWSTOP's bit 8, which the register
; takes over as soon as it has been written once.
DH_BASE             equ $2000
STRT_SHIFT          equ 3              ; DIWHIGH bits 4-3
STOP_SHIFT          equ 11             ; DIWHIGH bits 12-11

BLACK               equ $000
BASELINE            equ $FFF
TAG_LORES           equ $800
TAG_HIRES           equ $080
TAG_SHRES           equ $008
SUB0                equ $28C
SUB1                equ $2C8
SUB2                equ $CC2
SUB3                equ $C4A

TOP_LINE            equ $30
STEPLINES           equ 4              ; rasterlines per setting
BASELINES           equ 2              ; rasterlines per baseline stripe
SECTLINES           equ 3              ; rasterlines per section tag stripe
TEETH_LORES         equ 1              ; ramps per half, control section
TEETH_HIRES         equ 2
TEETH_SHRES         equ 2

BUF_SIZE            equ 16384

; One setting: park the Copper at the start of the line, install the
; DIWHIGH value, install the colour that names the setting.
;
; The colour goes into COLOR01 and COLOR05 alike. On AGA and on the two
; low resolutions the single bitplane selects register 1, but ECS Denise
; in super hires pairs the plane bits of two neighbouring pixels and ends
; up at register 5 (see Denise/Modes/shres). Writing both keeps the super
; hires section visible on every chipset instead of going black on the
; A500+ alone.
STEP    macro
	dc.w    (((\1)<<8)|$01),$FFFE
	dc.w    DIWHIGH,\2
	dc.w    COLOR01,\3
	dc.w    COLOR05,\3
	endm

; One ramp: a white baseline line, then the four settings of the field
; selected by \1 (STRT_SHIFT or STOP_SHIFT).
RAMP    macro
	STEP    CLINE,DH_BASE,BASELINE
CLINE   set     CLINE+BASELINES
	STEP    CLINE,DH_BASE|(0<<\1),SUB0
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,DH_BASE|(1<<\1),SUB1
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,DH_BASE|(2<<\1),SUB2
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,DH_BASE|(3<<\1),SUB3
CLINE   set     CLINE+STEPLINES
	endm

MAIN:
	lea     CUSTOM,a1
	move.w  #$7FFF,INTENA(a1)
	move.w  #$7FFF,DMACON(a1)
	move.w  #BPLCON0_OFF,BPLCON0(a1)
	move.b  #$7F,$BFDD00
	move.b  #$7F,$BFED01
	lea     irq3(pc),a3
	move.l  a3,LVL3_INT_VECTOR

	; Solid bitplane data, so the window interior is a flat colour
	lea     bitplanes(pc),a0
	move.w  #(BUF_SIZE/2)-1,d0
.fill:
	move.w  #$FFFF,(a0)+
	dbra    d0,.fill

	; Fill in the bitplane pointer reloads in the Copper list
	lea     bitplanes(pc),a0
	move.l  a0,d0
	lea     bplptr_lores(pc),a2
	move.w  d0,6(a2)
	swap    d0
	move.w  d0,2(a2)
	move.l  a0,d0
	lea     bplptr_hires(pc),a2
	move.w  d0,6(a2)
	swap    d0
	move.w  d0,2(a2)
	move.l  a0,d0
	lea     bplptr_shres(pc),a2
	move.w  d0,6(a2)
	swap    d0
	move.w  d0,2(a2)

	lea     copper(pc),a0
	move.l  a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0

	move.w  #$8080,DMACON(a1)   ; Copper DMA
	move.w  #$8100,DMACON(a1)   ; Bitplane DMA
	move.w  #$8200,DMACON(a1)   ; DMAEN
	move.w  #$C020,INTENA(a1)
.mainLoop:
	bra.b   .mainLoop

irq3:
	movem.l d0-a6,-(sp)
	move.w  #$3FFF,INTREQ(a1)
	lea     bitplanes(pc),a2
	lea     BPL1PTH(a1),a3
	move.l  a2,(a3)
	movem.l (sp)+,d0-a6
	rte

copper:
	dc.w    BPLCON0,BPLCON0_OFF
	dc.w    BPLCON1,$0000
	dc.w    BPLCON2,$0000
	dc.w    DDFSTRT,$0038
	dc.w    DDFSTOP,$00D0
	dc.w    DIWSTRT,DIW_START
	dc.w    DIWSTOP,DIW_STOP
	dc.w    DIWHIGH,DH_BASE
	dc.w    BPL1MOD,$0000
	dc.w    BPL2MOD,$0000
	dc.w    COLOR00,BLACK

CLINE   set     TOP_LINE

	;
	; LORES section -- the control. Nothing may move here.
	;
	dc.w    (((CLINE)<<8)|$01),$FFFE
	dc.w    BPLCON0,LORES_BITS
bplptr_lores:
	dc.w    BPL1PTH,$0000       ; filled in by MAIN
	dc.w    BPL1PTL,$0000
	dc.w    DIWHIGH,DH_BASE
	dc.w    COLOR01,TAG_LORES
	dc.w    COLOR05,TAG_LORES
CLINE   set     CLINE+SECTLINES

	rept    TEETH_LORES
	RAMP    STRT_SHIFT
	endr
	rept    TEETH_LORES
	RAMP    STOP_SHIFT
	endr

	;
	; HIRES section
	;
	dc.w    (((CLINE)<<8)|$01),$FFFE
	dc.w    BPLCON0,HIRES_BITS
bplptr_hires:
	dc.w    BPL1PTH,$0000       ; filled in by MAIN
	dc.w    BPL1PTL,$0000
	dc.w    DIWHIGH,DH_BASE
	dc.w    COLOR01,TAG_HIRES
	dc.w    COLOR05,TAG_HIRES
CLINE   set     CLINE+SECTLINES

	rept    TEETH_HIRES
	RAMP    STRT_SHIFT
	endr
	rept    TEETH_HIRES
	RAMP    STOP_SHIFT
	endr

	;
	; SUPER HIRES section
	;
	dc.w    (((CLINE)<<8)|$01),$FFFE
	dc.w    BPLCON0,SHRES_BITS
bplptr_shres:
	dc.w    BPL1PTH,$0000       ; filled in by MAIN
	dc.w    BPL1PTL,$0000
	dc.w    DIWHIGH,DH_BASE
	dc.w    COLOR01,TAG_SHRES
	dc.w    COLOR05,TAG_SHRES
CLINE   set     CLINE+SECTLINES

	rept    TEETH_SHRES
	RAMP    STRT_SHIFT
	endr
	rept    TEETH_SHRES
	RAMP    STOP_SHIFT
	endr

	dc.w    (((CLINE)<<8)|$01),$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
	dc.l    $FFFFFFFE

	ifgt    CLINE-250
	FAIL    "the picture runs past raster line 250"
	endc

bitplanes:
	ds.b    BUF_SIZE
