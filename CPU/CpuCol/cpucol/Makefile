BASE = ../../../..
FLOPPY=bin/cpucol.adf
MODULE=cpucol.s

# The cache-toggle handlers use MOVEC/CACR (68010+/68020+ only). They are
# gated at runtime by is020plus, so the .adf still runs correctly on a
# plain 68000 -- this just lets the assembler accept the opcodes.
#
# -no-opt is required alongside it: vasm's -m68020 peephole optimizer
# silently rewrites "move.w #0,COLOR00(a1)" (the handlers' own black
# write) into "clr.w COLOR00(a1)". Same effect on paper, but CLR and MOVE
# have different timing on a real 68000, and this is a cycle-timing test
# -- confirmed by comparing vasm's own listing output (-L) with and
# without -no-opt: only -no-opt keeps the colour handlers' machine code
# byte-for-byte identical to a plain (no -m68020) assembly.
VASM_EXTRA_ARGS = -m68020 -no-opt

include $(BASE)/shared/base.mk
