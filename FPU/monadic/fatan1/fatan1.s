    include "../../fpureg.i"
	include "../../arith1.i"

trap0:
    fmove   #$40,FPCR   ; Precision: Single, Rounding: To nearest
    TEST    fatan
    rte

info: 
    dc.b    'FATAN1', 0
    even 

expected:
    dc.b    $00,$00,$00,$00,  $00,$00,$00,$00  ; 1
    dc.b    $00,$00,$00,$00,  $04,$00,$00,$00  ; 2
    dc.b    $80,$00,$00,$00,  $00,$00,$00,$00  ; 3
    dc.b    $00,$00,$00,$00,  $0C,$00,$00,$00  ; 4
    dc.b    $3F,$FE,$00,$00,  $C9,$0F,$DB,$00  ; 5
    dc.b    $00,$00,$00,$00,  $00,$00,$02,$08  ; 6
    dc.b    $BF,$FE,$00,$00,  $C9,$0F,$DB,$00  ; 7
    dc.b    $00,$00,$00,$00,  $08,$00,$02,$08  ; 8
    dc.b    $3F,$FF,$00,$00,  $8D,$B7,$0D,$00  ; 9
    dc.b    $00,$00,$00,$00,  $00,$00,$02,$08  ; 10
    dc.b    $BF,$FF,$00,$00,  $8D,$B7,$0D,$00  ; 11
    dc.b    $00,$00,$00,$00,  $08,$00,$02,$08  ; 12
    dc.b    $3F,$FD,$00,$00,  $ED,$63,$38,$00  ; 13
    dc.b    $00,$00,$00,$00,  $00,$00,$02,$08  ; 14
    dc.b    $BF,$FD,$00,$00,  $ED,$63,$38,$00  ; 15
    dc.b    $00,$00,$00,$00,  $08,$00,$02,$08  ; 16
    dc.b    $3F,$FB,$00,$00,  $CC,$1F,$14,$00  ; 17
    dc.b    $00,$00,$00,$00,  $00,$00,$02,$08  ; 18
    dc.b    $BF,$FB,$00,$00,  $CC,$1F,$14,$00  ; 19
    dc.b    $00,$00,$00,$00,  $08,$00,$02,$08  ; 20
    dc.b    $3F,$FF,$00,$00,  $C8,$08,$ED,$00  ; 21
    dc.b    $00,$00,$00,$00,  $00,$00,$02,$08  ; 22
    dc.b    $BF,$FF,$00,$00,  $C8,$08,$ED,$00  ; 23
    dc.b    $00,$00,$00,$00,  $08,$00,$02,$08  ; 24
