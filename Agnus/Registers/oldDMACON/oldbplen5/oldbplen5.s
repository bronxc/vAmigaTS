	include "../../../../include/registers.i"
	include "hardware/dmabits.i"
	include "hardware/intbits.i"
	
LVL3_INT_VECTOR		equ $6c
SCREEN_WIDTH_BYTES	equ (320/8)
SCREEN_BIT_DEPTH	equ 5
	
entry:	
	lea	level3InterruptHandler(pc),a3
 	move.l	a3,LVL3_INT_VECTOR

	;; install copper list and enable DMA
	lea 	CUSTOM,a1
	lea	copper(pc),a0
	move.l	a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0
	move.w  #(DMAF_SETCLR!DMAF_COPPER!DMAF_RASTER!DMAF_MASTER),dmacon(a1)
	
.mainLoop:
	bra.b	.mainLoop

level3InterruptHandler:
	movem.l	d0-a6,-(sp)

.checkVerticalBlank:
	lea	CUSTOM,a5
	move.w	INTREQR(a5),d0
	and.w	#INTF_VERTB,d0	
	beq.s	.checkCopper

.verticalBlank:
	move.w	#INTF_VERTB,INTREQ(a5)	; clear interrupt bit	

.enableDMA:
	move.w  #$8200,DMACON(a5)

.resetBitplanePointers:
	lea	bitplanes(pc),a1
	lea     BPL1PTH(a5),a2
	moveq	#SCREEN_BIT_DEPTH-1,d0
.bitplaneloop:
	move.l	a1,(a2)
	lea	SCREEN_WIDTH_BYTES(a1),a1 ; bit plane data is interleaved
	addq	#4,a2
	dbra	d0,.bitplaneloop
	
.checkCopper:
	lea	CUSTOM,a5
	move.w	INTREQR(a5),d0
	and.w	#INTF_COPER,d0	
	beq.s	.interruptComplete
.copperInterrupt:
	move.w	#INTF_COPER,INTREQ(a5)	; clear interrupt bit	
	
.interruptComplete:
	movem.l	(sp)+,d0-a6
	rte

copper:
	dc.w    DIWSTRT,$2c71 
	dc.w	DIWSTOP,$2cd1
	dc.w	BPLCON0,(SCREEN_BIT_DEPTH<<12)|$200 ; set color depth and enable COLOR
	dc.w	BPL1MOD,SCREEN_WIDTH_BYTES*SCREEN_BIT_DEPTH-SCREEN_WIDTH_BYTES
	dc.w	BPL2MOD,SCREEN_WIDTH_BYTES*SCREEN_BIT_DEPTH-SCREEN_WIDTH_BYTES
 
 	include	"out/image-copper-list.s"


    ; Set number of bitplanes to 4, so Copper cannot be blocked by bitplane DMA.
	dc.w	BPLCON0,(4<<12)|$200

    ; First color block 
	dc.w	$3001,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$3181,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$3191,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$31D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$3801,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$3881,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$3899,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$38D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$4001,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$4081,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$40A1,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$40D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$4801,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$4881,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$48A9,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$48D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$5001,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$5081,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$50B1,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$50D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$5801,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$5881,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$58B9,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$58D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	; Second color block (toggle on and off in the middle of a DMA line)
	dc.w	$7001,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$7181,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$7191,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$71D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$7801,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$7881,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$7891,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$78D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$8001,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$8181,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$8191,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$81D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$8801,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$8881,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$8891,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$88D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$9001,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$9181,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$9191,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$91D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$9801,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$9881,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$9891,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$98D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	dc.w	$A001,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w	$A081,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$A091,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$A0D9,$FFFE  ; WAIT 
	dc.w	COLOR00, $000

	; Third color block (toggle on and off at the end of a DMA line)
	dc.w	$B823,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$B851,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$B891,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$B8D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.w	$C029,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$C051,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$C091,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$C0D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.w	$C82B,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$C851,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$C891,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$C8D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.w	$D02F,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$D051,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$D091,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$D0D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.w	$D831,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$D851,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$D891,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$D8D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.w	$E033,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$E051,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$E091,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$E0D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.w    $ffdf,$fffe ; Cross vertical boundary

; Fourth color block (toggle on and off multiple times in a rasterline, switch DMA off gliobally)
	dc.w	$002B,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$0031,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$0091,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$00D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.w	$082B,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$082F,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$0891,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$08D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.w	$102B,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$102D,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$1091,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$10D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.w	$1829,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$182B,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$1891,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$18D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.w	$2027,$FFFE  ; WAIT 
	dc.w	COLOR00, $F00
	dc.w    DMACON,$8100
	dc.w	$2029,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	$2091,$FFFE  ; WAIT 
	dc.w    DMACON,$8100
	dc.w	$20D9,$FFFE  ; WAIT 
	dc.w    DMACON,$0100
	dc.w	COLOR00, $000

	dc.l	$fffffffe

bitplanes:
	incbin	"out/image.bin"
	