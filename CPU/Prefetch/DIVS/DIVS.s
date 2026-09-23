;
; DIVS -- is the prefetch of divs.w  d1,d2 taken at the beginning or at the end of the
; instruction? See ../prefetch.i and ../README.md for how the stripes are
; produced and how to read them.
;
; 100 / 7: no overflow, positive operands, so a long division (~150 cycles on the 68000).
;

OP_SRC              equ $00000007
OP_DST              equ $00000064

TESTINSTR	MACRO
	divs.w  d1,d2
	ENDM

	include "../prefetch.i"
