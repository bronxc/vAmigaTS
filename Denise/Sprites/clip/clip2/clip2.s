	include "../../../../include/registers.i"
	include "hardware/dmabits.i"
	include "hardware/intbits.i"
	include "ministartup.s"

LVL3_INT_VECTOR		equ $6c
SCREEN_WIDTH_BYTES	equ (320/8)
SCREEN_BIT_DEPTH	equ 6
	
MAIN:	
	; Setup bitplane data
	lea bitplanes(pc),a0 
	move.w #61201,d0
.loop:
	move.b #$AA,(a0)+
	dbra d0,.loop

	; Install interrupt handler
	lea	level3InterruptHandler(pc),a3
 	move.l	a3,LVL3_INT_VECTOR

	;  Move sprite 0 to $25000
	MOVE.L  #$25000,a1 ;Point A1 at sprite destination
	LEA     SPRITE0(pc),a2 ;Point A2 at sprite source
SPRLOOP0:	
	MOVE.L  (a2),(a1)+ ;Move a long word
	CMP.L   #$00000000,(a2)+ ;Check for end of sprite
	BNE     SPRLOOP0	 ;Loop until entire sprite is moved

	;  Move sprite 2 to $26000
	MOVE.L  #$26000,a1 ;Point A1 at sprite destination
	LEA     SPRITE2(pc),a2 ;Point A2 at sprite source
SPRLOOP2:	
	MOVE.L  (a2),(a1)+ ;Move a long word
	CMP.L   #$00000000,(a2)+ ;Check for end of sprite
	BNE     SPRLOOP2	 ;Loop until entire sprite is moved

	;  Move sprite 4 to $27000
	MOVE.L  #$27000,a1 ;Point A1 at sprite destination
	LEA     SPRITE4(pc),a2 ;Point A2 at sprite source
SPRLOOP4:	
	MOVE.L  (a2),(a1)+ ;Move a long word
	CMP.L   #$00000000,(a2)+ ;Check for end of sprite
	BNE     SPRLOOP4	 ;Loop until entire sprite is moved

	;  Move sprite 6 to $28000
	MOVE.L  #$28000,a1 ;Point A1 at sprite destination
	LEA     SPRITE6(pc),a2 ;Point A2 at sprite source
SPRLOOP6:	
	MOVE.L  (a2),(a1)+ ;Move a long word
	CMP.L   #$00000000,(a2)+ ;Check for end of sprite
	BNE     SPRLOOP6	 ;Loop until entire sprite is moved

	;;
	;;  Now we write a dummy sprite to $30000, since all eight sprites are activated
	;;  at the same time and we're only going to use one. The remaining sprites
	;;  will point to this dummy sprite data.
	;;
	MOVE.L  #$00000000,$30000 ;Write it

	;; Install copper list and enable DMA
	lea 	CUSTOM,a1
	lea	copper(pc),a0
	move.l	a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0
	move.w  #(DMAF_SETCLR!DMAF_COPPER!32!DMAF_RASTER!DMAF_MASTER),dmacon(a1)
	; MOVE.W  #$83A0,DMACON(a1) ;Bitplane, Copper, and sprite DMA

.mainLoop:
	bra.b	.mainLoop

level3InterruptHandler:
	movem.l	d0-a6,-(sp)
	lea 	CUSTOM,a5
	move.w	#$3FFF,INTREQ(a5)	; Acknowledge
	lea     bitplanes(pc),a2
	lea     BPL1PTH(a5),a3
	move.l	a2,(a3)
	movem.l	(sp)+,d0-a6
	rte

