	include "../../../include/registers.i"
	include "../../../include/ministartup.i"

;
; cpucol2 -- cpucol with the cache held on throughout, instead of toggled
; section by section.
;
; This is cpucol's own program, with two substitutions: every CACHEOFF in
; the copper list below is CACHEON instead, so the instruction cache
; never gets turned off. irqcacheon keeps installing irq3_red (GREEN/
; YELLOW) at every section, and since CACHEOFF is never invoked,
; irqcacheoff and irq3_blue are never reached -- they're kept only for
; structural symmetry with cpucol, with irq3_blue's colour changed from
; RED to GREEN so there's no stray reference to a state this test never
; visits. See cpucol.s's own header for the full mechanism (the six-write
; colour toggle, STOP discipline, HPOS/HPSTEP row sampling, why there are
; two colour-handler copies at all); cpucol3 is this file's cache-off
; counterpart.
;
; With cache state no longer varying between a pair's two halves (both
; are cache-on now), giving them the same six trigger positions would
; make the second half's row of colour segments repeat the first half's
; exactly -- same colours, same cache state, same DMA background, same
; horizontal sample points. To keep the two halves independent, the
; second half of each bitplane-count pair (sections 2/4/6/8/10) triggers
; one Copper position later than the first (HPOS2 vs. HPOS below): the
; smallest actual shift available, since a Copper WAIT's horizontal field
; only compares in steps of 2 (bit 0 is reserved as the WAIT-vs-MOVE
; flag, not part of the position).
;

LVL1_INT_VECTOR		equ $64
LVL2_INT_VECTOR		equ $68
LVL3_INT_VECTOR		equ $6c

; Cache-enabled sections toggle GREEN/YELLOW; cache-disabled sections
; toggle RED/YELLOW. YELLOW is shared, so the toggle partner is what
; actually marks the two states apart. Every section here is cache-
; enabled, so GREEN/YELLOW is what actually appears; RED stays defined
; only because irq3_blue (unreachable, see above) still names it.
GREEN               equ $0F0
RED                 equ $F00
YELLOW              equ $FF0

; CACR: bit 0 enables the instruction cache, all other bits (flush,
; freeze, burst...) left clear. Same values used by CPU/68020/ICache.
CACR_ON             equ $0001
CACR_OFF            equ $0000

; The first trigger's horizontal position, and how far each subsequent row
; in a section moves it. Must stay ODD -- bit 0 of a Copper WAIT's first
; word is not part of the horizontal compare, it is fixed at 1 to mark the
; instruction as a WAIT rather than a MOVE. See copbbusy.i for the details
; and the empirical evidence (even values there caused rows to collide).
; HPSTEP is even, so HPOS+n*HPSTEP stays odd for every row.
;
; HPOS2 is the second half of each pair's base position -- one Copper
; position (2) later than HPOS, and still odd since that offset is even.
HPOS                equ $41
HPSTEP              equ $4
HPOFFSET            equ $2
HPOS2               equ HPOS+HPOFFSET

; One measurement: wait for the trigger position, then hand off to the CPU.
TRIGGER	MACRO
	dc.w    (\1)<<8|(\2),$FFFE
	dc.w    INTREQ,$8010
	ENDM

; One-shot, fired once at the top of a section: no WAIT of its own, since
; it only needs to run sometime before that section's first TRIGGER, and
; the section's own ruler WAIT has already put the Copper well before it.
CACHEON	MACRO
	dc.w    INTREQ,$8004        ; SOFT -- level 1
	ENDM

CACHEOFF MACRO
	dc.w    INTREQ,$8008        ; PORTS -- level 2
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

	; Does this CPU have a cache worth toggling? AFB_68020 (bit 1 of
	; AttnFlags) is also set for the 68030 and up; 68000/68010 have no
	; on-chip cache and leave it clear. ExecBase is already valid here --
	; ministartup's own START used it (via $4.w) before calling MAIN.
	move.l  $4.w,a0
	move.w  296(a0),d0
	btst    #1,d0
	sne     is020plus

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

	; Install the interrupt handlers this test needs: the colour writer
	; (starts as the green/cache-on copy, matching section 1) plus the
	; two cache-toggle handlers
	lea	    irq3_red(pc),a3
 	move.l	a3,LVL3_INT_VECTOR
	lea	    irqcacheon(pc),a3
	move.l	a3,LVL1_INT_VECTOR
	lea	    irqcacheoff(pc),a3
	move.l	a3,LVL2_INT_VECTOR

	; Setup Copper
	lea	    copper(pc),a0
	move.l	a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0
	move.w  #$0000,COPCON(a1)  ; the Copper never touches Blitter registers

	; Enable DMA
	move.w	#$8080,DMACON(a1)   ; Copper DMA
	move.w	#$8100,DMACON(a1)   ; Bitplane DMA
	move.w	#$8200,DMACON(a1)   ; DMAEN

	; Enable the three Copper-triggered interrupts: COPER (colour),
	; SOFT (cache on), PORTS (cache off)
	move.w	#$C01C,INTENA(a1)

