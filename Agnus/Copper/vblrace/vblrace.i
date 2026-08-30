	include "../../../../include/registers.i"
	include "../../../../include/ministartup.i"

;
; vblrace -- CPU vs. Copper: who wins the colour registers in the VBlank
; race, as a function of how late the Copper is allowed to start?
;
; This is coprace3 turned into a family: the same 31-register race (Copper
; writes COLOR01-31 yellow, in order, as the very first thing it does every
; frame; the CPU's VBlank handler writes the same 31 registers blue, also
; in order, then executes STOP -- whichever write lands last on a given
; register wins it), but with a WAIT statement in front of the Copper's
; first race write. Each member of the family sets WAIT_POS to a
; different target position before including this file, holding the
; Copper back by a different number of cycles before it fires its first
; MOVE.
;
; Why a Copper-side delay reveals a boundary that coprace3 itself
; couldn't: with no delay, the Copper is both further ahead at the start
; (it doesn't pay the CPU's interrupt-response latency) and faster per
; register (~2 CCK per MOVE vs. the CPU's slower immediate-to-memory
; write), so its write to register N is chronologically earlier than the
; CPU's for every N from 1 to 31 -- the CPU wins every register,
; unconditionally, exactly as coprace3 found. Holding the Copper back by D
; cycles gives the CPU a head start for the low-numbered registers (the
; CPU's write, unaffected by D, can now land first, so the Copper's
; delayed write arrives after it and wins -- yellow); but because the
; Copper still gains ground every register (its per-write cost is lower),
; that head start shrinks as N grows, and past some threshold the CPU is
; back in front again -- blue. The picture is yellow from register 1 up
; to a boundary, then blue from there to register 31; the boundary moves
; right as WAIT_POS increases across the family.
;
; The background/separator colour (COLOR00) is black, not white: it is
; the real Amiga background register, so its value also shows in the
; border outside the display window, and coprace3 originally left it at
; white there for the whole frame. The 1-pixel gaps between stripes stay
; readable as black against the blue/yellow race colours either way.
;

LVL3_INT_VECTOR		equ $6c

YELLOW              equ $FF0
BLUE                equ $00F
BLACK               equ $000

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

	; Bitplane pointers: five separate one-row buffers, not one big
	; image -- the modulo trick below redisplays each row on every
	; scanline, so there is nothing to scroll through underneath it
	lea     plane1(pc),a0
	move.l  a0,BPL1PTH(a1)
	lea     plane2(pc),a0
	move.l  a0,BPL2PTH(a1)
	lea     plane3(pc),a0
	move.l  a0,BPL3PTH(a1)
	lea     plane4(pc),a0
	move.l  a0,BPL4PTH(a1)
	lea     plane5(pc),a0
	move.l  a0,BPL5PTH(a1)

	; Set up the playfield: 5 planes (31 stripes + background), no
	; scroll, and a modulo that cancels each row's own advance so the
	; single row of data above is what every display line shows
	move.w  #(5<<12)|$200,BPLCON0(a1)
	move.w  #$0000,BPLCON1(a1)
	move.w  #-40,BPL1MOD(a1)
	move.w  #-40,BPL2MOD(a1)
	move.w  #$0038,DDFSTRT(a1)
	move.w  #$00D0,DDFSTOP(a1)
	move.w  #$2C81,DIWSTRT(a1)
	move.w  #$F4C1,DIWSTOP(a1)

	; Install the only interrupt handler this test needs
	lea	    irq3(pc),a3
 	move.l	a3,LVL3_INT_VECTOR

	; Setup Copper
	lea	    copper(pc),a0
	move.l	a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0
	move.w  #$0000,COPCON(a1)  ; the Copper only ever touches colour registers

	; Enable DMA
	move.w	#$8080,DMACON(a1)   ; Copper DMA
	move.w	#$8100,DMACON(a1)   ; Bitplane DMA
	move.w	#$8200,DMACON(a1)   ; DMAEN

	; Enable the vertical blank interrupt only
	move.w	#$C020,INTENA(a1)

.wait:
	bra.b	.wait               ; until the first VBlank


