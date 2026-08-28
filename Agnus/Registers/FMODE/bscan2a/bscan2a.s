	include "../../../../include/registers.i"
	include "hardware/dmabits.i"
	include "hardware/intbits.i"
	include "ministartup.s"

; Baseline: BSCAN2 off in both regions, so the region under test must come out identical to the control.
; Everything else lives in bscan2.i.

FMODE_B             equ $0000
MOD1_B              equ $0000
MOD2_B              equ $0000
REGB_SHIFT          equ 0

	include "../bscan2.i"
