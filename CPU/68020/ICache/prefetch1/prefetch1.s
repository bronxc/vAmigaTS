;
; prefetch1 -- where the 68020 instruction cache's longword boundaries
; actually fall, made visible by counting instructions.
;
;
; WHAT THE USER MANUAL ACTUALLY SAYS
; ----------------------------------
;
; The passage this test grew out of:
;
;   "The MC68020 always prefetches long words. When an instruction
;    prefetch falls on an odd word boundary (e.g., due to a branch to an
;    odd word location), the MC68020 will read the even word associated
;    with the long word base address at the same time as (32-bit memory)
;    or before (8- or 16-bit memory) the odd word is read. When an
;    instruction prefetch falls on an even word boundary (as would be
;    the normal case), the MC68020 reads both words at the long word
;    address, thus effectively prefetching the next two words."
;
; It is easy to read that as "a misaligned fetch fills two cache lines".
; It does not. A cache entry *is* one longword, tagged by the longword
; address, and the lookup index is bits 7..2 of the address -- bits 1..0
; play no part in it. A fetch of the word at $1006 and a fetch of the
; word at $1004 are the same lookup, of the same single entry, covering
; the same single longword $1004..$1007. One fetch, one entry, always.
;
; What the passage is really about is the *bus*: on a 16-bit port, which
; is what an Amiga has everywhere, a fetch of the odd word alone would
; leave the entry only half filled, and the 68020 will not mark a
; half-filled entry valid. So it reads the even word too, even though
; nobody asked for it, and then has a complete longword to cache. The
; visible consequence is not two lines -- it is that the *entry point's
; alignment* decides how the instruction stream is carved into entries.
; Enter on an even word and the entries come out {i0,i1} {i2,i3} ...;
; enter one word later and they come out {--,i0} {i1,i2} {i3,i4} ... --
; the first entry carries only one instruction of the stream, because
; the other half of it is the word in front of the entry point.
;
; That partition is what this test draws. It is not a curiosity: icache
; in this directory quietly tested nothing for a while because its
; two-word stub straddled a longword boundary, so "invalidate the stub's
; line" invalidated the opcode and left the immediate cached beside it.
;
;
; HOW IT IS MEASURED
; ------------------
;
; Two identical chains of N `addq.w #1,d0` followed by an `rts`:
;
;   chainA   starts on an odd word (its longword's even half is a word
;            that is never executed)
;   chainB   starts on a longword boundary
;
; Both are self-modifying targets. One stripe of the picture is one
; trial, and every trial is self-contained:
;
;   RESTORE  write `addq.w #1,d0` over all N words of the chain.
;   PRIME    CACR = $0009 (flush everything, cache on, not frozen) and
;            call the chain. Every longword of it is fetched from memory
;            and cached. d0 comes back as N; the value is discarded.
;   BLANK    write `nop` over all N words of the chain, so every
;            instruction that is fetched from *memory* from here on
;            counts for nothing.
;   PUNCH    CAAR = the address of one chosen longword of the chain,
;            CACR = $0007 (cache on, CE, frozen): invalidate exactly
;            that one entry, and freeze so it cannot refill.
;   RUN      d0 = 0, call the chain again.
;
; Every instruction whose entry is still valid is served from the cache
; as the `addq` it was primed with and adds one. Only the instructions
; living inside the one punched-out longword are fetched from memory,
; where they are now `nop`s, and add nothing. So
;
;   d0 = N - (number of chain instructions in the punched longword)
;
; and d0 is used directly as an index into a 16-entry palette. The bar
; colour *is* the answer, read off a register.
;
; With N = 11, six stripes per chain, punching longwords 0..5 of each:
;
;   chainA   entry point on an odd word
;            longword 0 holds { filler, i0 }        -> 1 instruction
;            longwords 1..5 hold { i1,i2 } .. { i9,i10 } -> 2 each
;            so d0 = 10, 9, 9, 9, 9, 9
;
;   chainB   entry point longword-aligned
;            longwords 0..4 hold { i0,i1 } .. { i8,i9 } -> 2 each
;            longword 5 holds { i10, rts }           -> 1 instruction
;            so d0 = 9, 9, 9, 9, 9, 10
;
; Palette entry 9 is blue and entry 10 is yellow, so the picture is
; twelve bars: a yellow one at the *top* of the first group and a yellow
; one at the *bottom* of the second, blue everywhere else. The odd bar
; out marks the partial longword, and it moves from one end of the chain
; to the other purely because the entry point moved by one word. That is
; the whole claim, drawn.
;
; Every other palette entry is a distinct colour too, so a machine that
; gets this wrong does not merely produce a subtly different blue -- if
; the cache were word-granular, for instance, punching one "longword"
; would cost exactly one instruction everywhere and all twelve bars
; would come out yellow.
;
;
; WHY EVERYTHING RUNS IN VERTICAL BLANK
; -------------------------------------
;
; All twelve trials run back to back inside the level 3 handler, once
; per frame, and none of them touch COLOR00. Each writes its answer into
; a data word of the Copper list instead, and the Copper then runs an
; unchanging list for the whole visible frame, moving each stripe's word
; into COLOR00 when it reaches that stripe's line.
;
; This matters more here than anywhere else in this directory. A trial
; is a restore loop, a priming call, a blank loop, two MOVECs and a
; second call, and how long all that takes depends on the very cache
; behaviour under test -- which is to say the handler's runtime is not
; merely long, it is *different for every stripe*. There is no margin
; that makes that safe to race against the beam. Running it in vertical
; blank and letting the Copper read the results afterwards removes the
; question entirely.
;
;
; WHAT IT FOUND ON ITS FIRST RUN
; ------------------------------
;
; The first recorded picture was not the one above: every bar of the
; first group came out one colour short, and tracing the emulator showed
; why. Moira's `execJsr` fetched the word at the jump target with a plain
; bus read
;
;     queue.irc = (u16)read<C, AddrSpace::PROG, Word>(ea);
;     prefetch<C>();
;
; instead of going through the instruction cache, on every core. That is
; right for the 68000, which has no cache to consult, and wrong for the
; 68020: the first instruction word of every JSR target was fetched from
; memory whatever the cache held, so self-modifying code entered through
; a JSR always saw the fresh word. JMP, BSR, Bcc, DBcc, RTS and RTR all
; used `fullPrefetch` already and were correct; JSR was the only one that
; was not, which is why the icache test in this directory never caught it
; -- its whole self-modified instruction, opcode word and immediate word
; alike, is meant to live in one longword, and the immediate still came
; from the cache, so its answers were right by accident.
;
; This test caught it because chainA's entry point is an odd word: the
; target word is the *last* word of its longword, so the bypassed fetch
; is the only access that longword ever gets, and its whole contribution
; to the count disappears. Fixed in Moira by routing JSR through
; `fullPrefetch<C>()`, which also clears the instruction latch -- the
; latch must not answer for a longword the jump has just left.
;
; This has only been checked against vAmiga; nothing here has been
; measured on a real 68020 yet.
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

