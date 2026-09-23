BASE = ../../../..
FLOPPY=bin/MULU.adf
MODULE=MULU.s

# -m68020 lets the assembler accept the MOVEC that switches the 68020's
# instruction cache off (gated at runtime, never executed on a 68000).
# -no-opt keeps vasm from rewriting any instruction of the timed code.
VASM_EXTRA_ARGS = -m68020 -no-opt

include $(BASE)/shared/base.mk
