## Objective

`ham8_a` with the pointer reload started later in the line, which changes the lag — and with it what the picture shows. One constant differs from `ham8_a`: the copper waits until hpos `$10` before reloading the bitplane pointers instead of starting at hpos `$00`. Nothing else.

See `ham8_a/README.md` for the copper-starvation mechanism, and `ham8/README.md` for the HAM6-versus-HAM8 comparison both share.

#### The lag is a function of when the reload starts

A copper MOVE takes **4** colour clocks, not 2 — which is where the original `ham8` comment went wrong. `PTRBLOCK` writes BPL1PTH, BPL1PTL, BPL2PTH, … BPL8PTL in that order, so plane *p*'s second MOVE completes at `RELOAD_HP + 8p`:

```
plane p is loaded in time   <=>   RELOAD_HP + 8p <= DDFSTRT
```

At `RELOAD_HP` `$00` that puts planes 7-8 late in lores (DDFSTRT `$38`) and planes 6-8 late in hires (DDFSTRT `$30`) — exactly what the bitplane pointers show when dumped from the emulator. A plane written after DDFSTRT has already fetched part of the line through its old pointer, so it ends the line a different distance into its buffer than the planes that made it.

Only plane 8 is visible, because `bitBuf5` repeats every 8 bytes while the other data buffers repeat every 2 or 4. The picture therefore shows `lag mod 8 bytes`, in steps of one word — quarters of the 64-entry ramp. Measured in vAmiga on an A1200:

```
RELOAD_HP:  $00  $04  $08  $0C  $0E  $10  $12  $14  $18  $1C
lores:      1/2  1/2  3/4  1/4  1/4   0    0   1/4  1/4  1/4
hires:       0    0    0   1/2  1/2  1/2   0    0    0    -
```

`$10` inverts the answer in **both** resolutions relative to the `_a` pair: lores loses its shift, hires gains one.

| | `_a` (`$00`) | `_b` (`$10`) |
|---|---|---|
| lores | 1/2 period | **0** |
| hires | 0 | **1/2 period** |

The value sits one step from the edge of its window in both cases, deliberately. A contention timing that differs from vAmiga's by a single step lands in a different bucket, so the picture says so.

#### What to check

vAmiga puts all four HAM8 bands on the same phase here — the palette band is **not** shifted, and the picture looks like the fixed `ham8` even though the reload still races the DMA. That is the same answer vAmiga gives for `ham8hires_a`, where the A1200 disagrees and does shift.

So this is the lores counterpart of that failure:

- If the A1200 shows the palette band shifted by any amount here, **vAmiga is wrong in lores too** and the divergence is not confined to hires.
- If the A1200 also shows no shift, vAmiga and hardware agree at this lag and the hires case stands alone.

Either outcome is worth having on record. Read the shift off the photograph and look it up in the table above — it converts directly into how far vAmiga's contention timing is off.

Dirk Hoffmann, 2026