.wait:
	bra.b	.wait                ; until the first trigger


; ---------------------------------------------------------------------------
; The CPU's only job: write the colour sequence, then get off the bus.
; ---------------------------------------------------------------------------

irq3_red:
	lea     sstack,a7           ; the handler never returns; keep the stack
	lea     CUSTOM,a1           ; bounded
	move.w  #$0010,INTREQ(a1)   ; acknowledge (COPER)

	move.w  #GREEN,COLOR00(a1)
	move.w  #YELLOW,COLOR00(a1)
	move.w  #GREEN,COLOR00(a1)
	move.w  #YELLOW,COLOR00(a1)
	move.w  #GREEN,COLOR00(a1)
	move.w  #YELLOW,COLOR00(a1)
	move.w  #$FFF,COLOR00(a1)
	move.w  #$000,COLOR00(a1)

	stop    #$2000               ; no bus cycles until the next trigger

irq3_blue:
	lea     sstack,a7           ; the handler never returns; keep the stack
	lea     CUSTOM,a1           ; bounded
	move.w  #$0010,INTREQ(a1)   ; acknowledge (COPER)

	move.w  #GREEN,COLOR00(a1)
	move.w  #YELLOW,COLOR00(a1)
	move.w  #GREEN,COLOR00(a1)
	move.w  #YELLOW,COLOR00(a1)
	move.w  #GREEN,COLOR00(a1)
	move.w  #YELLOW,COLOR00(a1)
	move.w  #$FFF,COLOR00(a1)
	move.w  #$000,COLOR00(a1)

	stop    #$2000               ; no bus cycles until the next trigger


; ---------------------------------------------------------------------------
; Section-boundary handlers: switch the colour handler and the cache state
; together, then go straight back to sleep. Neither is on the timing-
; critical path -- both fire, and both return to STOP, well before the
; section's own row triggers reach the CPU. irqcacheoff is installed but
; never triggered, since the copper list below never invokes CACHEOFF.
; ---------------------------------------------------------------------------

irqcacheon:
	lea     sstack,a7
	lea     CUSTOM,a1
	move.w  #$0004,INTREQ(a1)   ; acknowledge (SOFT)
	move.b  is020plus,d1
	tst.b   d1
	beq.s   .noCache
	move.w  #CACR_ON,d0
	movec   d0,cacr
.noCache:
	lea     irq3_red(pc),a0
	move.l  a0,LVL3_INT_VECTOR
	stop    #$2000

irqcacheoff:
	lea     sstack,a7
	lea     CUSTOM,a1
	move.w  #$0008,INTREQ(a1)   ; acknowledge (PORTS)

	move.b  is020plus,d1
	tst.b   d1
	beq.s   .noCache
	move.w  #CACR_OFF,d0
	movec   d0,cacr