N                   equ 11              ; addq instructions per chain
ADDQ1               equ $5240           ; addq.w #1,d0
NOPOP               equ $4E71           ; nop

CACR_PRIME          equ $0009           ; C=1, E=1, F=0: flush all, allow fill
CACR_PUNCH          equ $0007           ; E=1, F=1, CE=1: kill CAAR's entry and
                                        ; freeze, so it cannot come back

STRIPEBLK           equ 16              ; bytes of Copper list per stripe
SLOTOFF             equ 6               ; offset of the colour word in a block

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

	; MOVEC is privileged and MAIN does not run in supervisor mode, so
	; every MOVEC in this test lives inside the interrupt handler --
	; see icache in this directory for how that was found.

	lea     copper(pc),a0
	move.l  a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0

	move.w  #$8280,DMACON(a1)       ; Copper DMA only
	move.w  #$C020,INTENA(a1)       ; master, VBlank (3)

.mainLoop:
	bra.b   .mainLoop


; ---------------------------------------------------------------------------
; The trial table
;
; Offsets from chainA, not addresses, so the two chains can be described
; with one base register and so nothing here depends on where the program
; was linked.
; ---------------------------------------------------------------------------

CBOFF   equ     chainB-chainA

stripes:
	dc.w    0,     -2+0*4           ; chainA, longword 0  { filler, i0  }
	dc.w    0,     -2+1*4           ;         longword 1  { i1, i2      }
	dc.w    0,     -2+2*4           ;         longword 2  { i3, i4      }
	dc.w    0,     -2+3*4           ;         longword 3  { i5, i6      }
	dc.w    0,     -2+4*4           ;         longword 4  { i7, i8      }
	dc.w    0,     -2+5*4           ;         longword 5  { i9, i10     }
	dc.w    CBOFF, CBOFF+0*4        ; chainB, longword 0  { i0, i1      }
	dc.w    CBOFF, CBOFF+1*4        ;         longword 1  { i2, i3      }
	dc.w    CBOFF, CBOFF+2*4        ;         longword 2  { i4, i5      }
	dc.w    CBOFF, CBOFF+3*4        ;         longword 3  { i6, i7      }
	dc.w    CBOFF, CBOFF+4*4        ;         longword 4  { i8, i9      }
	dc.w    CBOFF, CBOFF+5*4        ;         longword 5  { i10, rts    }

