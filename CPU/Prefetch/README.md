## Objective

Find out *when* a long-running, register-only instruction performs its one
prefetch bus cycle: at the beginning of the instruction or at the end.

The question came up in Moira issue #38
(https://github.com/dirkwhoffmann/Moira/issues/38): `DIVU`/`DIVS` have the
right total cycle count, but Moira performs the prefetch before the long
internal computation, whereas SingleStepTests/680x0 shows it as the last
bus transaction of the instruction. The total cycle count can't tell the
two apart, but another bus master can.

#### DIVU, DIVS, MULU, MULS

All four tests share `prefetch.i`. Each defines the instruction under test
as a macro (`TESTINSTR`) plus its two operands, and includes the file.

    sled:     nop ... nop       entered at a varying offset
    sledend:  TESTINSTR         A      (longword aligned)
              nop               A+2
    target:   moveq #1,d0       A+4

When `TESTINSTR` starts, the prefetch queue already holds A+2, so the one
bus read it performs is the read of A+4. The word at `target` is read
exactly once, by the instruction under test, and whatever that read
returns ends up in d0.

The Blitter rewrites `target` while this happens. It runs a one-word-wide
A->D blit of BLITROWS rows with BLTDMOD = -2, so every row writes to
`target`. The first BLITROWS-1 rows write `moveq #1,d0` (no change), and
only the last row writes `moveq #0,d0`. The Blitter is therefore a timer
that flips the instruction at a fixed time after BLTSIZE is written.

The CPU writes BLTSIZE, jumps into the nop sled, and runs k nops before
`TESTINSTR`. Stripe i uses k = 2i, so going down the screen the instruction
under test starts later and later:

- **blue**: `target` was read before the Blitter changed it (d0 = 1)
- **yellow**: `target` was read after the Blitter changed it (d0 = 0)
- red / magenta: something went wrong (should never be seen)

The stripe where blue turns into yellow is the measurement. If the
prefetch happens at the end of the instruction, the read happens later,
so the switch comes *earlier* (higher on the screen). If it happens at the
beginning, the switch comes later, roughly by the instruction's length
divided by the time of two nops.

`MULU`/`MULS` serve as a reference. On the 68000, Moira does the MUL
prefetch first, so if the hardware agrees, the MUL switch marks "prefetch
at the beginning", and a DIV switch well above it means "prefetch at the
end".

All 32 trials run back to back in the vertical blank handler and write
their answers into the Copper list, which paints the stripes afterwards
(see CPU/68020/ICache for why).

The 68020 variant runs on an A1200 (AGA). There the CPU is twice as fast
relative to the Blitter, so the handler picks a shorter Blitter timer
(BLITROWS_020) when exec reports a 68020. It also switches off the
instruction cache, because a cached `target` would hide the Blitter's
write.

#### Results

Number of blue bars (= index of the first yellow stripe). "Moira before" is
the original code, which prefetched before the internal DIV cycles on both
CPUs.

| Test | 68000 real | 68000 Moira before | 68010 real | 68010 Moira before |
|------|:---:|:---:|:---:|:---:|
| DIVU | 8   | 16  | 15 | 15 |
| DIVS | 7   | 16  | 16 | 16 |
| MULU | 16  | 16  | 14 | 14 |
| MULS | 16  | 16  | 14 | 14 |

So the 68000 does the DIV prefetch at the end of the instruction, as
SingleStepTests says, while the 68010 does it at the beginning. MUL was
already right: the prefetch comes first on the 68000 and last on the
68010. Moira now branches on the CPU model in execDivsMoira and
execDivuMoira, and vAmiga matches all eight hardware results.

Moira's 68020 timing books the whole instruction in one go, so the 68020
variants haven't been compared yet; they're meant to be compared against
a real A1200.

Dirk Hoffmann, 2026
