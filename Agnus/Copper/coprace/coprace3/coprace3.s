	include "../../../../include/registers.i"
	include "../../../../include/ministartup.i"

;
; coprace3 -- CPU vs. Copper: who wins the colour registers in the VBlank
; race?
;
; Some games modify the Copper list from the CPU's VBlank interrupt, and
; rely on that write landing before the Copper gets to the affected part
; of the list. Whether it does is a race: the vertical blank that starts
; the Copper's list over from COP1LC is the same hardware event that
; requests the CPU's level 3 interrupt, and the CPU's side of that race
; carries real cost -- IPL synchronisation, exception stacking, vector
; fetch, our own handler's prologue -- that the Copper doesn't pay.
;
; This test makes the race visible instead of timing one write. The
; Copper list's very first act, every frame, is to set COLOR01-COLOR31
; to yellow, one MOVE per register, in order. The CPU's VBlank handler
; sets the same 31 registers to blue, also in order, then executes STOP.
; Whichever of the two writes a given register LAST wins it: if the
; Copper is still ahead of the CPU when it reaches register N (the usual
; case -- Copper MOVEs are far cheaper than an interrupt response), the
; CPU's blue write, arriving later, wins and the register ends up blue.
; Once the CPU's cumulative writes catch up to where the Copper already
; is, the Copper's own (later, since it keeps running) write to that
; register wins instead, and the register ends up yellow. The picture is
; 31 numbered stripes, one per register, and the blue/yellow boundary
; marks exactly how many registers the CPU's interrupt response cost it,
; in units of "one Copper MOVE".
;
; The bitplane data draws all 31 stripes at once, side by side, with a
; one-pixel black gap between neighbours so they can be counted; black
; comes from COLOR00, which the gaps are indexed to and which isn't part
; of the race -- it's also the true Amiga background/border register, so
; keeping it black here keeps the border outside the display window black
; too. Both bitplane modulos are set to -(bytes per row), so the same
; one-row image is redisplayed on every scanline -- the stripes don't
; need real height in the source data, only in DIW.
;
; At the bottom of the display (past the stripes, still within the same
; frame) the Copper resets all 31 registers to black, so every frame's
; race starts from the same known state rather than carrying over
; whatever the previous frame's race left behind.
;
; On vAmiga, as of this writing, the CPU wins all 31 registers, every
; frame, deterministically -- the picture is solid blue, no yellow
; anywhere. That is itself a real, reportable result: it means the
; crossover this test is built to expose lies beyond register 31 in
; vAmiga's current interrupt-latency model, not that the race isn't
; happening. Confirmed two ways: adding a few hundred extra cycles of
; delay to the CPU's handler before its first write left the result
; unchanged (it was already losing by more than that), and disabling
; the VBlank interrupt so the CPU never writes at all turns the whole
; picture solid yellow, exactly as it should.
;
; STOP rather than an RTE: the handler never returns, so RTE would just
; accumulate stale exception frames across the run. MAIN itself waits
; for the first VBlank with a plain busy loop, not STOP -- STOP is
; privileged, and executing it before ever having been through an
; interrupt exception is not safe here (see CPU/CpuCol/cpucol's README
; for the Amiberry privilege violation that taught us this). Once inside
; the handler, reached only through a real interrupt exception, STOP is
; exactly as safe as it is in copbbusy.i.
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
; them, then off the bus until next frame.
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
	; to patch. (An earlier draft copied those placeholder MOVEs from
	; that template without patching them; left in, they zeroed all five
	; pointers back to NULL at the top of every single frame, which is
	; why the display never reflected any change to the plane data below
	; -- it was reading from address 0 the whole time.)

	; The race: this runs at the top of the list, every frame, at the
	; same VBlank that requests the CPU's interrupt. Register-by-
	; register, whichever of this and irq3's blue writes lands last
	; wins.
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
	; $ffdf position every other test in this suite uses as "safely
	; past all visible content" -- before putting every register back
	; to black, so next frame's race starts from a clean slate. (An
	; earlier draft reset at VP=$E0, which is still inside the visible
	; area for this DIWSTOP: it blacked out the lower half of every
	; stripe mid-frame instead of resetting between frames.)
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
; white above); index N (1-31) is stripe N, read through COLORnn. Both
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
