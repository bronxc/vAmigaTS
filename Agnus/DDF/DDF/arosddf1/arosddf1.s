	include "../arosddf.i"
	
copper:
	COPPER

    dc.w	$2939,$FFFE  ; WAIT 
	RULER

    dc.w	$2A05,$FFFE  ; WAIT 
	dc.w    DIWSTRT,$2c81
	dc.w	DIWSTOP,$2cc1
	dc.w  	DDFSTRT,$003C
	dc.w  	DDFSTOP,$00D0

	dc.w	$f739,$FFFE  ; WAIT 
	RULER
	dc.w    $ffdf,$fffe  ; Cross vertical boundary
	dc.l	$fffffffe
