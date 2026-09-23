## Objective

`ham8hires` with its original pointer-reload timing — the hires counterpart of `ham8_a`, and the one place in this family where vAmiga and real hardware disagree. The assembly is byte-for-byte what `ham8hires` was before its pointer reload was moved onto a blank line; only the comments differ.

See `ham8_a/README.md` for the copper-starvation mechanism (identical here) and `ham8hires/README.md` for the HIRES and FMODE reasoning this file shares.

#### The disagreement

On a real A1200 the shift is present in hires exactly as it is in lores. Mapping the photograph into the screenshot's coordinates via the copper ruler's red and green end markers (scale 1.3766 photo px per hires px):

| | palette band | modify bands | offset | period |
|---|---|---|---|---|
| **A1200** | 62.3, 127.6, 192.3, 256.2 | 94.9, 159.6, 224.2, 288.2 | −30.5 ≈ −32 | 64 |
| **vAmiga** | 94, 158, 222, 286 | 94, 158, 222, 286 | 0 | 64 |

The modify bands land on vAmiga's grid (+1.2 px mean over six resets), so the emulator has those right. The palette band on hardware sits half a period earlier; vAmiga puts it in step instead, showing no artefact at all.

The reason is that the lag itself differs. In hires, vAmiga's plane 8 ends up a multiple of 8 bytes out — `bitBuf5`'s own period — so the MSB does not flip and the shift vanishes. In lores it lands on 4 bytes mod 8, the MSB flips, and the artefact appears. Real hardware lands on a visible lag in both resolutions. So `ham8_a` agrees with hardware and this test does not.

Corroborating evidence that the palette band is the one that moved, not the modify bands:

- At the left edge the A1200's palette band starts at level ~172 and climbs to 243 before wrapping — it reads COLOR32→63 *first*, the direct signature of the data field being offset by 32. vAmiga starts it at 0.
- Both ramps span the same range and rise in the same direction, so this is a pure index offset, not a palette-content or gamma difference.
- The banked palette writes are faithful: `Agnus/Registers/FMODE/fmode.i` uses a byte-identical write routine across all 8 banks / 256 registers, and `fmode01`'s A1200 photo matches vAmiga exactly.

#### Reading the result

See `ham8hires_b` for the same program with the reload delayed to hpos `$10`, where vAmiga *does* produce a shift — between them they pin down whether the disagreement is specific to this lag or general to hires.

**The stored reference images are vAmiga's output, so this test PASSES.** It guards against vAmiga's behaviour changing, but it does *not* agree with `ham8hires_a_A1200.jpeg`, and the photograph is the ground truth. When the contention timing is corrected, this reference must be regenerated, and the palette band should then appear shifted by 32 pixels — matching the photo and matching `ham8_a`.

Dirk Hoffmann, 2026