; ---------------------------------------------------------------------------
; The CPU's side of the race: 31 blue writes, as fast as the CPU can issue
; them, then off the bus until next frame. Unaffected by WAIT_POS -- only
; the Copper's start is delayed.
; ---------------------------------------------------------------------------

irq3:
	lea     sstack,a7           ; the handler never returns; keep the stack
	lea     CUSTOM,a1           ; bounded
	move.w  #$0020,INTREQ(a1)   ; acknowledge (VERTB)

	move.w  #BLUE,COLOR01(a1)
	move.w  #BLUE,COLOR02(a1)
	move.w  #BLUE,COLOR03(a1)
	move.w  #BLUE,COLOR04(a1)
	move.w  #BLUE,COLOR05(a1)
	move.w  #BLUE,COLOR06(a1)
	move.w  #BLUE,COLOR07(a1)
	move.w  #BLUE,COLOR08(a1)
	move.w  #BLUE,COLOR09(a1)
	move.w  #BLUE,COLOR10(a1)
	move.w  #BLUE,COLOR11(a1)
	move.w  #BLUE,COLOR12(a1)
	move.w  #BLUE,COLOR13(a1)
	move.w  #BLUE,COLOR14(a1)
	move.w  #BLUE,COLOR15(a1)
	move.w  #BLUE,COLOR16(a1)
	move.w  #BLUE,COLOR17(a1)
	move.w  #BLUE,COLOR18(a1)
	move.w  #BLUE,COLOR19(a1)
	move.w  #BLUE,COLOR20(a1)
	move.w  #BLUE,COLOR21(a1)
	move.w  #BLUE,COLOR22(a1)
	move.w  #BLUE,COLOR23(a1)
	move.w  #BLUE,COLOR24(a1)
	move.w  #BLUE,COLOR25(a1)
	move.w  #BLUE,COLOR26(a1)
	move.w  #BLUE,COLOR27(a1)
	move.w  #BLUE,COLOR28(a1)
	move.w  #BLUE,COLOR29(a1)
	move.w  #BLUE,COLOR30(a1)
	move.w  #BLUE,COLOR31(a1)

	stop    #$2000               ; no bus cycles until the next VBlank


; ---------------------------------------------------------------------------
; The copper list
; ---------------------------------------------------------------------------

copper:
	; Bitplane pointers are set once by the CPU in MAIN and never touched
	; again -- there is no per-frame scrolling here, so, unlike bbusy/
	; copbbusy/cpucol, this list has no BPLxPT placeholders for the CPU
	; to patch.

	; The customizable handicap: WAIT_POS is set by the including test
	; file. Holding the Copper here for longer gives the CPU's fixed
	; interrupt-response latency more of a head start before the race
	; below begins.
	dc.w    WAIT_POS,$FFFE

	; The race: register-by-register, whichever of this and irq3's blue
	; writes lands last wins.
	dc.w    COLOR01,YELLOW
	dc.w    COLOR02,YELLOW
	dc.w    COLOR03,YELLOW
	dc.w    COLOR04,YELLOW
	dc.w    COLOR05,YELLOW
	dc.w    COLOR06,YELLOW
	dc.w    COLOR07,YELLOW
	dc.w    COLOR08,YELLOW
	dc.w    COLOR09,YELLOW
	dc.w    COLOR10,YELLOW
	dc.w    COLOR11,YELLOW
	dc.w    COLOR12,YELLOW
	dc.w    COLOR13,YELLOW
	dc.w    COLOR14,YELLOW
	dc.w    COLOR15,YELLOW
	dc.w    COLOR16,YELLOW
	dc.w    COLOR17,YELLOW
	dc.w    COLOR18,YELLOW
	dc.w    COLOR19,YELLOW
	dc.w    COLOR20,YELLOW
	dc.w    COLOR21,YELLOW
	dc.w    COLOR22,YELLOW
	dc.w    COLOR23,YELLOW
	dc.w    COLOR24,YELLOW
	dc.w    COLOR25,YELLOW
	dc.w    COLOR26,YELLOW
	dc.w    COLOR27,YELLOW
	dc.w    COLOR28,YELLOW
	dc.w    COLOR29,YELLOW
	dc.w    COLOR30,YELLOW
	dc.w    COLOR31,YELLOW

	; The separator gaps built into the bitplane data are index 0 -- this
	; is what makes them black, the same as the border outside DIW
	dc.w    COLOR00,BLACK

	; Wait until well past the bottom of the visible frame -- the same
	; $ffdf position every other test in this suite uses as "safely past
	; all visible content" -- before putting every register back to
	; black, so next frame's race starts from a clean slate.
	dc.w    $ffdf,$fffe
	dc.w    COLOR01,BLACK
	dc.w    COLOR02,BLACK
	dc.w    COLOR03,BLACK
	dc.w    COLOR04,BLACK
	dc.w    COLOR05,BLACK
	dc.w    COLOR06,BLACK
	dc.w    COLOR07,BLACK
	dc.w    COLOR08,BLACK
	dc.w    COLOR09,BLACK
	dc.w    COLOR10,BLACK
	dc.w    COLOR11,BLACK
	dc.w    COLOR12,BLACK
	dc.w    COLOR13,BLACK
	dc.w    COLOR14,BLACK
	dc.w    COLOR15,BLACK
	dc.w    COLOR16,BLACK
	dc.w    COLOR17,BLACK
	dc.w    COLOR18,BLACK
	dc.w    COLOR19,BLACK
	dc.w    COLOR20,BLACK
	dc.w    COLOR21,BLACK
	dc.w    COLOR22,BLACK
	dc.w    COLOR23,BLACK
	dc.w    COLOR24,BLACK
	dc.w    COLOR25,BLACK
	dc.w    COLOR26,BLACK
	dc.w    COLOR27,BLACK
	dc.w    COLOR28,BLACK
	dc.w    COLOR29,BLACK
	dc.w    COLOR30,BLACK
	dc.w    COLOR31,BLACK

	dc.l    $fffffffe


