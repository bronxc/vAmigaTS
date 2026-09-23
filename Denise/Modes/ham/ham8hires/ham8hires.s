	include "../../../../include/registers.i"
	include "hardware/dmabits.i"
	include "hardware/intbits.i"
	include "ministartup.s"

; ham8hires.s -- HAM6 versus HAM8, both with the HIRES bit set.
;
; This is ham8.s with BPLCON0's HIRES bit (bit 15) ORed into both mode
; words, plus the FMODE change that is needed to make that combination
; actually paint something -- see "WHY FMODE" below. On AGA, HAM6 and HAM8
; are both defined with HIRES set: hamMode6()/hamMode8() (see vAmiga's
; Denise.h) gate on "lores(v) || isAGA()", i.e. HIRES only disables HAM on
; OCS/ECS Denise, not on AGA. So the upper half (HAM6) and the lower half
; (HAM8) are both real, working modes here -- unlike the HIRES-clear-only
; restriction that applies to plain OCS/ECS HAM6.
;
; What isn't real is running this on an ECS Agnus/OCS Denise machine or an
; A500+: there, "lores(v) || isAGA()" is false once HIRES is set, so HAM
; never engages and every band reads as a flat "set from palette" index
; instead of a colour ramp. The _ecs/_plus captures below are exactly that
; -- not a bug, the documented cross-chipset difference this test exists to
; show. Only _aga shows real red/green/blue ramps.
;
; Same bands, same bandTable, same pointer buffers, same copper timing
; ruler between the halves as ham8.s -- see ham8.s for the shared mechanism
; this file does not repeat.
;
;
; WHAT DIFFERS FROM ham8.s
; -------------------------
;
;     BPLCON0_HAM6   $6A00 -> $EA00   (HIRES bit added)
;     BPLCON0_HAM8   $0A10 -> $8A10   (HIRES bit added)
;     FMODE          $0000 -> $0001   (32-bit fetch -- see below)
;     DDFSTRT/DDFSTOP $0038/$00B0 -> $0030/$0088
;     DIWSTOP        $2C81 -> $2CC1
;     PLANE_SIZE      1024 ->  2048
;     every band reloads its pointers on a blank line -- see below
;
;
; WHY THE POINTER RELOAD NEEDS ITS OWN BLANK LINE
; -----------------------------------------------
;
; ham8.s reloads all eight bitplane pointers on the band's FIRST DISPLAY
; line, on the assumption that "sixteen MOVEs take 32 color clocks, so they
; are all done by hpos $23, well ahead of DDFSTRT". That assumption only
; holds while bitplane DMA is off. With eight planes fetching, bitplane DMA
; takes most of the slots and the copper is starved, so the last MOVEs in
; the block -- BPL6PT, BPL7PT, BPL8PT -- land late and those planes end up
; a different distance into their buffers than planes 1-5.
;
; That is invisible for most of the data here, because bitBuf0-bitBuf3
; repeat every 2 bytes and bitBuf4 every 4, so any lag that is a multiple
; of those is undetectable. bitBuf5 -- plane 8, the data field's MSB -- is
; the exception: it repeats every 8 bytes, so a lag of 4 bytes mod 8 flips
; the MSB and shifts the whole 64-entry ramp by half its period.
;
; The band that escapes it is the FIRST one of each half, whose reload
; happens to follow the copper ruler (or the top of the list), where the
; bitplanes were already switched off. So in ham8.s the "set" band is
; reloaded cleanly and the three modify bands are not, and the set band's
; palette ramp comes out shifted 32 pixels against them -- an artefact of
; copper/DMA contention, not of HAM.
;
; Measured on a real A1200 in both resolutions and reproduced by vAmiga in
; lores, so it is genuine hardware behaviour -- but it is not what this
; test is trying to measure. Every band here therefore switches the
; bitplanes off, reloads its pointers on that blank line, and switches the
; mode back on for the band's first display line -- the same discipline
; Agnus/Registers/FMODE/fmode.i already uses and documents for the same
; reason. With a clean reload all eight bands share one phase, and any
; difference left between them is HAM's doing.
;
; The cost is one blank raster line per band, so the bands are 19 display
; lines rather than 20; the WAIT positions are otherwise unchanged.
;
; WHY FMODE
; ---------
;
; vAmiga's Sequencer::computeFetchUnit caps a hires line's bitplane fetch
; at 4 planes when FMODE is 0 -- there simply aren't enough DMA slots for
; more. HAM6 needs 6 and HAM8 needs 8, so at FMODE 0 both halves would
; fetch nothing at all (confirmed: an earlier version of this test that
; kept FMODE at 0 came back solid black). A non-zero FMODE widens the
; fetch and lifts that cap to 8, the same fact the Agnus/Registers/FMODE
; suite already demonstrates for its own HIRES region (fmode01 genuinely
; paints all 8 planes in hires at FMODE $0001). FMODE $0001 (32-bit fetch)
; is the smallest value that does it, so that is what this test uses.
;
; DDFSTRT/DDFSTOP move to $0030/$0088 to match: they are the exact window
; Agnus/Registers/FMODE/fmode01 already uses at this FMODE for hires, and
; reusing a window already proven to fetch a clean, non-shearing word count
; is simpler than re-deriving one. DIWSTOP widens to $2CC1 to match --
; also not a fresh derivation, but the constant Denise/Modes/shres already
; uses for HIRES with a DDFSTRT/DDFSTOP window of this shape. PLANE_SIZE
; doubles because a hires line now fetches twice the words a lores line
; does at the same FMODE, so each band's data is twice as long.
;
; DIWSTART, the band line ranges, the copper timing ruler and every band's
; pointer assignment are otherwise byte-for-byte what ham8.s uses --
; vertical position is unaffected by a horizontal-only bit, so none of it
; needed to move.

