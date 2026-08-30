## Objective

Verify basic timing properties.

`coprace/coprace3` visualizes the CPU-modifies-the-Copper-list-from-the-
VBlank-interrupt race (31 color registers, Copper writes yellow, CPU's
VBlank handler writes blue, last write wins) but found that on vAmiga the
CPU wins every single register -- the crossover point the test is built
to expose lies beyond what 31 registers can show.

This family turns the same race into a sweep that brings the crossover
into view. Each member adds a Copper WAIT statement in front of the
race's first write, holding the Copper back by a different number of
color clocks before it starts. The CPU's VBlank handler is untouched --
it always begins as soon as its interrupt is serviced -- so the WAIT
gives the CPU an artificial head start on the low-numbered registers.
Because the Copper is still faster per register once it does start,
that head start shrinks with every register it writes, and past some
point the CPU falls back behind. The picture is yellow (Copper wins)
from register 1 up to a boundary, then blue (CPU wins) from there to
register 31; the boundary moves right as the WAIT target increases
across the family, from all-blue at one end to all-yellow at the other:

| Test      | WAIT target (HP) | Registers won by Copper (yellow) |
|-----------|:-----------------:|:---------------------------------:|
| vblrace0  | $01               | 0  (all blue)                     |
| vblrace1  | $31               | 1                                  |
| vblrace2  | $41               | 5                                  |
| vblrace3  | $51               | 9                                  |
| vblrace4  | $61               | 13                                 |
| vblrace5  | $71               | 17                                 |
| vblrace6  | $81               | 21                                 |
| vblrace7  | $91               | 23                                 |
| vblrace8  | $A1               | 27                                 |
| vblrace9  | $B1               | 31  (all yellow)                  |

All ten share `vblrace.i` for the setup, interrupt handler, Copper list
and bitplane data; each leaf `.s` file only sets `WAIT_POS` before
including it -- see `vblrace.i`'s own header for why the WAIT target's
low byte has to be odd (that bit is the hardware's WAIT-vs-MOVE flag,
not part of the position), and for why the background/separator colour
(COLOR00) is black rather than white: it is also the real Amiga
background/border register, so a non-black value here leaks into the
border for the whole frame.

Dirk Hoffmann, 2026