copper:
	dc.w    DIWSTRT,$2c81
	dc.w	DIWSTOP,$2cc1
	dc.w    DDFSTRT,$0040
	dc.w	DDFSTOP,$00D8
	dc.w	BPLCON0,(1<<12)|$200 ; 1 bitplane
	dc.w	BPL1MOD,SCREEN_WIDTH_BYTES*SCREEN_BIT_DEPTH-SCREEN_WIDTH_BYTES
	dc.w	BPL2MOD,SCREEN_WIDTH_BYTES*SCREEN_BIT_DEPTH-SCREEN_WIDTH_BYTES

	dc.w    BPLCON1,$FF
 
	DC.W    SPR0PTH,$0002 ;Sprite 0 pointer = $25000
	DC.W    SPR0PTL,$5000
	DC.W    SPR1PTH,$0003 ;Sprite 1 pointer = $30000
	DC.W    SPR1PTL,$0000
	DC.W    SPR2PTH,$0002 ;Sprite 2 pointer = $26000
	DC.W    SPR2PTL,$6000
	DC.W    SPR3PTH,$0003 ;Sprite 3 pointer = $30000
	DC.W    SPR3PTL,$0000
	DC.W    SPR4PTH,$0002 ;Sprite 4 pointer = $27000
	DC.W    SPR4PTL,$7000
	DC.W    SPR5PTH,$0003 ;Sprite 5 pointer = $30000
	DC.W    SPR5PTL,$0000
	DC.W    SPR6PTH,$0002 ;Sprite 6 pointer = $28000
	DC.W    SPR6PTL,$8000
	DC.W    SPR7PTH,$0003 ;Sprite 7 pointer = $30000
	DC.W    SPR7PTL,$0000
	DC.W    COLOR17,$066F 
	DC.W    COLOR18,$0444 
	DC.W    COLOR19,$0F00 
	DC.W    COLOR21,$06F6 
	DC.W    COLOR22,$0444 
	DC.W    COLOR23,$0F00 
	DC.W    COLOR25,$0FF0 
	DC.W    COLOR26,$0444 
	DC.W    COLOR27,$0F00 
	DC.W    COLOR29,$0CCC 
	DC.W    COLOR30,$0444 
	DC.W    COLOR31,$0F00 
	
   ; First color block
	dc.w	$3001,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    COLOR01,$66F
	dc.w	$30D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000
	dc.w    DDFSTRT,$0048
	dc.w	DDFSTOP,$00D0

	dc.w	$3801,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$38D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000
	dc.w    DDFSTRT,$0050
	dc.w	DDFSTOP,$00C8

  ; Second color block
	dc.w	$8001,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    COLOR01,$B6F
	dc.w	$80D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000
	dc.w    DDFSTRT,$0058
	dc.w	DDFSTOP,$00C0

	dc.w	$8801,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$88D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000
	dc.w    DDFSTRT,$0058
	dc.w	DDFSTOP,$00C0

	; Third color block
	dc.w    $D001,$FFFE  ; WAIT
	dc.w	COLOR00, $F00
	dc.w    COLOR01,$F6F
	dc.w    $D0D9,$FFFE  ; WAIT
	dc.w	COLOR00, $000
	dc.w    DDFSTRT,$0060
	dc.w	DDFSTOP,$00B8

	dc.w    $D801,$FFFE  ; WAIT
	dc.w	COLOR00, $F00
	dc.w    $D8D9,$FFFE  ; WAIT
	dc.w	COLOR00, $000
	dc.w    DDFSTRT,$0060
	dc.w	DDFSTOP,$00B0

	dc.w    $ffdf,$fffe ; Cross vertical boundary

	; Fourth color block
	dc.w    $2001,$FFFE  ; WAIT
	dc.w	COLOR00, $F00
	dc.w    COLOR01,$F6B
	dc.w    $20D9,$FFFE  ; WAIT
	dc.w	COLOR00, $000
	dc.w    DDFSTRT,$0068
	dc.w	DDFSTOP,$00A8

	dc.w    $2801,$FFFE  ; WAIT
	dc.w	COLOR00, $F00
	dc.w    $28D9,$FFFE  ; WAIT
	dc.w	COLOR00, $000
	dc.w    DDFSTRT,$0070
	dc.w	DDFSTOP,$00A0

	dc.l	$fffffffe

	;;
	;;  Sprite data 
	;;

SPRITE0:
			DC.W    $2D53,$3D00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $7D63,$8D00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $CD6B,$DD00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $1D73,$2D04 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
	        DC.W    $0000,$0000 ; End of sprite data

SPRITE2:
			DC.W    $4D5B,$5D00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $9D63,$AD00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $ED6B,$FD00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $0D6B,$1D04 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
	        DC.W    $0000,$0000 ; End of sprite data

SPRITE4:
			DC.W    $2DE3,$3D00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $7DD3,$8D00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $CDCB,$DD00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $1DBA,$2D04 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
	        DC.W    $0000,$0000 ; End of sprite data

SPRITE6:
			DC.W    $4DDB,$5D00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $9DD3,$AD00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $EDC3,$FD00 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
			DC.W    $0DC3,$1D04 ;VSTART, HSTART, VSTOP
	        DC.W    $03C0,$0000 ; 0
	        DC.W    $0FF0,$0000 ; 1
	        DC.W    $1C78,$0380 ; 2
	        DC.W    $3DFC,$0380 ; 3
	        DC.W    $7DFE,$0380 ; 4
	        DC.W    $7FF8,$0000 ; 5
	        DC.W    $FFE0,$0000 ; 6
	        DC.W    $FF00,$0000 ; 7
	        DC.W    $FF00,$0000 ; 8
	        DC.W    $FFE0,$0000 ; 9
	        DC.W    $7FF8,$0000 ; 10
	        DC.W    $7FFE,$0000 ; 11
	        DC.W    $3FFC,$0000 ; 13
	        DC.W    $1FF8,$0000 ; 14
	        DC.W    $0FF0,$0000 ; 14
	        DC.W    $03C0,$0000 ; 15
			;
	        DC.W    $0000,$0000 ; End of sprite data

SPRITE_END: DC.W    $0000,$0001 ; Copy until we get here

bitplanes:
	ds.b    61201
	