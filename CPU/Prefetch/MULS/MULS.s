;
; MULS -- is the prefetch of muls.w  d1,d2 taken at the beginning or at the end of the
; instruction? See ../prefetch.i and ../README.md for how the stripes are
; produced and how to read them.
;
; Source $5555: sixteen 01/10 transitions, the slowest MULS (70 cycles on the 68000).
;

OP_SRC              equ $00005555
OP_DST              equ $00001234

TESTINSTR	MACRO
	muls.w  d1,d2
	ENDM

	include "../prefetch.i"
