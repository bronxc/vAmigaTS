## Objective

`ham8hires_a` with the pointer reload started later in the line — the hires counterpart of `ham8_b`. One constant differs from `ham8hires_a`: the copper waits until hpos `$10` before reloading the bitplane pointers instead of starting at hpos `$00`. Nothing else.

See `ham8_b/README.md` for the timing model and the full `RELOAD_HP` table, `ham8_a/README.md` for the copper-starvation mechanism, and `ham8hires/README.md` for the HIRES and FMODE reasoning this file shares.

#### Where this sits

```
RELOAD_HP:  $00  $04  $08  $0C  $0E  $10  $12  $14  $18  $1C
lores:      1/2  1/2  3/4  1/4  1/4   0    0   1/4  1/4  1/4
hires:       0    0    0   1/2  1/2  1/2   0    0    0    -
```

| | `_a` (`$00`) | `_b` (`$10`) |
|---|---|---|
| lores | 1/2 period | 0 |
| hires | 0 | **1/2 period** |

In vAmiga the palette band's ramp resets at 62/126/190/254 while the modify bands reset at 94/158/222/286 — an offset of 32 texels against a period of 64, exactly half.

#### What to check

This one matters because of what happens at `RELOAD_HP` `$00`. There — `ham8hires_a` — vAmiga shows **no** shift at all while the A1200 clearly does, which is the one place in this family where emulator and hardware are known to part company. This variant moves hires to a lag where vAmiga *does* produce a shift.

- If the A1200 also shows half a period here, then vAmiga's hires contention is right at this lag and wrong at `$00`. That pins the disagreement to a specific point rather than to hires as a whole, which is a much sharper statement than "hires is broken".
- If the A1200 shows some other fraction, the table above converts it straight into how far vAmiga's timing is off.

Together the four tests bracket the behaviour: each resolution now has one lag where vAmiga reports a shift and one where it reports none, and the photographs decide which answers are right.

Dirk Hoffmann, 2026
