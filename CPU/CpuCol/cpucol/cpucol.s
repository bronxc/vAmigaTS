	include "../../../include/registers.i"
	include "../../../include/ministartup.i"

;
; cpucol -- CPU register-write timing, with the Blitter and the Copper's
; own colour changes taken out of the measurement.
;
; This is the copbbusy design turned around: instead of the Copper starting
; the Blitter and waiting for BBUSY, the Copper fires a CPU interrupt and
; steps aside. The CPU's handler writes a fixed sequence of colours into
; COLOR00 -- six writes toggling between two colours, a white marker, then
; black -- and goes back to sleep. Toggling rather than a gradient: every
; write instant is a sharp edge between two maximally different colours,
; so it can be read directly off the picture instead of inferred from a
; shade boundary. The row that produces is a stripe of colour segments
; whose boundaries are the CPU's individual write instants: get the CPU's
; instruction timing or interrupt latency wrong, and the segment boundaries
; land on the wrong pixels.
;
; Sections come in pairs that share a bitplane count (0/0/1/1/2/2/3/3/4/4),
; so each pair repeats the same six-row layout twice. The second half of
; each pair is put to a second use: right before its row triggers, the
; Copper fires a separate, one-shot interrupt that disables the CPU's
; instruction cache (68020+ only -- see is020plus below); the matching
; trigger at the top of the first half of the next pair turns it back on.
; The colour pair marks which is which: green/yellow toggling for a
; cache-enabled section, red/yellow for a cache-disabled one, so the two
; halves of a pair are told apart at a glance as well as by row position.
; On a CPU with no cache (68000/68010) the toggle is a no-op and every
; section reads identically.
;
;   dc.w    (VP)<<8|(HP),$FFFE   ; wait for the trigger position
;   dc.w    INTREQ,$8010         ; request a level 3 (COPER) interrupt
;
; The interrupt vectors to a handler that acknowledges, writes the eight
; colours, and executes STOP. Nothing waits for the CPU -- the Copper moves
; straight on to the next trigger. There is no BBUSY-style rendezvous here
; because there is nothing on the hardware side to finish; the whole point
; is to see the CPU's own timing directly in the picture.
;
; STOP rather than a loop or an RTE: the handler never returns, so RTE
; would just accumulate stale exception frames, and a spin loop would still
; fetch (there is no instruction cache on a 68000 to spin from instead). A
; stopped CPU issues no bus cycles at all, and wakes cleanly on the next
; trigger's interrupt.
;
; The stack pointer is reset at the top of the handler for the same reason
; as in copbbusy: every trigger enters through an interrupt and never
; returns, so the frames would otherwise pile up for as long as the test
; runs -- here that is 60 times a frame instead of once.
;
; Within a section, each row's trigger position moves a little later in
; the line (see HPOS/HPSTEP below) than the row above it, so the same
; sequence gets sampled at six different phases against the DMA slot grid.
; The next section resets back to the original position. Six rows and ten
; sections mirror bbusy/copbbusy's layout, but nothing here depends on the
; Blitter, so there is only one version of this test -- no BLTCON0/BLTCON1/
; BLTSIZE combinations to multiply it by.
;
; MAIN itself waits for the first trigger with a busy loop, not STOP --
; exactly as copbbusy.i's MAIN does. STOP is privileged, and an earlier
; draft that executed it directly in MAIN took a privilege violation
; (confirmed on Amiberry: Guru #00000008). Once inside a handler, reached
; only through a real interrupt exception -- which always enters in
; supervisor mode -- STOP is exactly as safe as it is in copbbusy.i.
;
; The colour handler comes in two byte-for-byte identical copies, irq3_red
; and irq3_blue, differing only in which six immediate colour values they
; move into COLOR00. Two copies rather than one table-driven routine: an
; indexed load (colour table pointer, then six (a0)+ reads) is a different
; addressing mode from six immediate moves, with different timing, and
; that would confound the very thing being measured. Whichever copy is
; current is installed into LVL3_INT_VECTOR by the cache-toggle handlers
; below, so switching colour and switching cache state happen together, at
; the same section boundary, for the same reason.
;

LVL1_INT_VECTOR		equ $64
LVL2_INT_VECTOR		equ $68
LVL3_INT_VECTOR		equ $6c

; Cache-enabled sections toggle GREEN/YELLOW; cache-disabled sections
; toggle RED/YELLOW. YELLOW is shared, so the toggle partner is what
; actually marks the two states apart.
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
HPOS                equ $41
HPSTEP              equ $4

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
	; (starts as the red/cache-on copy, matching section 1) plus the two
	; cache-toggle handlers
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

	move.w  #RED,COLOR00(a1)
	move.w  #YELLOW,COLOR00(a1)
	move.w  #RED,COLOR00(a1)
	move.w  #YELLOW,COLOR00(a1)
	move.w  #RED,COLOR00(a1)
	move.w  #YELLOW,COLOR00(a1)
	move.w  #$FFF,COLOR00(a1)
	move.w  #$000,COLOR00(a1)

	stop    #$2000               ; no bus cycles until the next trigger


; ---------------------------------------------------------------------------
; Section-boundary handlers: switch the colour handler and the cache state
; together, then go straight back to sleep. Neither is on the timing-
; critical path -- both fire, and both return to STOP, well before the
; section's own row triggers reach the CPU.
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
	CACHEOFF
	TRIGGER $52,HPOS
	TRIGGER $54,HPOS+HPSTEP
	TRIGGER $56,HPOS+HPSTEP*2
	TRIGGER $58,HPOS+HPSTEP*3
	TRIGGER $5A,HPOS+HPSTEP*4
	TRIGGER $5C,HPOS+HPSTEP*5

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
	CACHEOFF
	TRIGGER $72,HPOS
	TRIGGER $74,HPOS+HPSTEP
	TRIGGER $76,HPOS+HPSTEP*2
	TRIGGER $78,HPOS+HPSTEP*3
	TRIGGER $7A,HPOS+HPSTEP*4
	TRIGGER $7C,HPOS+HPSTEP*5

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
	CACHEOFF
	TRIGGER $92,HPOS
	TRIGGER $94,HPOS+HPSTEP
	TRIGGER $96,HPOS+HPSTEP*2
	TRIGGER $98,HPOS+HPSTEP*3
	TRIGGER $9A,HPOS+HPSTEP*4
	TRIGGER $9C,HPOS+HPSTEP*5

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
	CACHEOFF
	TRIGGER $B2,HPOS
	TRIGGER $B4,HPOS+HPSTEP
	TRIGGER $B6,HPOS+HPSTEP*2
	TRIGGER $B8,HPOS+HPSTEP*3
	TRIGGER $BA,HPOS+HPSTEP*4
	TRIGGER $BC,HPOS+HPSTEP*5

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
	CACHEOFF
	TRIGGER $D2,HPOS
	TRIGGER $D4,HPOS+HPSTEP
	TRIGGER $D6,HPOS+HPSTEP*2
	TRIGGER $D8,HPOS+HPSTEP*3
	TRIGGER $DA,HPOS+HPSTEP*4
	TRIGGER $DC,HPOS+HPSTEP*5

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
