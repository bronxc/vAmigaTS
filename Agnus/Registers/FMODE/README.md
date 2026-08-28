## Objective

Verifies the behaviour of Agnus' FMODE register on AGA machines, i.e. how BPL32 and BPAGEM (FMODE bits 0 and 1) affect the size of a bitplane fetch and, in the 64-bit case, how the alignment of the bitplane pointers affects the result.

All tests share the same layout: 8 sections in a LORES region followed by 8 sections in a HIRES region, enabling 1 to 8 bitplanes respectively (the 8-plane case uses BPLCON0::BPU3, an AGA-only bit). A copper timing ruler separates the two regions. All 256 AGA color registers are initialized so the number of enabled bitplanes can be read directly off the hue: red, orange, yellow, green, cyan, blue, magenta, white for 1 through 8 planes.

#### fmode00, fmode01, fmode10, fmode11

Exercise the four FMODE values ($0-$3) in turn, i.e. every combination of BPL32 and BPAGEM. The bitplane data is a repeating 8-byte staircase pattern; plane k switches on at byte k-1 of each period and stays on, so scanning across a line brings in one more plane every 8 pixels and the picture is literally a staircase of hues. BPL1MOD/BPL2MOD are both zero and the bitplane pointers are simply left to run from one line into the next, reloaded only when a new section starts; the DDF window of each test is chosen so a line fetches a whole number of staircase periods, which is what keeps the picture standing still.

Because FMODE changes how many words a fetch delivers without changing the fetch unit itself, the four tests need different DDF windows to paint the same picture (three staircases in the LORES region, six in the HIRES region).

fmode10 (BPAGEM set, BPL32 clear) is not a documented fetch mode; the 64-bit mode wants both bits set. It exists to pin down what real hardware does with that combination.

#### fmode11a to fmode11j

All ten variants are fmode11 (FMODE=$3, the 64-bit fetch mode) with a subset of the eight bitplane pointers deliberately pushed off their 64-bit boundary.

fmode11a-e misalign the pointers by 4 bytes:

- fmode11a: all eight planes misaligned. Reproduces the original bug.
- fmode11b: planes 1-4 misaligned, 5-8 aligned.
- fmode11c: planes 5-8 misaligned, 1-4 aligned.
- fmode11d: odd planes (1,3,5,7) misaligned, even planes aligned.
- fmode11e: even planes (2,4,6,8) misaligned, odd planes aligned.

fmode11f-j repeat the same five plane subsets with a 2-byte misalignment.


#### bscan2a to bscan2d

BSCAN2, bit 14 of FMODE, which the rest of this directory does not touch.

Normally BPL1MOD belongs to the odd bitplanes and BPL2MOD to the even ones. BSCAN2 discards that and selects the modulo by the **parity of the raster line** instead, the same modulo then applying to every plane. That is what makes scan doubling possible: give one parity a modulo that rewinds the pointers by exactly one line of data and the other a modulo of zero, and every line is fetched twice and displayed twice.

The parity is not counted from the top of the fetch region. It is anchored at the vertical start of the display window:

```
modulo = (line parity == DIWSTRT vstart parity) ? BPL1MOD : BPL2MOD
```

Each test paints two regions of 64 raster lines from the same bitmap, separated by a white bar. The upper region is always the control -- BSCAN2 off, both modulos zero. The lower region is the one under test. The bitmap is three bitplanes of solid horizontal bands, two source lines per band, cycling through black, red, green, blue, yellow, magenta, cyan and white, so the control repeats every 16 raster lines. The answer is read as the number of colour cycles in the lower region against the number in the upper one, with no ruler needed.

| test | FMODE | BPL1MOD | BPL2MOD | region offset | what it asks |
|---|---|---|---|---|---|
| bscan2a | `$0000` | 0 | 0 | 0 | baseline: does the region switch alone change anything? |
| bscan2b | `$4000` | -40 | 0 | 0 | does scan doubling work? |
| bscan2c | `$4000` | 0 | -40 | 0 | which parity picks which modulo? |
| bscan2d | `$4000` | -40 | 0 | +1 line | is the parity anchored at DIWSTRT or at the region? |

Measured in vAmiga on an A1200, reading band heights down the middle of each region:

| test | control region | region under test |
|---|---|---|
| bscan2a | 32 bands of 2 lines | 32 bands of 2 lines — identical |
| bscan2b | 32 bands of 2 lines | **16 bands of 4 lines** — every source line doubled |
| bscan2c | 32 bands of 2 lines | 3, then 15 bands of 4 — the first source line shown once |
| bscan2d | 32 bands of 2 lines | 3, then 15 bands of 4 |

Three relationships hold exactly, pixel for pixel, and each pins down a different half of the rule:

- **bscan2c and bscan2d are the same picture.** Swapping the two modulos does the same thing as moving the region down one raster line, which is only true if the modulo is chosen by line parity.
- **bscan2b and bscan2d differ.** Moving the region down one line changes the result, so the parity cannot be counted from the top of the region. It is anchored elsewhere -- at DIWSTRT.
- **On an A500+ the region offset changes nothing**, and bscan2b and bscan2d are identical there.

That last point is why every test also has a `_plus` script, and it is not the null result it sounds like. FMODE does not exist before AGA, so the modulos go back to meaning what they always meant, and the same pair of values rewinds planes 1 and 3 every line while plane 2 runs on: region B breaks into 4 line bands of a single colour. Same registers, same bitmap, completely different picture -- which is the clearest statement of what BSCAN2 changes. Not the modulos, but which modulo is picked.

Nothing in these four depends on CPU timing. The CPU builds the bitmap once and then idles; every register the picture depends on is written by the Copper.


Dirk Hoffmann, 2026
