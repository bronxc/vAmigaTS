;
; MULU -- is the prefetch of mulu.w  d1,d2 taken at the beginning or at the end of the
; instruction? See ../prefetch.i and ../README.md for how the stripes are
; produced and how to read them.
;
; Source $FFFF: sixteen one bits, the slowest MULU (70 cycles on the 68000).
;

OP_SRC              equ $0000FFFF
OP_DST              equ $00001234

TESTINSTR	MACRO
	mulu.w  d1,d2
	ENDM

	include "../prefetch.i"