BPLCON3             equ $106          ; AGA only
BPLCON4             equ $10C          ; AGA only
BPL7PTH             equ $F8           ; AGA only
BPL7PTL             equ $FA           ; AGA only
BPL8PTH             equ $FC           ; AGA only
BPL8PTL             equ $FE           ; AGA only
FMODEREG            equ $1FC          ; AGA only

FMODE               equ $0001         ; 32-bit fetch -- lifts the hires plane cap

DDF_START           equ $0030
DDF_STOP            equ $0088

; Same DIWSTART formula as ham8.s; DIWSTOP widened for hires -- see header.
DIW_START           equ $2C00+(DDF_START*2)+9
DIW_STOP            equ $2CC1

BPLCON0_HAM6        equ $EA00         ; BPU=6, HAM, HIRES
BPLCON0_HAM8        equ $8A10         ; BPU=8 (BPU3), HAM, HIRES
BPLCON0_OFF         equ $0200

BAND_LINES          equ 20
PLANE_SIZE          equ 2048          ; plenty for a 20-line band at this window


MAIN:
	; Load base address into a1
	lea     CUSTOM,a1

	; Disable interrupts, DMA and bitplanes
	move.w  #$7FFF,INTENA(a1)
	move.w  #$7FFF,DMACON(a1)
	move.w  #$200,BPLCON0(a1)

	; Disable CIA interrupts
	move.b  #$7F,$BFDD00  ; CIA B
	move.b  #$7F,$BFED01  ; CIA A

	move.w  #FMODE,FMODEREG(a1)

	; Fill the eight buffers with their 4 word patterns.
	lea     bitBuf0,a0
	lea     .pat0(pc),a3
	bsr     .fillPattern
	lea     bitBuf1,a0
	lea     .pat1(pc),a3
	bsr     .fillPattern
	lea     bitBuf2,a0
	lea     .pat2(pc),a3
	bsr     .fillPattern
	lea     bitBuf3,a0
	lea     .pat3(pc),a3
	bsr     .fillPattern
	lea     bitBuf4,a0
	lea     .pat4(pc),a3
	bsr     .fillPattern
	lea     bitBuf5,a0
	lea     .pat5(pc),a3
	bsr     .fillPattern
	lea     onesBuf,a0
	lea     .patOnes(pc),a3
	bsr     .fillPattern
	lea     zerosBuf,a0
	lea     .patZeros(pc),a3
	bsr     .fillPattern

	; Palette: COLOR00-63 hold a 64 step black to white ramp, register n
	; carrying the 8 bit level n*4. A write with LOCT clear stores the
	; given nibble in BOTH halves of each component, and a following write
	; with LOCT set replaces the lower halves, so the pair of passes below
	; lands exactly (n>>2)*16 + (n&3)*4 = n*4 per channel.
	;
	; Registers 0-31 are bank 0 and 32-63 are bank 1. Bank 1 is written
	; first so that bank 0 is written last: on a chipset where BPLCON3's
	; BANK field does nothing, both passes hit the same 32 registers and
	; whichever went last is what sticks -- and that has to be bank 0.
	lea     CUSTOM,a1
	moveq   #1,d7                   ; d7 = bank (1 downto 0)
