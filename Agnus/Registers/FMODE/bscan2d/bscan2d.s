	include "../../../../include/registers.i"
	include "hardware/dmabits.i"
	include "hardware/intbits.i"
	include "ministartup.s"

; bscan2b with the region under test moved down one raster line. The parity is anchored at DIWSTRT, not at the top of the region, so the picture must change: the first source line loses its second copy.
; Everything else lives in bscan2.i.

FMODE_B             equ $4000
MOD1_B              equ $FFD8
MOD2_B              equ $0000
REGB_SHIFT          equ 1

	include "../bscan2.i"
