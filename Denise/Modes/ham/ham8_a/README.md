## Objective

`ham8` with its original pointer-reload timing, kept as a test in its own right. The assembly is byte-for-byte what `ham8` was before its pointer reload was moved onto a blank line — only the comments differ. Where `ham8` now measures HAM alone, this variant deliberately measures what the original timing exposed: **copper starvation by bitplane DMA**.

See `ham8/README.md` for the HAM6-versus-HAM8 mechanism itself, which this file shares unchanged.

#### What the original timing does

All eight bitplane pointers are reloaded by sixteen copper MOVEs on the band's **first display line**. Sixteen MOVEs take 32 color clocks, so starting at hpos $01 they finish by hpos $23, comfortably ahead of DDFSTRT — but only while bitplane DMA is off. With eight planes fetching, bitplane DMA takes most of the slots, the copper is starved, and the last MOVEs of the block (BPL6PT, BPL7PT, BPL8PT) land late. Those planes end up a different distance into their buffers than planes 1-5.

Most of the data hides this, because the lag only matters modulo each buffer's pattern period:

| buffer | plane | pattern period | lag visible? |
|---|---|---|---|
| bitBuf0-bitBuf3 | 3-6 | 2 bytes | no |
| bitBuf4 | 7 | 4 bytes | no |
| **bitBuf5** | **8** | **8 bytes** | **yes** |

`bitBuf5` is plane 8, the HAM8 data field's MSB. A lag of 4 bytes mod 8 flips that bit, which offsets the 6-bit data field by 32 and shifts the whole 64-entry palette ramp by exactly half its period.

The one band that escapes is the first of each half, whose reload follows the copper ruler (or the top of the copper list), where the bitplanes had already been switched off. So the palette band is reloaded cleanly, the three modify bands are not, and the palette band's ramp comes out 32 pixels out of step with them.

HAM6 never shows it: all four of its data planes are `bitBuf0`-`bitBuf3`, whose 2-byte period makes any lag invisible.

#### Measured

On a real A1200 (`ham8_a_A1200.jpeg`), reading the HAM8 section:

```
palette band resets at   220, 395, 568
modify bands reset at    307, 481
offset -87, period 174   ->  exactly half a period
```

vAmiga reproduces this, so the test passes and pins the behaviour down. That makes it a useful guard: it is one of the few tests here that depends on copper/bitplane-DMA cycle contention rather than on Denise's colour path.

Its hires counterpart, `ham8hires_a`, is the interesting one — there vAmiga and hardware disagree.

The lag is not fixed, though: `ham8_b` and `ham8hires_b` start the same reload later in the line, which moves the palette band to a different quarter of the ramp. Between them the four tests bracket the behaviour, and `ham8_b` is the lores case where vAmiga reports no shift at all.

Dirk Hoffmann, 2026
