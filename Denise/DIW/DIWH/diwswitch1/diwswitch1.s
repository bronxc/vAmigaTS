;
; diwswitch1 -- can the DIWHIGH interpretation be switched off again? (AGA/ECS)
;
; ECS Denise and Lisa read DIWSTRT/DIWSTOP's low byte as before, but no
; longer hard-wire the missing 9th bit (H8): OCS always used H8=0 for
; DIWSTRT and H8=1 for DIWSTOP, giving a fixed horizontal range of 0-255
; for the start edge and 256-511 for the stop edge. On ECS and AGA, that
; 9th bit instead comes from DIWHIGH -- bit 5 for DIWSTRT, bit 13 for
; DIWSTOP -- which lets a Copper list place either edge anywhere across
; the whole 0-511 range instead of being confined to one half of it.
;
; The interesting part is not the bit itself but the latch behind it.
; DIWHIGH's extended interpretation is not simply "on once ECS/AGA
; hardware is present" -- it has to be switched on by writing DIWHIGH,
; and a later write to DIWSTRT or DIWSTOP switches it back off again,
; reverting that edge to the OCS-style hard-wired bit until DIWHIGH is
; written again. WinUAE / Amiberry model this with a single flag,
; `diwhigh_written`, shared by both edges: writing DIWHIGH sets it,
; and writing *either* DIWSTRT or DIWSTOP clears it -- for *both* edges
; at once, not just the one being written.
;
; vAmiga's current setDIWSTRT / setDIWSTOP do force their own edge back
; to the OCS-hardcoded bit on every write, which reproduces the WinUAE
; behaviour for a same-field rewrite. What they do NOT do is touch the
; *other* edge's bit -- Denise::setDIWSTRT only ever calls setHSTRT,
; never setHSTOP, and setDIWSTOP is the mirror image. So on vAmiga, as
; the source reads today, writing DIWSTOP while DIWSTRT's extended bit
; is active leaves that bit untouched, where the WinUAE model says it
; should be cleared.
;
;
; WHAT THIS TEST DOES
; --------------------
;
; Section A drives DIWSTRT's H8 bit through six steps, in this order:
;
;   1. baseline           DIWHIGH default (H8=0)      edge at the near
;                          position -- OCS-style, the starting point
;   2. switch ON           DIWHIGH sets H8=1            edge jumps to the
;                          far position
;   3. same-field rewrite  DIWSTRT rewritten unchanged  edge should fall
;                          back to the near position -- this is the part
;                          both models agree on
;   4. switch ON again      DIWHIGH sets H8=1            edge at the far
;                          position again
;   5. cross-field rewrite DIWSTOP rewritten unchanged  THE OPEN QUESTION:
;                          WinUAE says this clears the latch too (edge
;                          should fall back to the near position);
;                          vAmiga's source only clears it on a DIWSTRT
;                          write, so the edge should stay at the far
;                          position
;   6. reset                DIWHIGH default              back to the near
;                          position, closing out the section
;
; Section B repeats the same six steps for DIWSTOP's H8 bit, with the
; roles of DIWSTRT and DIWSTOP swapped, so the cross-field question gets
; asked in both directions.
;
; Every step is bordered in one of two colours: dark blue for a step
; where the OCS-style hardcoded bit should be in effect (the extension
; is off), dark yellow for a step where the extension should be active.
; Step 5 in each section -- the open question -- is bordered white
; instead of guessing an answer: read its window edge and compare it
; against the blue and yellow steps around it to see which model vAmiga
; agrees with.
;
;
; READING THE PICTURE
; --------------------
;
; One bitplane, filled solid, so the window interior is a flat white bar
; against the black interior gap and the coloured border above. DIWSTOP
; is held far out in section A (432, well past both of DIWSTRT's two
; positions) so the left edge is the only thing that moves; DIWSTRT is
; held at a fixed near position in section B so the right edge is the
; only thing that moves.
;

	include "../../../../include/registers.i"
	include "../../../../include/ministartup.i"

LVL3_INT_VECTOR     equ $6C
DIWHIGH             equ $1E4

LORES_BITS          equ $1201          ; one bitplane, ECSENA set
BPLCON0_OFF         equ $0201

; Section A: DIWSTRT's H8 bit. DIWSTOP is fixed at 432 (H8=1, low byte
; $B0), comfortably beyond both of DIWSTRT's two possible positions.
A_STRT_LO           equ $2890          ; vertical start line 40, low byte $90 -> near 144
A_STOP_FIXED        equ $F0B0          ; vertical stop line 240, low byte $B0, H8=1 -> 432

; Section B: DIWSTOP's H8 bit. DIWSTRT is fixed at 144, comfortably
; below both of DIWSTOP's two possible positions (176 and 432).
B_STRT_FIXED        equ $2890          ; same vertical window as section A: 144
B_STOP_LO            equ $F0B0          ; far 432 (H8=1) / near 176 (H8=0)

