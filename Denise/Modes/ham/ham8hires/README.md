## Objective

Takes `ham8`'s HAM6-versus-HAM8 comparison and sets BPLCON0's HIRES bit (bit 15) on both halves. On AGA that is a real, working combination: vAmiga's `hamMode6()`/`hamMode8()` (see `Denise.h`) gate HAM on `lores(v) || isAGA()`, so HIRES only disables HAM on OCS/ECS Denise -- on AGA, HAM6 and HAM8 both stay live regardless of resolution. This test is what makes that difference visible: the same program produces real colour ramps on an A1200 and a flat, colourless readout on an ECS Agnus/OCS Denise machine or an A500+.

#### What changed from `ham8`

```
BPLCON0_HAM6     $6A00 -> $EA00   (HIRES bit added)
BPLCON0_HAM8     $0A10 -> $8A10   (HIRES bit added)
FMODE            $0000 -> $0001   (32-bit fetch)
DDFSTRT/DDFSTOP  $0038/$00B0 -> $0030/$0088
DIWSTOP          $2C81 -> $2CC1
PLANE_SIZE        1024 ->  2048
plus: every band reloads its pointers on a blank line (see below)
```

The band WAIT positions, pointer assignments and the copper timing ruler between the halves are otherwise untouched -- see `ham8/README.md` for the shared mechanism.

#### Why the pointer reload gets its own blank line

`ham8` reloads all eight bitplane pointers on the band's **first display line**, assuming the sixteen MOVEs finish well ahead of DDFSTRT. That only holds while bitplane DMA is off. With eight planes fetching, bitplane DMA takes most of the slots and starves the copper, so the last MOVEs in the block — BPL6PT, BPL7PT, BPL8PT — land late, leaving those planes a different distance into their buffers than planes 1-5.

That is invisible for most of the data, because `bitBuf0`-`bitBuf3` repeat every 2 bytes and `bitBuf4` every 4. `bitBuf5` is the exception: it is plane 8, the data field's MSB, and it repeats every 8 bytes — so a lag of 4 bytes mod 8 flips that bit and shifts the whole 64-entry ramp by **half its period**.

The band that escapes this is the first of each half, whose reload follows the copper ruler (or the top of the list) where the bitplanes were already off. So in `ham8` the palette band is reloaded cleanly and the three modify bands are not, and the palette band's ramp comes out shifted 32 pixels against them. Measured on a real A1200 in both resolutions, and reproduced by vAmiga in lores — genuine hardware behaviour, but an artefact of copper/DMA contention rather than anything to do with HAM. The original timing is preserved as its own test in `ham8_a` (lores) and `ham8hires_a` (hires); the latter is a known vAmiga/hardware divergence.

Every band here therefore switches the bitplanes off, reloads on that blank line, and switches the mode back on for the band's first display line — the discipline `Agnus/Registers/FMODE/fmode.i` already uses and documents for the same reason. With a clean reload all eight bands share one phase, so any difference left between them is HAM's doing. The cost is one blank raster line per band (19 display lines instead of 20).

#### Why FMODE has to change too

Setting HIRES alone is not enough. vAmiga's `Sequencer::computeFetchUnit` caps a hires line's bitplane fetch at 4 planes when FMODE is 0 -- there are not enough DMA slots for more. HAM6 needs 6 planes and HAM8 needs 8, so at FMODE 0 both halves fetch *nothing*: an earlier version of this test that kept FMODE at 0 came back solid black in both halves, on every chipset, which is a completely different (and far less interesting) result than the one below. A non-zero FMODE widens the fetch and lifts that cap to 8 -- the same fact the `Agnus/Registers/FMODE` suite already demonstrates for its own HIRES region (`fmode01` genuinely paints all 8 planes in hires at FMODE $0001). FMODE $0001 is the smallest value that does it, so that is what this test uses.

DDFSTRT/DDFSTOP move to $0030/$0088 to match -- the exact window `fmode01` already uses at this FMODE for hires, reused here rather than re-derived, since it is already proven to fetch a clean, non-shearing word count. DIWSTOP widens to $2CC1 to match, the constant `Denise/Modes/shres` already uses for HIRES with a DDFSTRT/DDFSTOP window of this shape. PLANE_SIZE doubles because a hires line now fetches twice the words a lores line does at the same FMODE.

#### The result

On an A1200 (AGA Denise), both halves paint real colour ramps -- red, green and blue, exactly as in `ham8`'s own lores picture, just at hires resolution. HAM did not need lores after all; it needed AGA.

On an A500 with ECS Agnus/OCS Denise, and on an A500+ (ECS Agnus/ECS Denise), the picture comes back solid black except for the copper timing ruler between the halves, which writes COLOR00 directly and never depends on bitplane DMA or HAM. Two separate restrictions point the same way here. The DMA one is more fundamental: `Sequencer::computeFetchUnit`'s non-AGA path only defines a hires fetch unit for BPU 1-4 -- there is no FMODE escape hatch pre-AGA, so BPU 6 (HAM6) and BPU 8 (HAM8) fetch *no bitplane data at all* in hires on these chipsets, the same "not enough DMA slots" limit the very first version of this test hit on every chipset at FMODE 0 (see the git history of this file). On top of that, even if the data did arrive, `lores(v) || isAGA()` is false once HIRES is set on these chipsets, so HAM would not engage either. Either restriction alone would produce this picture; both apply. The `_ecs`/`_plus` captures are that combination -- the documented, cross-chipset difference this test exists to show, not a bug in the test.

#### Hardware reference

The existing A1200 photograph was taken with the original pointer-reload timing and now lives with `ham8hires_a`, which still carries that code. This test needs a fresh photograph to confirm hardware agreement; with a clean reload all bands are expected to share one phase.

Dirk Hoffmann, 2026
