## Objective

CPU register-write timing, with the Blitter and the Copper's own colour
changes taken out of the measurement.

This is the `copbbusy` design turned around: instead of the Copper starting
the Blitter and waiting for BBUSY, the Copper fires a CPU interrupt and
steps aside. The CPU's handler writes a fixed sequence of colours into
COLOR00 -- six writes toggling between two colours, a white marker, then
black -- and goes back to sleep. Toggling rather than a gradient: every
write instant is a sharp edge between two maximally different colours, so
it can be read directly off the picture instead of inferred from a shade
boundary. The row that produces is a stripe of colour segments whose
boundaries are the CPU's individual write instants: get the CPU's
instruction timing or interrupt latency wrong, and the segment boundaries
land on the wrong pixels.

Sections come in pairs that share a bitplane count (0/0/1/1/2/2/3/3/4/4),
so each pair repeats the same six-row layout twice. The second half of
each pair is put to a second use: right before its row triggers, the
Copper fires a separate, one-shot interrupt that disables the CPU's
instruction cache (68020+ only; a no-op on 68000/68010, detected once at
startup via `AttnFlags`); the matching trigger at the top of the next
pair's first half turns it back on. The colour pair marks which is which:
green/yellow toggling for a cache-enabled section, red/yellow for a
cache-disabled one, so the two halves are told apart at a glance as well
as by row position.

```
dc.w    (VP)<<8|(HP),$FFFE   ; wait for the trigger position
dc.w    INTREQ,$8010         ; request a level 3 (COPER) interrupt
```

The interrupt vectors to a handler that acknowledges, writes the eight
colours, and executes STOP. Nothing waits for the CPU -- the Copper moves
straight on to the next trigger. There is no BBUSY-style rendezvous here
because there is nothing on the hardware side to finish; the whole point
is to see the CPU's own timing directly in the picture.

STOP rather than a loop or an RTE: the handler never returns, so RTE would
just accumulate stale exception frames, and a spin loop would still fetch
(there is no instruction cache on a 68000 to spin from instead). A stopped
CPU issues no bus cycles at all, and wakes cleanly on the next trigger's
interrupt.

MAIN itself waits for the very first trigger with a plain busy loop, not
STOP, exactly as `copbbusy.i`'s MAIN does. STOP is privileged, and an
earlier draft that executed it directly in MAIN took a privilege
violation (confirmed on Amiberry: Guru `#00000008`). Once inside the
handler -- reached only through a real interrupt exception, which always
enters in supervisor mode -- STOP is exactly as safe as it is in
`copbbusy.i`.

Within a section, each row's trigger position moves a little later in the
line (`HPOS`/`HPSTEP`) than the row above it, so the same instruction
sequence gets sampled at six different phases against the DMA slot grid.
The next section resets back to the original position. Six rows and ten
sections mirror `bbusy`/`copbbusy`'s layout, but nothing here depends on
the Blitter, so there is only one version of this test -- no BLTCON0/
BLTCON1/BLTSIZE combinations to multiply it by.

The colour handler comes in two byte-for-byte identical copies, `irq3_red`
and `irq3_blue`, differing only in which six immediate colour values they
move into COLOR00. Two copies rather than one table-driven routine: an
indexed load (colour-table pointer, then six `(a0)+` reads) is a different
addressing mode from six immediate moves, with different timing, and that
would confound the very thing being measured. Whichever copy is current is
installed into `LVL3_INT_VECTOR` by the cache-toggle handlers, so
switching colour and switching cache state happen together, at the same
section boundary, for the same reason.

**Build note:** the cache toggle needs `MOVEC`/`CACR` (68010+/68020+), so
the Makefile assembles with `-m68020`. That alone is not enough: vasm's
`-m68020` peephole optimizer silently rewrites `move.w #0,COLOR00(a1)`
(the handlers' own final "black" write) into `clr.w COLOR00(a1)` --
equivalent on paper, but CLR and MOVE have different timing on a real
68000, which corrupted exactly the thing this test measures (an extra,
wrongly-timed colour blip right after the white marker on every row).
The Makefile also passes `-no-opt` to suppress this and other
optimizations; confirmed by comparing vasm's own listing output (`-L`)
with and without it, so the colour handlers' machine code stays
byte-for-byte identical to a plain (no `-m68020`) assembly.

Dirk Hoffmann, 2026