.bankLoop:
	move.w  d7,d0
	lsl.w   #8,d0
	lsl.w   #5,d0                   ; BANK -> BPLCON3 bits 15-13

	move.w  d0,BPLCON3(a1)          ; LOCT = 0: high nibbles
	lea     COLOR00(a1),a2
	moveq   #0,d6
.hiLoop:
	move.w  d7,d5
	lsl.w   #5,d5
	or.w    d6,d5                   ; d5 = n = bank*32 + reg
	move.w  d5,d2
	lsr.w   #2,d2                   ; n >> 2, the high nibble of n*4
	move.w  d2,d1
	lsl.w   #4,d1
	or.w    d1,d2
	lsl.w   #4,d1
	or.w    d1,d2                   ; replicate into R, G and B
	move.w  d2,(a2)+
	addq.w  #1,d6
	cmp.w   #32,d6
	bne.s   .hiLoop

	or.w    #$0200,d0               ; LOCT = 1: low nibbles
	move.w  d0,BPLCON3(a1)
	lea     COLOR00(a1),a2
	moveq   #0,d6
.loLoop:
	move.w  d7,d5
	lsl.w   #5,d5
	or.w    d6,d5
	and.w   #3,d5
	lsl.w   #2,d5                   ; (n & 3) * 4, the low nibble of n*4
	move.w  d5,d2
	move.w  d2,d1
	lsl.w   #4,d1
	or.w    d1,d2
	lsl.w   #4,d1
	or.w    d1,d2
	move.w  d2,(a2)+
	addq.w  #1,d6
	cmp.w   #32,d6
	bne.s   .loLoop

	dbra    d7,.bankLoop

	; COLOR00 is the base every modify band ramps away from, so force it to
	; true black. It is index 0, which the ramp above already makes black,
	; but writing it explicitly keeps the intent obvious and leaves BPLCON3
	; in a known state.
	move.w  #$0000,BPLCON3(a1)      ; bank 0, LOCT = 0
	move.w  #$0000,COLOR00(a1)
	move.w  #$0200,BPLCON3(a1)      ; bank 0, LOCT = 1
	move.w  #$0000,COLOR00(a1)
	move.w  #$0000,BPLCON3(a1)

	; Patch the buffer addresses into every band's pointer block. Each
	; entry of bandTable is one band: the address of its copper block
	; followed by the eight buffers its planes point at, in plane order.
	lea     bandTable(pc),a4
.bandLoop:
	move.l  (a4)+,d0
	beq.s   .bandDone
	move.l  d0,a2                   ; a2 = the band's BPL1PTH move
	moveq   #7,d6
.planeLoop:
	move.l  (a4)+,d3
	move.w  d3,6(a2)                ; low  word -> BPLxPTL move
	swap    d3
	move.w  d3,2(a2)                ; high word -> BPLxPTH move
	addq.l  #8,a2
	dbra    d6,.planeLoop
	bra.s   .bandLoop
.bandDone:

	; Install Copper list and enable DMA
	lea 	CUSTOM,a1
	lea	    copper(pc),a0
	move.l	a0,COP1LC(a1)
	move.w  COPJMP1(a1),d0

	move.w	#$8080,DMACON(a1)   ; Copper DMA
	move.w	#$8100,DMACON(a1)   ; Bitplane DMA
	move.w	#$8200,DMACON(a1)   ; DMAEN

.mainLoop:
	bra.b	.mainLoop


.fillPattern:
	; Replicates the 4-word (8-byte) pattern at a3 across the buffer at a0.
	; in: a0 = dest, a3 = pattern
	; clobbers: a0, a4, d0
	move.w  #(PLANE_SIZE/8)-1,d0
.fpLoop:
	move.l  a3,a4
	move.w  (a4)+,(a0)+
	move.w  (a4)+,(a0)+
	move.w  (a4)+,(a0)+
	move.w  (a4)+,(a0)+
	dbra    d0,.fpLoop
	rts

	; Bit b of the pixel position, as a 4 word period. Pixel 0 is the most
	; significant bit of the first word.
.pat0:     dc.w    $5555,$5555,$5555,$5555   ; period  2 pixels
.pat1:     dc.w    $3333,$3333,$3333,$3333   ; period  4
.pat2:     dc.w    $0F0F,$0F0F,$0F0F,$0F0F   ; period  8
.pat3:     dc.w    $00FF,$00FF,$00FF,$00FF   ; period 16
.pat4:     dc.w    $0000,$FFFF,$0000,$FFFF   ; period 32
.pat5:     dc.w    $0000,$0000,$FFFF,$FFFF   ; period 64
.patOnes:  dc.w    $FFFF,$FFFF,$FFFF,$FFFF
.patZeros: dc.w    $0000,$0000,$0000,$0000


; One entry per band: the copper block to patch, then the buffer each of the
; eight planes points at.
;
; HAM6 takes its control bits from planes 5 and 6 (index bits 4 and 5) and
; its data from planes 1-4. Planes 7 and 8 are not fetched at BPU = 6 but
; are pointed at zerosBuf anyway so no pointer is ever left dangling.
;
; HAM8 takes its control bits from planes 1 and 2 (index bits 0 and 1) and
; its data from planes 3-8. The low control bit is plane 1 in HAM8 and
; plane 5 in HAM6, so "code 10" means plane 6 in the upper half and plane 2
; in the lower one.
bandTable:
	; HAM6, code 00 -- palette
	dc.l    h6set
	dc.l    bitBuf0,bitBuf1,bitBuf2,bitBuf3
	dc.l    zerosBuf,zerosBuf,zerosBuf,zerosBuf
	; HAM6, code 10 -- modify red
	dc.l    h6red
	dc.l    bitBuf0,bitBuf1,bitBuf2,bitBuf3
	dc.l    zerosBuf,onesBuf,zerosBuf,zerosBuf
	; HAM6, code 11 -- modify green
	dc.l    h6green
	dc.l    bitBuf0,bitBuf1,bitBuf2,bitBuf3
	dc.l    onesBuf,onesBuf,zerosBuf,zerosBuf
	; HAM6, code 01 -- modify blue
	dc.l    h6blue
	dc.l    bitBuf0,bitBuf1,bitBuf2,bitBuf3
	dc.l    onesBuf,zerosBuf,zerosBuf,zerosBuf

	; HAM8, code 00 -- palette
	dc.l    h8set
	dc.l    zerosBuf,zerosBuf
	dc.l    bitBuf0,bitBuf1,bitBuf2,bitBuf3,bitBuf4,bitBuf5
	; HAM8, code 10 -- modify red
	dc.l    h8red
	dc.l    zerosBuf,onesBuf
	dc.l    bitBuf0,bitBuf1,bitBuf2,bitBuf3,bitBuf4,bitBuf5
	; HAM8, code 11 -- modify green
	dc.l    h8green
	dc.l    onesBuf,onesBuf
	dc.l    bitBuf0,bitBuf1,bitBuf2,bitBuf3,bitBuf4,bitBuf5
	; HAM8, code 01 -- modify blue
	dc.l    h8blue
	dc.l    onesBuf,zerosBuf
	dc.l    bitBuf0,bitBuf1,bitBuf2,bitBuf3,bitBuf4,bitBuf5

	dc.l    0


; PTRBLOCK -- the eight pointer MOVE pairs of one band, emitted as zero and
; filled in at startup from bandTable. Sixteen MOVEs take 32 color clocks;
; started at hpos $01 they are all done by hpos $23, well ahead of DDFSTRT.
PTRBLOCK	MACRO
	dc.w    BPL1PTH,$0000
	dc.w    BPL1PTL,$0000
	dc.w    BPL2PTH,$0000
	dc.w    BPL2PTL,$0000
	dc.w    BPL3PTH,$0000
	dc.w    BPL3PTL,$0000
	dc.w    BPL4PTH,$0000
	dc.w    BPL4PTL,$0000
	dc.w    BPL5PTH,$0000
	dc.w    BPL5PTL,$0000
	dc.w    BPL6PTH,$0000
	dc.w    BPL6PTL,$0000
	dc.w    BPL7PTH,$0000
	dc.w    BPL7PTL,$0000
	dc.w    BPL8PTH,$0000
	dc.w    BPL8PTL,$0000
	ENDM


copper:
	dc.w    FMODEREG,FMODE
	dc.w    BPLCON0,BPLCON0_OFF
	dc.w    BPLCON1,$0000
	dc.w    BPLCON2,$0024
	dc.w    BPLCON3,$0000
	dc.w    BPLCON4,$0011           ; AGA defaults (no bitplane colour XOR)
	dc.w    DIWSTRT,DIW_START
	dc.w    DIWSTOP,DIW_STOP
	dc.w    DDFSTRT,DDF_START
	dc.w    DDFSTOP,DDF_STOP
	dc.w    BPL1MOD,$0000
	dc.w    BPL2MOD,$0000

	;
	; HAM6 band 1 (lines $30-$43): code 00, the palette
	;
	dc.w    $2F01,$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
h6set:
	PTRBLOCK
	dc.w    $3001,$FFFE
	dc.w    BPLCON0,BPLCON0_HAM6

	;
	; HAM6 band 2 (lines $44-$57): code 10, modify red
	;
	dc.w    $4301,$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
h6red:
	PTRBLOCK
	dc.w    $4401,$FFFE
	dc.w    BPLCON0,BPLCON0_HAM6

	;
	; HAM6 band 3 (lines $58-$6B): code 11, modify green
	;
	dc.w    $5701,$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
h6green:
	PTRBLOCK
	dc.w    $5801,$FFFE
	dc.w    BPLCON0,BPLCON0_HAM6

	;
	; HAM6 band 4 (lines $6C-$7F): code 01, modify blue
	;
	dc.w    $6B01,$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
h6blue:
	PTRBLOCK
	dc.w    $6C01,$FFFE
	dc.w    BPLCON0,BPLCON0_HAM6

	;
	; Copper timing ruler (from ddf1), between the two halves. Each MOVE
	; takes 4 color clocks, i.e. 8 lores pixels, so the stripes measure
	; copper timing straight across the display. Bitplane DMA is switched
	; off first: left running it would steal slots from the copper and the
	; stripe train would no longer be evenly spaced.
	;
	dc.w    $8001,$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
	dc.w    COLOR00,$000
	dc.w    $8800+DDF_START+1,$FFFE ; ruler starts where the data does
	dc.w    COLOR00,$F00
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$FFF
	dc.w    COLOR00,$000
	dc.w    COLOR00,$0F0
	dc.w    COLOR00,$000

	;
	; HAM8 band 1 (lines $90-$A3): code 00, the palette
	;
	dc.w    $8F01,$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
h8set:
	PTRBLOCK
	dc.w    $9001,$FFFE
	dc.w    BPLCON0,BPLCON0_HAM8

	;
	; HAM8 band 2 (lines $A4-$B7): code 10, modify red
	;
	dc.w    $A301,$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
h8red:
	PTRBLOCK
	dc.w    $A401,$FFFE
	dc.w    BPLCON0,BPLCON0_HAM8

	;
	; HAM8 band 3 (lines $B8-$CB): code 11, modify green
	;
	dc.w    $B701,$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
h8green:
	PTRBLOCK
	dc.w    $B801,$FFFE
	dc.w    BPLCON0,BPLCON0_HAM8

	;
	; HAM8 band 4 (lines $CC-$DF): code 01, modify blue
	;
	dc.w    $CB01,$FFFE
	dc.w    BPLCON0,BPLCON0_OFF
h8blue:
	PTRBLOCK
	dc.w    $CC01,$FFFE
	dc.w    BPLCON0,BPLCON0_HAM8

	;
	; Done -- shut the display down again.
	;
	dc.w    $E001,$FFFE
	dc.w    BPLCON0,BPLCON0_OFF

	dc.l    $fffffffe

	cnop    0,8
bitBuf0:  ds.b PLANE_SIZE
	cnop    0,8
bitBuf1:  ds.b PLANE_SIZE
	cnop    0,8
bitBuf2:  ds.b PLANE_SIZE
	cnop    0,8
bitBuf3:  ds.b PLANE_SIZE
	cnop    0,8
bitBuf4:  ds.b PLANE_SIZE
	cnop    0,8
bitBuf5:  ds.b PLANE_SIZE
	cnop    0,8
onesBuf:  ds.b PLANE_SIZE
	cnop    0,8
zerosBuf: ds.b PLANE_SIZE
