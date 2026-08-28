	include "../../../../include/registers.i"
	include "hardware/dmabits.i"
	include "hardware/intbits.i"
	include "ministartup.s"

; Scan doubling. BPL1MOD rewinds one line (-40 bytes), BPL2MOD leaves the pointers alone, so every source line is fetched and shown twice.
; Everything else lives in bscan2.i.

FMODE_B             equ $4000
MOD1_B              equ $FFD8
MOD2_B              equ $0000
REGB_SHIFT          equ 0

	include "../bscan2.i"
