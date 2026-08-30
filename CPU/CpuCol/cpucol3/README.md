## Objective

CPU register-write timing with the instruction cache held off throughout,
instead of toggled section by section -- see `cpucol/README.md` for the
shared mechanism, and `cpucol2/README.md` (this test's cache-on
counterpart) for the reasoning behind the single substitution.

This is `cpucol`'s own program with two substitutions. First: every
`CACHEON` in the copper list is `CACHEOFF` instead, so the cache never
gets turned on and every section reads RED/YELLOW. `irqcacheon` and
`irq3_red` are kept in the file -- unreachable, since nothing in the
copper list ever requests the SOFT interrupt that would trigger them --
purely so the program stays a recognizable, line-for-line copy of
`cpucol`'s; `irq3_red`'s colour was changed from GREEN to RED, and
`MAIN`'s initial handler install from `irq3_red` to `irq3_blue`, so
neither one leaves a stray reference to a state this test never visits.

Second: with cache state no longer telling a pair's two halves apart,
giving them the same six trigger positions would make the second half
repeat the first half's row of colour segments exactly. So, exactly as
in `cpucol2`, the second half of each bitplane-count pair (sections
2/4/6/8/10) triggers one Copper position later than the first (`HPOS2`
vs. `HPOS`) -- the smallest actual shift available, since a Copper
WAIT's horizontal field only compares in steps of 2.

Dirk Hoffmann, 2026
