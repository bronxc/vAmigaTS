## Objective

The DDF tests use the Copper to modify DDFSTART and DDSTOP in various ways.

#### ddfstrt1 to ddfstrt9, ddfstrt1h to ddfstrt9h

DDFSTRT is incremented continously at the end of certain rasterlines. DDFSTOP remains at a fixed position. Test cases with the 'h' suffix run in hires modes, all others in lores mode.

#### ddfstrt10 to ddfstrt15, ddfstrt10h to ddfstrt15h

Same as ddfstrt1 to ddfstrt6 (ddfstrt1h to ddfstrt6h), but with swapped values for DDFSTRT and DDFSTOP. Hence, DDFSTRT is greater than DDFSTOP in all cases. 

#### ddfinv1

Tests some combinations where DDFSTRT is greater than DDFSTOP.

#### ddfinv2 and ddfinv3

Sets DDFSTRT and DDFSTOP to values close to the hardware stops.

#### ddfinv4

Tests some combinations where DDFTOP is outside the valid range (i.e., values that are larger than the upper hardware stop and larger than the highest DMA cycle number).

#### ddfinv5

DDFSTOP is set to $E2. DDFSTRT varies. 

#### ddfskip1

Changes DDFSTRT near the trigger position.

#### ddfskip2

Changes DDFSTOP near the trigger position.

Dirk Hoffmann, 2019
