	include "../../../../include/registers.i"
	include "hardware/dmabits.i"
	include "hardware/intbits.i"
	include "ministartup.s"

; The modulos of bscan2b swapped over. The doubling then starts on the other parity, so the first source line is shown once and every later one twice.
; Everything else lives in bscan2.i.

FMODE_B             equ $4000
MOD1_B              equ $0000
MOD2_B              equ $FFD8
REGB_SHIFT          equ 0

	include "../bscan2.i"