; Sixteen clearly distinguishable colours, indexed by the instruction
; count the trial comes back with. 9 and 10 are the two answers this
; test expects; every other index is deliberately nothing like them.
palette:
	dc.w    $F00                    ;  0  red
	dc.w    $F60                    ;  1  orange
	dc.w    $C90                    ;  2  amber
	dc.w    $9C0                    ;  3  lime
	dc.w    $0F0                    ;  4  green
	dc.w    $0C6                    ;  5  sea green
	dc.w    $0FF                    ;  6  cyan
	dc.w    $08F                    ;  7  azure
	dc.w    $666                    ;  8  grey
	dc.w    $00F                    ;  9  BLUE   -- a full longword punched
	dc.w    $FF0                    ; 10  YELLOW -- a half longword punched
	dc.w    $F0F                    ; 11  magenta
	dc.w    $FFF                    ; 12  white
	dc.w    $F09                    ; 13  pink
	dc.w    $840                    ; 14  brown
	dc.w    $000                    ; 15  black


; ---------------------------------------------------------------------------
; The chains and the handler, deliberately adjacent
;
; Nothing executed between a trial's priming call and its measured call
; may alias a chain longword, and on a direct-mapped 64-entry longword
; cache that is guaranteed as soon as the whole span is shorter than 256
; bytes. The assertion at the end of this block enforces it, rather than
; leaving it to inspection of a link map that changes every time this
; file does.
; ---------------------------------------------------------------------------

	cnop    0,4
block:
	; The even half of chainA's first longword. It is never executed by
	; this test -- it exists so that chainA's entry point lands on an odd
	; word, and so that chainA's first cache entry has room for only one
	; instruction of the chain.
	dc.w    NOPOP

chainA:
	dcb.w   N,ADDQ1
	rts

	cnop    0,4
chainB:
	dcb.w   N,ADDQ1
	rts


; ---------------------------------------------------------------------------
; Level 3, vertical blank -- every trial for every stripe runs here
;
; a1 = CUSTOM. a2 is the chain entry point, a3 the longword to punch,
; a5 the Copper-list word to answer into, a6 the base every table offset
; is measured from, a0/d0/d1 scratch, d7 the stripe counter.
; ---------------------------------------------------------------------------

irq3:
	movem.l d0-a6,-(sp)

	lea     stripes(pc),a4
	lea     chainA(pc),a6
	lea     slots(pc),a5
	addq.w  #SLOTOFF,a5             ; -> the first stripe's colour word
	moveq   #STRIPES-1,d7

.loop:
	move.w  (a4)+,d1
	lea     0(a6,d1.w),a2           ; this trial's chain entry point
	move.w  (a4)+,d1
	lea     0(a6,d1.w),a3           ; the longword to punch out

	; RESTORE: every word of the chain is an addq again
	move.l  a2,a0
	moveq   #N-1,d1
.restore:
	move.w  #ADDQ1,(a0)+
	dbra    d1,.restore

	; PRIME: flush everything, cache on and unfrozen, then run the chain
	; so that every longword of it is fetched from memory and cached.
	move.w  #CACR_PRIME,d0
	movec   d0,cacr
	jsr     (a2)

	; BLANK: every word of the chain is now a nop in memory. The cache
	; still holds addqs; that is the whole point.
	move.l  a2,a0
	moveq   #N-1,d1
.blank:
	move.w  #NOPOP,(a0)+
	dbra    d1,.blank

	; PUNCH: invalidate exactly one entry and freeze, so the fetches
	; that land in it have to go to memory and cannot refill.
	move.l  a3,d0
	movec   d0,caar
	move.w  #CACR_PUNCH,d0
	movec   d0,cacr

	; RUN: count what still comes back from the cache.
	moveq   #0,d0
	jsr     (a2)

	; The count is the colour. It goes into the Copper list, not into
	; COLOR00: the Copper will read it long after this handler is done.
	lea     palette(pc),a0
	and.w   #$000F,d0
	add.w   d0,d0
	move.w  (a0,d0.w),(a5)

	lea     STRIPEBLK(a5),a5
	dbra    d7,.loop

	move.w  #$0020,INTREQ(a1)
	movem.l (sp)+,d0-a6
	rte

blockend:

	ifgt    (blockend-block)-250
	FAIL    "chains and handler span 256 bytes or more: they can alias"
	endc


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
	; carrying a table of twelve pointers, so the stride has to be what
	; it thinks it is.
	ifne    (slotsend-slots)-(STRIPES*STRIPEBLK)
	FAIL    "STRIPEBLK does not match the Copper list's stripe block"
	endc

	ifgt    CLINE-255
	FAIL    "the band runs past raster line 255"
	endc

	dc.l    $FFFFFFFE
