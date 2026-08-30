 ## Objective

Verify basic timing properties.

#### coprace1

A simple test that lets the CPU and the Copper modify the background color simultaniously.

#### coprace2

Similar to coprace1 with the CPU triggering some interrupts.

#### coprace3

The CPU-modifies-the-Copper-list-from-the-VBlank-interrupt race, made
visible instead of timed. The Copper's list sets COLOR01-COLOR31 to
yellow, one MOVE per register, as the very first thing it does every
frame; the CPU's VBlank handler sets the same 31 registers to blue, also
in order. Whichever write lands last wins that register, and the result
is 31 numbered stripes -- separated by black one-pixel lines drawn via
COLOR00, so they can be counted -- whose blue/yellow boundary marks
exactly how many registers the CPU's interrupt response cost it, in
units of one Copper MOVE. All 31 registers are reset to black at the
bottom of the display, past the visible stripes, so every frame's race
starts from the same clean state. See coprace3.s's own header for the
full mechanism, including the (deterministic, on vAmiga as of this
writing) result: the CPU wins every single register, meaning the actual
crossover point lies beyond what 31 color registers can show -- see
`../vblrace` for a version of this same race with a customizable Copper
start delay, which does bring the crossover into view.

Dirk Hoffmann, 2026
