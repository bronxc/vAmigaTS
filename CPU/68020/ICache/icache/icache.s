;
; icache -- the 68020 instruction cache and self-modifying code, in two
; colours: yellow means the CPU executed the instruction we just wrote,
; black means it executed the one that was there before.
;
;
; WHAT EACH STRIPE ASKS
; ---------------------
;
; The self-modified instruction is a single stub:
;
;   stub:  move.w  #$0000,(a3)     ; a3 -> a word of the Copper list
;          rts
;
; Opcode and immediate share one cache longword, so one fetch decides
; the whole instruction. Every stripe runs the same two-part recipe:
;
;   PRIME   poke the stub's immediate to black, flush the whole cache
;           (CACR bit 3) with the cache enabled and unfrozen, then call
;           the stub. A guaranteed miss: black is fetched fresh and the
;           fill caches that fetch.
;
;   TEST    apply this stripe's CACR value, poke the immediate to
;           yellow, and call the stub again.
;
; If the CACR value left the primed line valid, the second call hits it
; and runs the cached black write -- the yellow poke never took effect
; from the CPU's point of view. If it invalidated that line (or the
; cache is off outright), the call misses, fetches the fresh yellow
; immediate, and yellow is what shows.
;
; Six CACR values, repeated twice for confidence:
;
;   $0000  off                          miss regardless:              yellow
;   $0001  on, unchanged from priming    still valid, hits:            black
;   $0005  on, CE (invalidate this line) invalidated, miss:            yellow
;   $0003  on, frozen, no invalidate     still valid, hits:            black
;   $0007  on, frozen + CE               invalidated, frozen so it
;                                        cannot refill either: miss:   yellow
;   $0009  on, C (flush everything)      invalidated, miss:            yellow
;
; CAAR is set once per frame to the stub's own address -- every CE in
; this test means "invalidate the stub's line", nothing else.
;
;
; WHY EVERYTHING RUNS IN VERTICAL BLANK
; -------------------------------------
;
; All twelve trials run back to back inside the level 3 handler, once
; per frame, and none of them touch COLOR00. Each one writes its answer
; into a data word of the Copper list instead. The Copper then runs an
; unchanging list for the whole visible frame and simply moves each
; stripe's word into COLOR00 when it reaches that stripe's line.
;
; That removes the picture's dependence on CPU speed completely. The
; earlier design raised an interrupt once per stripe and had the handler
; write COLOR00 directly, which meant the handler was racing the beam:
; its PRIME step genuinely writes black before the TEST step writes the
; real answer, so if the interrupt fired anywhere the beam was already
; scanning a recorded line, that intermediate black was exactly as
; visible as the final answer. Widening the margin only ever moved the
; race, it never removed it -- on a real Amiga 1200 the transient was
; plainly visible at the top of every stripe even with eight lines of
; slack. Here the handler runs where the beam is not, the Copper reads
; the results long afterwards, and there is no margin to tune.
;
;
; THE STUB MUST BE LONGWORD ALIGNED
; ---------------------------------
;
; This is not a detail, it is the difference between the test working
; and quietly testing nothing. `move.w #imm,(a3)` is two words: the
; opcode and the immediate. Only if they share one longword does a
; single cache entry cover both, and only then does "invalidate the
; stub's line" invalidate the whole instruction.
;
; Put the stub on an odd word and the opcode lands at the end of one
; longword while the immediate -- the word this test actually rewrites
; -- lands at the start of the next. A CE aimed at CAAR = stub then
; clears the opcode's entry and leaves the stale immediate being served
; from the entry beside it, so the CE and CE+freeze stripes come out
; black and look exactly like a CPU that ignores CACR bit 2. This test
; shipped in that state for a while, and a real A1200 reproduced it
; faithfully, which is worth remembering: the hardware agreeing with the
; emulator says nothing about whether either agrees with what you meant
; to ask. prefetch1 in this directory is the test that draws this
; boundary-vs-alignment effect directly.
;
;
; MOVEC IS PRIVILEGED
; -------------------
;
; A MOVEC in MAIN's own top-level code takes a privilege violation here:
; the start-up code is not in supervisor mode by the time MAIN gets
; control. A hardware interrupt always enters supervisor mode regardless
; of what it interrupts, which is why every MOVEC in this test lives in
; irq3.
;

	include "../../../../include/registers.i"
	include "../../../../include/ministartup.i"

LVL3_INT_VECTOR     equ $6C

LINE0               equ $28             ; first line of the top rule
TOPRULE             equ 2
STRIPELINES         equ 10
STRIPES             equ 12

HP_BASE             equ $01             ; HP $00, start of line

PENDING_COLOR       equ $444            ; dark grey: the handler never ran
RULE_COLOR          equ $FFF
FRAME_COLOR         equ $006

BLACK               equ $0000
YELLOW              equ $0FF0

CACR_PRIME          equ $0009           ; C=1, E=1, F=0: flush all, allow fill
CACR_OFF            equ $0000
CACR_ON             equ $0001           ; E=1, F=0, unchanged from priming
CACR_CE             equ $0005           ; E=1, CE=1: invalidate the stub's line
CACR_FREEZE         equ $0003           ; E=1, F=1
CACR_FREEZE_CE      equ $0007           ; E=1, F=1, CE=1
CACR_C              equ $0009           ; E=1, C=1: invalidate every line

; Bytes of Copper list per stripe, and the offset of the colour word
; the handler writes within that block. Asserted below, so a change to
; the Copper list cannot silently desynchronise the handler's walk.
STRIPEBLK           equ 16
SLOTOFF             equ 6

