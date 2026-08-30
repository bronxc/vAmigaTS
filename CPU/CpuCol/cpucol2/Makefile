BASE = ../../../..
FLOPPY=bin/cpucol2.adf
MODULE=cpucol2.s

# CACR is set once via MOVEC (68010+/68020+ only), gated at runtime by an
# AttnFlags check, so the .adf still runs correctly on a plain 68000 --
# this just lets the assembler accept the opcode.
#
# -no-opt is required alongside it: vasm's -m68020 peephole optimizer
# silently rewrites "move.w #0,COLOR00(a1)" (the handler's own black
# write) into "clr.w COLOR00(a1)". Same effect on paper, but CLR and MOVE
# have different timing on a real 68000, and this is a cycle-timing test
# -- see CPU/CpuCol/cpucol's own Makefile for the confirmation this was
# carried over from.
VASM_EXTRA_ARGS = -m68020 -no-opt

include $(BASE)/shared/base.mk