.noCache:
	lea     irq3_blue(pc),a0
	move.l  a0,LVL3_INT_VECTOR

	stop    #$2000


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
	include "copperline.i"
	dc.w    BPLCON0, (0<<12)|$200
	CACHEON
	TRIGGER $42,HPOS
	TRIGGER $44,HPOS+HPSTEP
	TRIGGER $46,HPOS+HPSTEP*2
	TRIGGER $48,HPOS+HPSTEP*3
	TRIGGER $4A,HPOS+HPSTEP*4
	TRIGGER $4C,HPOS+HPSTEP*5

    ;
    ; Section 2
    ;

  	dc.w    $5039, $FFFE
	include "copperline.i"
	dc.w    BPLCON0, (0<<12)|$200
	CACHEON
	TRIGGER $52,HPOS2
	TRIGGER $54,HPOS2+HPSTEP
	TRIGGER $56,HPOS2+HPSTEP*2
	TRIGGER $58,HPOS2+HPSTEP*3
	TRIGGER $5A,HPOS2+HPSTEP*4
	TRIGGER $5C,HPOS2+HPSTEP*5

    ;
    ; Section 3
    ;

  	dc.w    $6039, $FFFE
	include "copperline.i"
	dc.w    BPLCON0, (1<<12)|$200
	CACHEON
	TRIGGER $62,HPOS
	TRIGGER $64,HPOS+HPSTEP
	TRIGGER $66,HPOS+HPSTEP*2
	TRIGGER $68,HPOS+HPSTEP*3
	TRIGGER $6A,HPOS+HPSTEP*4
	TRIGGER $6C,HPOS+HPSTEP*5

    ;
    ; Section 4
    ;

  	dc.w    $7039, $FFFE
	include "copperline.i"
	dc.w    BPLCON0, (1<<12)|$200
	CACHEON
	TRIGGER $72,HPOS2
	TRIGGER $74,HPOS2+HPSTEP
	TRIGGER $76,HPOS2+HPSTEP*2
	TRIGGER $78,HPOS2+HPSTEP*3
	TRIGGER $7A,HPOS2+HPSTEP*4
	TRIGGER $7C,HPOS2+HPSTEP*5

    ;
    ; Section 5
    ;

  	dc.w    $8039, $FFFE
	include "copperline.i"
	dc.w    BPLCON0, (2<<12)|$200
	CACHEON
	TRIGGER $82,HPOS
	TRIGGER $84,HPOS+HPSTEP
	TRIGGER $86,HPOS+HPSTEP*2
	TRIGGER $88,HPOS+HPSTEP*3
	TRIGGER $8A,HPOS+HPSTEP*4
	TRIGGER $8C,HPOS+HPSTEP*5

    ;
    ; Section 6
    ;

  	dc.w    $9039, $FFFE
	include "copperline.i"
	dc.w    BPLCON0, (2<<12)|$200
	CACHEON
	TRIGGER $92,HPOS2
	TRIGGER $94,HPOS2+HPSTEP
	TRIGGER $96,HPOS2+HPSTEP*2
	TRIGGER $98,HPOS2+HPSTEP*3
	TRIGGER $9A,HPOS2+HPSTEP*4
	TRIGGER $9C,HPOS2+HPSTEP*5

    ;
    ; Section 7
    ;

  	dc.w    $A039, $FFFE
	include "copperline.i"
	dc.w    BPLCON0, (3<<12)|$200
	CACHEON
	TRIGGER $A2,HPOS
	TRIGGER $A4,HPOS+HPSTEP
	TRIGGER $A6,HPOS+HPSTEP*2
	TRIGGER $A8,HPOS+HPSTEP*3
	TRIGGER $AA,HPOS+HPSTEP*4
	TRIGGER $AC,HPOS+HPSTEP*5

    ;
    ; Section 8
    ;

  	dc.w    $B039, $FFFE
	include "copperline.i"
	dc.w    BPLCON0, (3<<12)|$200
	CACHEON
	TRIGGER $B2,HPOS2
	TRIGGER $B4,HPOS2+HPSTEP
	TRIGGER $B6,HPOS2+HPSTEP*2
	TRIGGER $B8,HPOS2+HPSTEP*3
	TRIGGER $BA,HPOS2+HPSTEP*4
	TRIGGER $BC,HPOS2+HPSTEP*5

    ;
    ; Section 9
    ;

  	dc.w    $C039, $FFFE
	include "copperline.i"
	dc.w    BPLCON0, (4<<12)|$200
	CACHEON
	TRIGGER $C2,HPOS
	TRIGGER $C4,HPOS+HPSTEP
	TRIGGER $C6,HPOS+HPSTEP*2
	TRIGGER $C8,HPOS+HPSTEP*3
	TRIGGER $CA,HPOS+HPSTEP*4
	TRIGGER $CC,HPOS+HPSTEP*5

    ;
    ; Section 10
    ;

  	dc.w    $D039, $FFFE
	include "copperline.i"
	dc.w    BPLCON0, (4<<12)|$200
	CACHEON
	TRIGGER $D2,HPOS2
	TRIGGER $D4,HPOS2+HPSTEP
	TRIGGER $D6,HPOS2+HPSTEP*2
	TRIGGER $D8,HPOS2+HPSTEP*3
	TRIGGER $DA,HPOS2+HPSTEP*4
	TRIGGER $DC,HPOS2+HPSTEP*5

	; Cross vertical boundary
	dc.w    $ffdf,$fffe

	dc.l    $fffffffe

is020plus:
	dc.b    0
	even

	ds.l    64
sstack:
spare:
	ds.w    1024,$00
bitplanes:
	ds.b    32768,$00