; ---------------------------------------------------------------------------
; Bitplane data: one 320-pixel row per plane. 31 stripes, 8 pixels wide,
; separated by a 1-pixel gap (index 0 -- shows through COLOR00, set to
; black above); index N (1-31) is stripe N, read through COLORnn. Both
; bitplane modulos above are set to redisplay this same row on every
; scanline, so there is no per-line data to provide.
; ---------------------------------------------------------------------------

; Each plane's real 320-pixel row (20 words) is followed by 32 words of
; zero padding. Agnus's actual fetch burst for a given DDFSTRT/DDFSTOP is
; a few words wider than the nominal (DDFSTOP-DDFSTRT)/8+1 -- get that
; margin wrong and the extra words read past the end of a 20-word buffer
; straight into the NEXT plane's data, garbling the stripe boundaries.
; The padding costs nothing (it's off-screen/background either way) and
; removes the need to get the exact fetch width right.
plane1:
	dc.w    $0000,$07F8,$01FE,$007F,$801F,$E007,$F801,$FE00
	dc.w    $7F80,$1FE0,$07F8,$01FE,$007F,$801F,$E007,$F801
	dc.w    $FE00,$7F80,$1FE0,$0000
	ds.w    32,0
plane2:
	dc.w    $0000,$0003,$FDFE,$0000,$3FDF,$E000,$03FD,$FE00
	dc.w    $003F,$DFE0,$0003,$FDFE,$0000,$3FDF,$E000,$03FD
	dc.w    $FE00,$003F,$DFE0,$0000
	ds.w    32,0
plane3:
	dc.w    $0000,$0000,$0000,$FF7F,$BFDF,$E000,$0000,$00FF
	dc.w    $7FBF,$DFE0,$0000,$0000,$FF7F,$BFDF,$E000,$0000
	dc.w    $00FF,$7FBF,$DFE0,$0000
	ds.w    32,0
plane4:
	dc.w    $0000,$0000,$0000,$0000,$0000,$0FF7,$FBFD,$FEFF
	dc.w    $7FBF,$DFE0,$0000,$0000,$0000,$0000,$0FF7,$FBFD
	dc.w    $FEFF,$7FBF,$DFE0,$0000
	ds.w    32,0
plane5:
	dc.w    $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	dc.w    $0000,$000F,$F7FB,$FDFE,$FF7F,$BFDF,$EFF7,$FBFD
	dc.w    $FEFF,$7FBF,$DFE0,$0000
	ds.w    32,0

	ds.l    64
sstack:
