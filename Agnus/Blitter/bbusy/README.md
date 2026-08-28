## Objective

Test BBUSY bit timing.

#### bbusyX

These tests run the copy Blitter with the channel enable bits ABCD set to X. The Copper is utilized to trigger interrupts. Inside the interrupt handler, the CPU launches the Blitter, waits until the BBUSY bit is cleared and changes the background color back to black. 

#### bbusyXf

Same as bbusyX with the Blitter running in fill mode.

#### bbusyXl

Similar to bbusyX with the Blitter running in line mode.


#### copbbusyX

The same tests with the Blitter started by the Copper instead of the CPU.

The CPU-driven tests above measure the Blitter's behaviour *and* the CPU's:
interrupt latency, instruction timing, and every bus cycle the spin loop on
DMACONR steals from the Blitter while it waits. Comparing two emulators on
those pictures compares their CPUs as much as their Blitters, which is a
problem when the question is about the Blitter -- for instance whether AGA
releases BBUSY later than OCS.

Here the Copper does all of it:

```
dc.w    COLOR00,COLn        ; bar starts
dc.w    BLTSIZE,BLTSIZEn    ; start the blit  (needs CDANG)
dc.w    $0001,$7FFE         ; wait for BBUSY  (BFD clear)
dc.w    COLOR00,$FFF
dc.w    COLOR00,$000        ; bar ends
```

The second WAIT compares against VP=0, HP=0, which every position already
satisfies, so the Blitter going idle is the only thing it waits for. That
couples the Copper straight to BBUSY with no software in between, and the
bar is Blitter time plus a constant Copper overhead that cancels when two
machines are compared.

The first WAIT -- the one that starts the bar -- is placed inside the
visible screen rather than at the left edge, so black is visible before the
bar begins. That turns the *start* of the bar into a measurement too: the
moment the colour first appears marks how long it took the Copper's
BLTSIZE write to actually launch the blit, exactly as the white flash at
the end marks the moment BBUSY cleared. A row reads black, then colour for
the blit's duration, then one white line, then black again.

That WAIT position (`HPOS` in `copbbusy.i`) has to be an odd value. Bit 0
of a Copper WAIT's first word is not part of the horizontal compare -- it
is fixed at 1 to mark the instruction as a WAIT rather than a MOVE (whose
first word is always an even register address). Every other HP constant in
this suite already follows this by convention; an even value here does not
fail to assemble, it assembles into something that is no longer a WAIT at
the intended position. Measured directly: $20, $30, $40, $50 and $80 all
left rows colliding into each other rather than landing on their own
raster lines, which is a more confusing failure than a build error would
have been.

The CPU is used once per frame, in the vertical blank handler, to set the
Blitter up exactly as `prepareblit` does above. It then executes `STOP` and
sleeps until the next vertical blank.

`STOP` rather than a loop: a stopped 68000 issues no bus cycles at all, so
it cannot steal a slot from the Blitter or shift its timing by a cycle. A
tight loop would still fetch, and a 68000 has no instruction cache to fetch
from. The stack pointer is reset at the top of the handler, since the CPU is
woken and stopped again without ever returning.

There is no `synccpu` and no magenta sync bar: nothing in the measurement
depends on where the CPU is, so there is nothing to sync.

Two consequences worth knowing when reading the pictures. The bars are much
shorter than in the CPU-driven tests, because all the interrupt and spin
overhead is gone -- what is left is close to the blit itself. And they begin
at the left edge rather than partway in: the Copper reaches HPOS with no
latency, so a bar starts before the visible region. The end position is what
carries the measurement.

Several of these tests produce identical pictures. That is expected: BBUSY
timing follows the number of active DMA channels, not which ones, so the
tests that differ only in channel selection agree once the CPU's
contribution is removed.


Dirk Hoffmann, 2021 - 2026