; DIWHIGH values. Bit 5 is DIWSTRT's H8, bit 13 is DIWSTOP's H8; both
; default to the OCS-hardcoded state (STRT=0, STOP=1) at $2000.
DH_DEFAULT          equ $2000          ; bit5=0, bit13=1 -- OCS defaults
DH_STRT_ON          equ $2020          ; bit5=1 -- DIWSTRT's H8 forced to 1
DH_STOP_ON          equ $0000          ; bit13=0 -- DIWSTOP's H8 forced to 0

BLACK               equ $000
WHITE               equ $FFF
BORDER_OFF          equ $006           ; dark blue: extension believed off
BORDER_ON           equ $660           ; dark yellow: extension believed on
BORDER_ASK          equ $848           ; muted red-grey: distinct from content white AND from OFF/ON

TAG_A               equ $600           ; dark red
TAG_B               equ $006           ; dark blue -- reused after section A closes

STEPLINES           equ 8
SECTLINES           equ 3

BUF_SIZE            equ 16384

; One step: park the Copper at the start of the line, apply the register
; write under test, and set the border colour that names the expected
; state (or BORDER_ASK for the open question).
STEP    macro
	dc.w    (((\1)<<8)|$01),$FFFE
	\2
	dc.w    COLOR00,\3
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

	lea     bitplanes(pc),a0
	move.w  #(BUF_SIZE/2)-1,d0
.fill:
	move.w  #$FFFF,(a0)+
	dbra    d0,.fill

	lea     bitplanes(pc),a0
	move.l  a0,d0
	lea     bplptr(pc),a2
	move.w  d0,6(a2)
	swap    d0
	move.w  d0,2(a2)

	lea     copper(pc),a0
	move.l  a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0

	move.w  #$8080,DMACON(a1)
	move.w  #$8100,DMACON(a1)
	move.w  #$8200,DMACON(a1)
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
	dc.w    DIWSTRT,A_STRT_LO
	dc.w    DIWSTOP,A_STOP_FIXED
	dc.w    DIWHIGH,DH_DEFAULT
	dc.w    BPL1MOD,$0000
	dc.w    BPL2MOD,$0000
	dc.w    COLOR00,BLACK
	dc.w    COLOR01,WHITE

CLINE   set     $28

	dc.w    (((CLINE)<<8)|$01),$FFFE
	dc.w    BPLCON0,LORES_BITS
bplptr:
	dc.w    BPL1PTH,$0000       ; filled in by MAIN
	dc.w    BPL1PTL,$0000

	;
	; SECTION A -- DIWSTRT's H8 bit. DDFSTOP is fixed far out so the
	; left edge alone carries the answer.
	;
	dc.w    (((CLINE)<<8)|$01),$FFFE
	dc.w    COLOR00,TAG_A
CLINE   set     CLINE+SECTLINES

	STEP    CLINE,<dc.w    DIWHIGH,DH_DEFAULT>,BORDER_OFF
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,<dc.w    DIWHIGH,DH_STRT_ON>,BORDER_ON
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,<dc.w    DIWSTRT,A_STRT_LO>,BORDER_OFF
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,<dc.w    DIWHIGH,DH_STRT_ON>,BORDER_ON
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,<dc.w    DIWSTOP,A_STOP_FIXED>,BORDER_ASK
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,<dc.w    DIWHIGH,DH_DEFAULT>,BORDER_OFF
CLINE   set     CLINE+STEPLINES

	;
	; SECTION B -- DIWSTOP's H8 bit, same six steps, roles of DIWSTRT
	; and DIWSTOP swapped. DIWSTRT is fixed near so the right edge
	; alone carries the answer.
	;
	dc.w    (((CLINE)<<8)|$01),$FFFE
	dc.w    DIWSTRT,B_STRT_FIXED
	dc.w    DIWSTOP,B_STOP_LO
	dc.w    DIWHIGH,DH_DEFAULT
	dc.w    COLOR00,TAG_B
CLINE   set     CLINE+SECTLINES

	STEP    CLINE,<dc.w    DIWHIGH,DH_DEFAULT>,BORDER_OFF
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,<dc.w    DIWHIGH,DH_STOP_ON>,BORDER_ON
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,<dc.w    DIWSTOP,B_STOP_LO>,BORDER_OFF
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,<dc.w    DIWHIGH,DH_STOP_ON>,BORDER_ON
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,<dc.w    DIWSTRT,B_STRT_FIXED>,BORDER_ASK
CLINE   set     CLINE+STEPLINES
	STEP    CLINE,<dc.w    DIWHIGH,DH_DEFAULT>,BORDER_OFF
CLINE   set     CLINE+STEPLINES

	dc.w    (((CLINE)<<8)|$01),$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
	dc.l    $FFFFFFFE

	ifgt    CLINE-250
	FAIL    "the picture runs past raster line 250"
	endc

bitplanes:
	ds.b    BUF_SIZE