MAIN:
	lea     CUSTOM,a1

	; Silence the machine, as in Memory/Rom/mirror/custom.i
	move.w  #$0200,BPLCON0(a1)
	move.w  #$7FFF,INTENA(a1)
	move.w  #$7FFF,DMACON(a1)
	move.b  #$7F,$BFDD00
	move.b  #$7F,$BFED01

	; The only handler in this test. Everything runs out of vertical
	; blank; the Copper raises no interrupt at all.
	lea     irq3(pc),a0
	move.l  a0,LVL3_INT_VECTOR

	lea     stub(pc),a2
	addq.w  #2,a2                   ; a2 -> the stub's immediate field

	lea     copper(pc),a0
	move.l  a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0

	move.w  #$8280,DMACON(a1)       ; Copper DMA only
	move.w  #$C020,INTENA(a1)       ; master, VBlank (3)

.mainLoop:
	bra.b   .mainLoop


; ---------------------------------------------------------------------------
; Level 3, vertical blank -- every trial for every stripe runs here, once
; per frame, before the Copper has drawn anything this test cares about.
;
; The stub and this handler sit next to each other on purpose: see the
; span assertion below.
; ---------------------------------------------------------------------------

	cnop    0,4
span:

	; The stub is placed first so that its alignment is fixed by this
	; cnop and cannot drift when the handler above it changes length.
stub:
	; The compiled-in placeholder is not $0000: vasm quietly turns
	; "move.w #0,(a3)" into the 2-byte "clr.w (a3)" (no immediate word
	; at all), which would leave the pokes below overwriting the RTS
	; instead of an operand. Any non-zero placeholder keeps the full
	; 4-byte move-immediate encoding; it is only ever visible for the
	; very first fetch of the very first frame, before the first prime.
	move.w  #$BEEF,(a3)
	rts

irq3:
	movem.l d0-a6,-(sp)

	; CAAR is set once per frame. Every CE below means the same thing.
	lea     stub(pc),a0
	move.l  a0,d0
	movec   d0,caar

	lea     table(pc),a4            ; walks the CACR test values
	lea     slots(pc),a5
	addq.w  #SLOTOFF,a5             ; -> the first stripe's colour word
	moveq   #STRIPES-1,d7

.loop:
	move.l  a5,a3                   ; this stripe's Copper-list word

	; PRIME: guarantee a fresh, valid, black cache line for the stub.
	move.w  #BLACK,(a2)
	move.w  #CACR_PRIME,d0
	movec   d0,cacr
	jsr     stub(pc)

	; TEST: apply this stripe's CACR value, then attempt the poke.
	move.w  (a4)+,d0
	movec   d0,cacr
	move.w  #YELLOW,(a2)
	jsr     stub(pc)

	lea     STRIPEBLK(a5),a5
	dbra    d7,.loop

	move.w  #$0020,INTREQ(a1)
	movem.l (sp)+,d0-a6
	rte

spanend:

	; The cache is direct-mapped on address bits 7..2, so any two
	; addresses exactly 256 bytes apart share an entry. Between PRIME
	; and TEST this handler executes its own instructions, and if any
	; of them aliased the stub's entry it would evict the very line the
	; trial depends on -- the CE stripes would still come out yellow,
	; but so would the ON and FREEZE stripes, and for the wrong reason.
	; Keeping the stub and the handler inside one 256 byte span makes
	; that impossible by construction rather than by inspecting a link
	; map that changes every time this file does.
	ifgt    (spanend-span)-250
	FAIL    "stub and handler span 256 bytes or more: they can alias"
	endc

table:
	dc.w    CACR_OFF          ; 1  yellow  cache off
	dc.w    CACR_ON           ; 2  black   HIT: primed line survives
	dc.w    CACR_CE           ; 3  yellow  invalidated
	dc.w    CACR_FREEZE       ; 4  black   HIT: freeze alone doesn't clear it
	dc.w    CACR_FREEZE_CE    ; 5  yellow  invalidated, frozen so it stays that way
	dc.w    CACR_C            ; 6  yellow  invalidated (flush all)
	dc.w    CACR_OFF          ; 7  yellow  (repeat, for confidence)
	dc.w    CACR_ON           ; 8  black
	dc.w    CACR_CE           ; 9  yellow
	dc.w    CACR_FREEZE       ; 10 black
	dc.w    CACR_FREEZE_CE    ; 11 yellow
	dc.w    CACR_C            ; 12 yellow


; ---------------------------------------------------------------------------
; The copper list
;
; Each stripe waits for its own line and moves its own colour word into
; COLOR00. Nothing here is conditional and nothing here is timed against
; the CPU: by the time the Copper reaches the first stripe, every word
; has held its final value since vertical blank.
; ---------------------------------------------------------------------------

copper:
	dc.w    BPLCON0,$0200
	dc.w    COLOR00,FRAME_COLOR

CLINE   set     LINE0

	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00,RULE_COLOR
CLINE   set     CLINE+TOPRULE

slots:
	rept    STRIPES

	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00
	dc.w    PENDING_COLOR           ; <- the word the handler rewrites
CLINE   set     CLINE+STRIPELINES

	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00,RULE_COLOR
CLINE   set     CLINE+1

	endr

slotsend:

	dc.w    ((CLINE<<8)|HP_BASE),$FFFE
	dc.w    COLOR00,FRAME_COLOR

	; The handler walks the list above in fixed strides instead of
	; carrying a table of twelve pointers, so the stride and the offset
	; of the colour word inside each block have to be what it thinks.
	ifne    (slotsend-slots)-(STRIPES*STRIPEBLK)
	FAIL    "STRIPEBLK does not match the Copper list's stripe block"
	endc
	ifgt    CLINE-255
	FAIL    "the band runs past raster line 255"
	endc

	dc.l    $FFFFFFFE
