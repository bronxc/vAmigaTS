	include "../../../../include/registers.i"
	include "../../../../include/ministartup.i"
	
LVL3_INT_VECTOR		equ $6c

COPPER 	MACRO
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
	dc.w  	BPLCON0,$2200
	dc.w  	BPL1MOD,0
	dc.w  	BPL2MOD,0
	ENDM

RULER	MACRO
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	dc.w    COLOR00,$F0F
	dc.w    COLOR00,$000
	ENDM

MAIN:
	; Load OCS base address
	lea     CUSTOM,a1
	
	; Disable interrupts, DMA and bitplanes
	move.w  #$7FFF,INTENA(a1)
	move.w  #$7FFF,DMACON(a1)
	move.w  #$0200,BPLCON0(a1)

	; Disable CIA interrupts
	move.b  #$7F,$BFDD00
	move.b  #$7F,$BFED01

	; Install interrupt handlers
	lea	    irq3(pc),a3
 	move.l	a3,LVL3_INT_VECTOR

	; Setup Copper
	lea	    copper,a0
	move.l	a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0

	; Setup colors
	move.w  #$000,COLOR00(a1)
	move.w  #$8AF,COLOR01(a1)
	move.w  #$CC4,COLOR02(a1)
	move.w  #$C44,COLOR03(a1)

	; Setup bitplane pointers
	lea     copper,a3

	lea     bitplane1(pc),a2
	move.l 	a2,d1
	move.w	d1,2(a3)
    swap    d1
	move.w	d1,6(a3)

	lea     bitplane2(pc),a2
	move.l 	a2,d1
	move.w	d1,10(a3)
    swap    d1
	move.w	d1,14(a3)

	; Setup bitplane data
	lea     bitplane1+10,a2
	moveq	#100,d0
.x1:
	move.w 	#$FFFF,(a2)+
	move.w 	#$0000,(a2)+
	add.w   #36+2,a2
	move.w 	#$FFFF,(a2)+
	move.w 	#$0000,(a2)+
	add.w   #32+2,a2
	dbra	d0,.x1
	;move.w 	#$CCCC,(a2)+
	;move.w 	#$CCCC,(a2)+

	lea     bitplane2+18,a2
	moveq	#100,d0
.x2:
	move.w 	#$FFFF,(a2)+
	move.w 	#$0000,(a2)+
	add.w   #36+2,a2
	move.w 	#$FFFF,(a2)+
	move.w 	#$0000,(a2)+
	add.w   #32+2,a2
	dbra	d0,.x2
	;move.w 	#$3333,(a2)+
	;move.w 	#$3333,(a2)+

	; Enable DMA
	move.w	#$8080,DMACON(a1)   ; Copper DMA 	
	move.w	#$8100,DMACON(a1)   ; Bitplane DMA 
	move.w	#$8200,DMACON(a1)   ; DMAEN 

	; Enable interrupts
	move.w	#$C020,INTENA(a1)

.mainLoop:
	bra.b	.mainLoop

irq3:
	move.w  #$3FFF,INTREQ(a1)         ; Acknowledge	
	rte

bitplane1:
	ds.b    16384,$00
bitplane2:
	ds.b    16384,$00
