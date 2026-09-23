## Objective

Verifies HAM8, the AGA 8 bitplane Hold-And-Modify mode, against HAM6 in the same frame. The upper half of the screen is drawn in HAM6, the lower half in HAM8, with the copper timing ruler from the Agnus/DDF/ddf1 test between them. Both halves are LORES here — see `ham8hires` for the same comparison with the HIRES bit set on both halves, which turns out to be a real, working combination on AGA (just not on OCS/ECS Denise).

#### What separates the two modes

Both modes split the color index into two control bits and a data field, and the control codes mean the same thing in both:

```
00   set the color from a palette register
01   hold red and green, modify BLUE
10   hold green and blue, modify RED
11   hold red and blue,   modify GREEN
```

What differs is where the control bits sit and how wide the data field is:

```
             control bits     data field      modify writes
HAM6         index 5-4        index 3-0       value << 4   (4 bits, 16 steps)
             planes 5, 6      planes 1-4
HAM8         index 1-0        index 7-2       value << 2   (6 bits, 64 steps)
             planes 1, 2      planes 3-8
```

HAM8 puts its control bits in the **low** two planes, not the high two. It is not HAM6 with two more data planes bolted on top, and a plane assignment that is right for one mode is wrong for the other. In the set case HAM6 reads COLOR00-15 while HAM8 reads COLOR00-63, the index shifted right by two.

#### ham8

Each half is four horizontal bands of 19 display lines (20, less the blank line each band uses to reload its bitplane pointers -- see below). A band holds one control code constant across the whole line and lets the data field count up with the pixel position, so each band is a sawtooth of whatever its control code does:

```
band 1   code 00   the palette, cycled
band 2   code 10   a black to red   ramp
band 3   code 11   a black to green ramp
band 4   code 01   a black to blue  ramp
```

The data field is fed the pixel position in both halves, so its width alone decides the period of the sawtooth: 16 lores pixels in HAM6, 64 in HAM8. With 256 pixels of display that is 16 teeth per band in the upper half against 4 in the lower one. A quarter of the tooth count is not a subtle difference, and it is a direct read-out of the data field width, which is the thing that actually separates the two modes.

The palette band reads the same way. COLOR00-63 hold a 64 step black to white ramp, so the HAM8 band sweeps black to white every 64 pixels while the HAM6 band, which can only reach COLOR00-15, sweeps black to a quarter grey every 16. **The HAM6 palette band being conspicuously dark is the expected result, not a palette bug**: a HAM6 picture cannot address the upper 48 registers. The three modify bands peak at full brightness in both halves (240 in HAM6, 252 in HAM8, the two field widths shifted into an 8 bit channel).

The ramps start from black because the modify codes hold two channels from the previous pixel, and at the left edge of the display window that is COLOR00, which is forced to true black. If a band comes out tinted rather than a pure single-channel ramp, the HAM hold is not being reset to COLOR00 at the start of the line. That is worth knowing either way, and is the reason the two held channels are set up to be exactly zero.

#### The pointer reload gets its own blank line

Each band switches the bitplanes off, reloads all eight pointers on that blank line, and switches the mode back on for its first display line. Reloading on the first *display* line instead — which is what this test used to do — is only safe while bitplane DMA is off. With eight planes fetching, bitplane DMA takes most of the slots, the copper is starved, and the last MOVEs of the block (BPL6PT, BPL7PT, BPL8PT) land late, leaving those planes a different distance into their buffers than planes 1-5.

`bitBuf5` — plane 8, the HAM8 data field's MSB — repeats every 8 bytes, so a lag of 4 bytes mod 8 flips that bit and shifts the whole 64-entry ramp by half its period. The palette band is the only one whose reload follows the ruler, where the bitplanes were already off, so it alone got a clean reload and ended up 32 pixels out of step with the three modify bands.

That artefact is copper/bitplane-DMA contention, not HAM, so it does not belong here. It is real and worth pinning down, though, so the original timing is preserved verbatim in **`ham8_a`** (lores) and **`ham8hires_a`** (hires) — the latter being a known vAmiga/hardware divergence — and **`ham8_b`** / **`ham8hires_b`** repeat the pair with the reload delayed to hpos `$10`, which lands on a different lag and inverts the answer in both resolutions. The blank-line discipline used here is the one `Agnus/Registers/FMODE/fmode.i` already documents for the same reason. The cost is one blank raster line per band, so the bands are 19 display lines rather than 20.

#### Notes on the source

Only eight bitplane buffers exist, each filled with a repeating 4 word pattern: six carrying bit 0 to bit 5 of the pixel position, plus one solid and one empty. A band is then nothing but a choice of pointers, the data planes getting bit 0 upwards and the two control planes getting the solid or the empty buffer according to the band's control code. That is why both halves can share every buffer even though they take their control bits from opposite ends of the plane stack.

FMODE is $0 (16 bit fetch), so a line fetches `(DDFSTOP - DDFSTRT) / 8 + 1` words per plane, which for the $38 to $B0 window used here is 16 words = 256 lores pixels. 16 is a multiple of the 4 word pattern period, so a line always ends on a period boundary and the next line starts in phase with BPLxMOD left at zero; the pointers are reloaded only when a band starts. Choosing the window to satisfy that condition is only safe because the window is fixed here — see agascroll.i for the case where it is not and the pointers have to be reloaded per line instead.


#### Hardware reference

The existing A1200 (and A500/A500+) photographs were taken with the original pointer-reload timing and now live with `ham8_a`, which still carries that code. This test needs a fresh photograph to confirm hardware agreement; with a clean reload all bands are expected to share one phase.

Dirk Hoffmann, 2026
