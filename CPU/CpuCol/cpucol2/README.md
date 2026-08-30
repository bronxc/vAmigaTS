## Objective

CPU register-write timing with the instruction cache held on throughout,
instead of toggled section by section -- see `cpucol/README.md` for the
shared mechanism (Copper-fires-CPU-interrupt, six-write colour toggle,
STOP discipline, HPOS/HPSTEP row sampling).

This is `cpucol`'s own program with two substitutions. First: every
`CACHEOFF` in the copper list is `CACHEON` instead, so the cache never
gets turned off and every section reads GREEN/YELLOW. `irqcacheoff` and
`irq3_blue` are kept in the file -- unreachable, since nothing in the
copper list ever requests the PORTS interrupt that would trigger them --
purely so the program stays a recognizable, line-for-line copy of
`cpucol`'s; `irq3_blue`'s colour was changed from RED to GREEN so there's
no stray reference to a state this test never visits.

Second: with cache state no longer telling a pair's two halves apart,
giving them the same six trigger positions would make the second half
repeat the first half's row of colour segments exactly -- same colours,
same cache state, same DMA background, same horizontal sample points. So
the second half of each bitplane-count pair (sections 2/4/6/8/10)
triggers one Copper position later than the first (`HPOS2` vs. `HPOS`)
-- the smallest actual shift available, since a Copper WAIT's horizontal
field only compares in steps of 2 (bit 0 is reserved as the WAIT-vs-MOVE
flag, not part of the position).

See `cpucol3` for the cache-off counterpart.

Dirk Hoffmann, 2026
