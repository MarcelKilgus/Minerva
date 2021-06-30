* Default secondary fount
        xdef    tb_f1,tb_hex

..... equ %0000000
....O equ %0000100
...O. equ %0001000
...OO equ %0001100
..O.. equ %0010000
..O.O equ %0010100
..OO. equ %0011000
..OOO equ %0011100
.O... equ %0100000
.O..O equ %0100100
.O.O. equ %0101000
.O.OO equ %0101100
.OO.. equ %0110000
.OO.O equ %0110100
.OOO. equ %0111000
.OOOO equ %0111100
O.... equ %1000000
O...O equ %1000100
O..O. equ %1001000
O..OO equ %1001100
O.O.. equ %1010000
O.O.O equ %1010100
O.OO. equ %1011000
O.OOO equ %1011100
OO... equ %1100000
OO..O equ %1100100
OO.O. equ %1101000
OO.OO equ %1101100
OOO.. equ %1110000
OOO.O equ %1110100
OOOO. equ %1111000
OOOOO equ %1111100

        section tb_f1
tb_f1
 dc.b $80,(tb_f1x-tb_f1-11)/9 first character and total number less one

 dc.b O...O
 dc.b .....
 dc.b .OO.O
 dc.b O..OO
 dc.b O...O
 dc.b O..OO
 dc.b .OO.O
 dc.b .....
 dc.b .....

 dc.b ..O.O
 dc.b .O.O.
 dc.b .....
 dc.b .OOOO
 dc.b O...O
 dc.b O..OO
 dc.b .OO.O
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .O.O.
 dc.b ..O..
 dc.b .OOOO
 dc.b O...O
 dc.b O..OO
 dc.b .OO.O
 dc.b .....
 dc.b .....

 dc.b ...O.
 dc.b ..O..
 dc.b .OOO.
 dc.b O...O
 dc.b OOOOO
 dc.b O....
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b O...O
 dc.b .....
 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b ..O.O
 dc.b .O.O.
 dc.b .....
 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b .OOOO
 dc.b O..OO
 dc.b O.O.O
 dc.b OO..O
 dc.b OOOO.
 dc.b .....
 dc.b .....

 dc.b O...O
 dc.b .....
 dc.b .....
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b .OOOO
 dc.b O....
 dc.b O....
 dc.b O....
 dc.b .OOOO
 dc.b ..O..
 dc.b .O...

 dc.b ..O.O
 dc.b .O.O.
 dc.b .....
 dc.b OOOO.
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b .OOOO
 dc.b ..O.O
 dc.b .OOOO
 dc.b O.O..
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b .O.OO
 dc.b O.O..
 dc.b O.OOO
 dc.b O.O..
 dc.b .O.OO
 dc.b .....
 dc.b .....

 dc.b ...O.
 dc.b ..O..
 dc.b .OO.O
 dc.b O..OO
 dc.b O...O
 dc.b O..OO
 dc.b .OO.O
 dc.b .....
 dc.b .....

 dc.b .O...
 dc.b ..O..
 dc.b .OO.O
 dc.b O..OO
 dc.b O...O
 dc.b O..OO
 dc.b .OO.O
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .O.O.
 dc.b .....
 dc.b .OOOO
 dc.b O...O
 dc.b O..OO
 dc.b .OO.O
 dc.b .....
 dc.b .....

 dc.b O...O
 dc.b .....
 dc.b .OOO.
 dc.b O...O
 dc.b OOOOO
 dc.b O....
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b .O...
 dc.b ..O..
 dc.b .OOO.
 dc.b O...O
 dc.b OOOOO
 dc.b O....
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .O.O.
 dc.b .OOO.
 dc.b O...O
 dc.b OOOOO
 dc.b O....
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b O...O
 dc.b .....
 dc.b .....
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ...O.
 dc.b .....
 dc.b .....

 dc.b ...O.
 dc.b ..O..
 dc.b .....
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ...O.
 dc.b .....
 dc.b .....

 dc.b .O...
 dc.b ..O..
 dc.b .....
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ...O.
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .O.O.
 dc.b .....
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ...O.
 dc.b .....
 dc.b .....

 dc.b ...O.
 dc.b ..O..
 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b .O...
 dc.b ..O..
 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .O.O.
 dc.b .....
 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b ...O.
 dc.b ..O..
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b .O...
 dc.b ..O..
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .O.O.
 dc.b .....
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b O.OO.
 dc.b O...O
 dc.b O...O
 dc.b O.OO.
 dc.b O....
 dc.b O....

 dc.b .....
 dc.b ...O.
 dc.b .OOOO
 dc.b O..O.
 dc.b O..O.
 dc.b O..O.
 dc.b .OOOO
 dc.b ...O.
 dc.b .....

 dc.b O...O
 dc.b O...O
 dc.b .O.O.
 dc.b ..O..
 dc.b OOOOO
 dc.b ..O..
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b .O...
 dc.b ..O..
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b O...O
 dc.b ..O..
 dc.b .O.O.
 dc.b O...O
 dc.b OOOOO
 dc.b O...O
 dc.b O...O
 dc.b .....
 dc.b .....

 dc.b ..O.O
 dc.b .O.O.
 dc.b ..O..
 dc.b .O.O.
 dc.b O...O
 dc.b OOOOO
 dc.b O...O
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .O.O.
 dc.b ..O..
 dc.b .O.O.
 dc.b O...O
 dc.b OOOOO
 dc.b O...O
 dc.b .....
 dc.b .....

 dc.b ...O.
 dc.b ..O..
 dc.b OOOOO
 dc.b O....
 dc.b OOOOO
 dc.b O....
 dc.b OOOOO
 dc.b .....
 dc.b .....

 dc.b O...O
 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b ..O.O
 dc.b .O.O.
 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b .OO.O
 dc.b O...O
 dc.b O..OO
 dc.b O.O.O
 dc.b OO..O
 dc.b O...O
 dc.b O.OO.
 dc.b .....
 dc.b .....

 dc.b O...O
 dc.b .....
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b .OOO.
 dc.b O...O
 dc.b O....
 dc.b O....
 dc.b O...O
 dc.b .OOO.
 dc.b ..O..
 dc.b .O...
 dc.b .....

 dc.b .OOO.
 dc.b .....
 dc.b O...O
 dc.b OO..O
 dc.b O.O.O
 dc.b O..OO
 dc.b O...O
 dc.b .....
 dc.b .....

 dc.b .OOOO
 dc.b O..O.
 dc.b O..O.
 dc.b OOOOO
 dc.b O..O.
 dc.b O..O.
 dc.b O..OO
 dc.b .....
 dc.b .....

 dc.b .OOOO
 dc.b O..O.
 dc.b O..O.
 dc.b O..OO
 dc.b O..O.
 dc.b O..O.
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b .O..O
 dc.b O.OO.
 dc.b O..O.
 dc.b O.OO.
 dc.b .O..O
 dc.b .....
 dc.b .....

 dc.b .OOO.
 dc.b O...O
 dc.b O....
 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b OOOOO
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b O....
 dc.b .O...
 dc.b .O...
 dc.b ..O..
 dc.b ..OO.
 dc.b .O.O.
 dc.b O...O
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b OO..O
 dc.b O.OOO
 dc.b O....
 dc.b O....

 dc.b .....
 dc.b .....
 dc.b .OOOO
 dc.b OO.O.
 dc.b .O.O.
 dc.b .O.O.
 dc.b .O.O.
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b ..O..
 dc.b .OOO.
 dc.b O.O.O
 dc.b O.O.O
 dc.b O.O.O
 dc.b .OOO.
 dc.b ..O..
 dc.b ..O..

 dc.b ..O..
 dc.b .....
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .....
 dc.b ..O..
 dc.b .O...
 dc.b O....
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b .OOO.
 dc.b O...O
 dc.b O.O.O
 dc.b O..O.
 dc.b .OO.O
 dc.b .....
 dc.b O...O
 dc.b .O.O.
 dc.b ..O..

 dc.b .OOO.
 dc.b O...O
 dc.b O....
 dc.b .OOO.
 dc.b O...O
 dc.b .OOO.
 dc.b ....O
 dc.b O...O
 dc.b .OOO.

 dc.b .....
 dc.b O...O
 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b O...O
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b ..O.O
 dc.b .O.O.
 dc.b O.O..
 dc.b .O.O.
 dc.b ..O.O
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b O.O..
 dc.b .O.O.
 dc.b ..O.O
 dc.b .O.O.
 dc.b O.O..
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .O.O.
 dc.b ..O..
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b ..O..
 dc.b .....
 dc.b OOOOO
 dc.b .....
 dc.b ..O..
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b ..O..
 dc.b .OO..
 dc.b OOOOO
 dc.b .OO..
 dc.b ..O..
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b ..O..
 dc.b ..OO.
 dc.b OOOOO
 dc.b ..OO.
 dc.b ..O..
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b ..O..
 dc.b .OOO.
 dc.b OOOOO
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b .....

 dc.b .....
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b OOOOO
 dc.b .OOO.
 dc.b ..O..
 dc.b .....
* 192 minerva extended chars!
 dc.b .....
 dc.b OOOO.
 dc.b OOO..
 dc.b OOO..
 dc.b O.O..
 dc.b O..O.
 dc.b ....O
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .OOOO
 dc.b ..OOO
 dc.b ..OOO
 dc.b ..O.O
 dc.b .O..O
 dc.b O....
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b ....O
 dc.b O..O.
 dc.b O.O..
 dc.b OOO..
 dc.b OOO..
 dc.b OOOO.
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b O....
 dc.b .O..O
 dc.b ..O.O
 dc.b ..OOO
 dc.b ..OOO
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b ..O..
 dc.b .O.O.
 dc.b .O.O.
 dc.b O...O
 dc.b O...O
 dc.b OOOOO
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b O.OO.
 dc.b OO..O
 dc.b .O..O
 dc.b .O..O
 dc.b O..O.
 dc.b ...O.
 dc.b ..O..

 dc.b .OOO.
 dc.b ..O..
 dc.b OOOOO
 dc.b O.O.O
 dc.b OOOOO
 dc.b ..O..
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b OOOOO
 dc.b O...O
 dc.b O....
 dc.b O....
 dc.b O....
 dc.b O....
 dc.b O....
 dc.b .....
 dc.b .....
* 200
 dc.b ..O..
 dc.b .OOO.
 dc.b .OOO.
 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b O.O.O
 dc.b ..O..
 dc.b .OOO.

 dc.b .....
 dc.b .O.O.
 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b .OOO.
 dc.b ..O..
 dc.b .....

 dc.b ..O..
 dc.b ..O..
 dc.b .OOO.
 dc.b .OOO.
 dc.b OOOOO
 dc.b .OOO.
 dc.b .OOO.
 dc.b ..O..
 dc.b ..O..

 dc.b .OOO.
 dc.b ..O..
 dc.b O.O.O
 dc.b OOOOO
 dc.b O.O.O
 dc.b ..O..
 dc.b ..O..
 dc.b .OOO.
 dc.b .....

 dc.b ..O..
 dc.b ..O..
 dc.b .O.O.
 dc.b .O.O.
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .....
 dc.b .....

 dc.b OOOOO
 dc.b O...O
 dc.b O...O
 dc.b .O.O.
 dc.b .O.O.
 dc.b ..O..
 dc.b ..O..
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b .O.O.
 dc.b O.O.O
 dc.b O.O.O
 dc.b O.O.O
 dc.b .O.O.
 dc.b .....
 dc.b .....

 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .O.O.
 dc.b OO.OO
 dc.b .....
 dc.b .....
* 208
 dc.b OOOOO
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b .....
 dc.b .....

 dc.b O.O.O
 dc.b O.O.O
 dc.b O.O.O
 dc.b .OOO.
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b .....
 dc.b .....

 dc.b .OOOO
 dc.b O....
 dc.b O.OO.
 dc.b O.O.O
 dc.b O.OO.
 dc.b O.O.O
 dc.b O....
 dc.b .OOOO
 dc.b .....

 dc.b OOOOO
 dc.b .O...
 dc.b ..O..
 dc.b ...O.
 dc.b ..O..
 dc.b .O...
 dc.b OOOOO
 dc.b .....
 dc.b .....

 dc.b .OOO.
 dc.b O...O
 dc.b O...O
 dc.b O.O.O
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b O...O
 dc.b .O.O.
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b ..O..
 dc.b .OOO.
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..

 dc.b ..O..
 dc.b ..O..
 dc.b .OOO.
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b .OOO.
 dc.b ..O..
 dc.b ..O..
* 216
 dc.b OOOOO
 dc.b O...O
 dc.b .....
 dc.b .OOO.
 dc.b .....
 dc.b O...O
 dc.b OOOOO
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b ..O..
 dc.b OOOOO
 dc.b ..O..
 dc.b ..O..
 dc.b .....
 dc.b OOOOO
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b .OOO.
 dc.b O...O
 dc.b O....
 dc.b O....
 dc.b .OOO.
 dc.b ...O.
 dc.b ..O..

 dc.b .....
 dc.b OOOOO
 dc.b .....
 dc.b OOOOO
 dc.b .....
 dc.b OOOOO
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b ...OO
 dc.b .OO..
 dc.b O....
 dc.b .OO..
 dc.b ...OO
 dc.b .....
 dc.b OOOOO
 dc.b .....
 dc.b .....

 dc.b ....O
 dc.b ...O.
 dc.b OOOOO
 dc.b ..O..
 dc.b OOOOO
 dc.b .O...
 dc.b O....
 dc.b .....
 dc.b .....

 dc.b OO...
 dc.b ..OO.
 dc.b ....O
 dc.b ..OO.
 dc.b OO...
 dc.b .....
 dc.b OOOOO
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .O...
 dc.b O.O.O
 dc.b ...O.
 dc.b .O...
 dc.b O.O.O
 dc.b ...O.
 dc.b .....
 dc.b .....
* 224
 dc.b OOOOO
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b O...O
 dc.b OOOOO
 dc.b .....
 dc.b .....

 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b .....
 dc.b .....

 dc.b .OOO.
 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b OOOOO
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b O...O
 dc.b .O..O
 dc.b .O.O.
 dc.b ..O..
 dc.b .O.O.
 dc.b O..O.
 dc.b O...O

 dc.b .OO..
 dc.b O..O.
 dc.b ....O
 dc.b ..OOO
 dc.b .O..O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b .OOOO
 dc.b O....
 dc.b OOOO.
 dc.b O....
 dc.b .OOOO
 dc.b .....
 dc.b .....

 dc.b OOOO.
 dc.b O....
 dc.b OOO..
 dc.b O....
 dc.b O.OO.
 dc.b O.O.O
 dc.b ..OO.
 dc.b ..O.O
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b O...O
 dc.b OO..O
 dc.b ..O.O
 dc.b ...O.
 dc.b ...O.
 dc.b .OO..
 dc.b .....
* 232
 dc.b .O.O.
 dc.b .OO..
 dc.b .O...
 dc.b OO...
 dc.b .OOO.
 dc.b .O..O
 dc.b .O..O
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O.O
 dc.b ...O.
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b .....
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..

 dc.b .....
 dc.b .....
 dc.b O...O
 dc.b O..O.
 dc.b OOO..
 dc.b O..O.
 dc.b O...O
 dc.b .....
 dc.b .....

 dc.b .O...
 dc.b .O...
 dc.b .O..O
 dc.b .O.O.
 dc.b ..O..
 dc.b .O.O.
 dc.b O.OO.
 dc.b .OOOO
 dc.b ...O.

 dc.b .O...
 dc.b .O...
 dc.b .O..O
 dc.b .O.O.
 dc.b ..O..
 dc.b .O.OO
 dc.b O...O
 dc.b ...O.
 dc.b ..OOO

 dc.b OO...
 dc.b ..O..
 dc.b .O..O
 dc.b ..OO.
 dc.b OOO..
 dc.b .O.O.
 dc.b O.OO.
 dc.b .OOOO
 dc.b ...O.

 dc.b .....
 dc.b .....
 dc.b .O.O.
 dc.b O...O
 dc.b O.O.O
 dc.b O.O.O
 dc.b .O.O.
 dc.b .....
 dc.b .....
* 240
 dc.b ..O..
 dc.b ..O..
 dc.b O.O.O
 dc.b O.O.O
 dc.b O.O.O
 dc.b O.O.O
 dc.b .OOO.
 dc.b ..O..
 dc.b ..O..

 dc.b .O...
 dc.b ..O..
 dc.b OOOO.
 dc.b ....O
 dc.b OOOO.
 dc.b ..O..
 dc.b .O...
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b ..OO.
 dc.b .O..O
 dc.b .O..O
 dc.b .OOO.
 dc.b .O...
 dc.b O....
 dc.b O....

 dc.b .....
 dc.b .....
 dc.b ..OOO
 dc.b .O.O.
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b .OOOO
 dc.b O.O..
 dc.b ..O..
 dc.b ..O..
 dc.b ..O..
 dc.b .....
 dc.b .....

 dc.b .....
 dc.b .....
 dc.b O...O
 dc.b .O..O
 dc.b O...O
 dc.b O...O
 dc.b .OOO.
 dc.b .....
 dc.b .....

 dc.b ....O
 dc.b ....O
 dc.b ....O
 dc.b ...O.
 dc.b ...O.
 dc.b .O.O.
 dc.b O.O..
 dc.b O.O..
 dc.b ..O..

 dc.b O...O
 dc.b .O..O
 dc.b OO..O
 dc.b .O.O.
 dc.b O..O.
 dc.b .O.O.
 dc.b O.O..
 dc.b O.O..
 dc.b ..O..
* 248
 dc.b .O...
 dc.b .OOOO
 dc.b O....
 dc.b .OOO.
 dc.b O....
 dc.b O....
 dc.b .OO..
 dc.b ...O.
 dc.b .OO..

 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b O.O.O
 dc.b O.O.O
 dc.b .....
 dc.b .....

 dc.b .O..O
 dc.b ..OOO
 dc.b ...O.
 dc.b ..O..
 dc.b ..O..
 dc.b .O...
 dc.b .OOO.
 dc.b ....O
 dc.b ..OO.

 dc.b .....
 dc.b .....
 dc.b ..OO.
 dc.b .OOOO
 dc.b OO.OO
 dc.b OO...
 dc.b OO...
 dc.b .OO..
 dc.b .OO..

 dc.b .OO..
 dc.b .OO..
 dc.b .OO..
 dc.b .OO..
 dc.b .OO..
 dc.b .OO..
 dc.b .OO..
 dc.b .OO..
 dc.b .OO..

 dc.b ..OO.
 dc.b ..OO.
 dc.b ...OO
 dc.b ...OO
 dc.b OO.OO
 dc.b OOOO.
 dc.b .OO..
 dc.b .....
 dc.b .....

 dc.b O...O
 dc.b ..O..
 dc.b ...O.
 dc.b .O...
 dc.b O...O
 dc.b ...O.
 dc.b .O...
 dc.b ..O..
 dc.b O...O

 dc.b O..O.
 dc.b ..O..
 dc.b O..O.
 dc.b .O..O
 dc.b ..O..
 dc.b .O..O
 dc.b O..O.
 dc.b ..O..
 dc.b .O..O
* 0
 dc.b OO.O.
 dc.b O.OO.
 dc.b O..O.
 dc.b ..O.O
 dc.b ..O.O
 dc.b O.OOO
 dc.b O....
 dc.b O....
 dc.b OOO..

 dc.b OOOO.
 dc.b O....
 dc.b OOO..
 dc.b O....
 dc.b O..O.
 dc.b ..OO.
 dc.b ...O.
 dc.b ...O.
 dc.b ..OOO

 dc.b OOOO.
 dc.b O....
 dc.b OOO..
 dc.b O....
 dc.b O..O.
 dc.b ..O.O
 dc.b ....O
 dc.b ...O.
 dc.b ..OOO

 dc.b OOOO.
 dc.b O....
 dc.b OOO..
 dc.b O....
 dc.b O.OO.
 dc.b ....O
 dc.b ..OO.
 dc.b ....O
 dc.b ..OO.

 dc.b OOOO.
 dc.b O....
 dc.b OOO..
 dc.b O....
 dc.b O..O.
 dc.b ..OO.
 dc.b .O.O.
 dc.b .OOOO
 dc.b ...O.

 dc.b OOOO.
 dc.b O....
 dc.b OOO..
 dc.b O....
 dc.b O.OOO
 dc.b ..O..
 dc.b ..OOO
 dc.b ....O
 dc.b ..OOO

 dc.b .O...
 dc.b O.O..
 dc.b OOO..
 dc.b O.O..
 dc.b .....
 dc.b ..O.O
 dc.b ..OO.
 dc.b ..OO.
 dc.b ..O.O

 dc.b ..O..
 dc.b ..OO.
 dc.b ..O.O
 dc.b ..O..
 dc.b ..O..
 dc.b .OO..
 dc.b OOO..
 dc.b OOO..
 dc.b .O...
* 8
 dc.b OO...
 dc.b O.O..
 dc.b OO...
 dc.b O.O..
 dc.b OO.OO
 dc.b ..O..
 dc.b ...O.
 dc.b ....O
 dc.b ..OO.

 dc.b O.O..
 dc.b O.O..
 dc.b OOO..
 dc.b O.O..
 dc.b O.O..
 dc.b ..OOO
 dc.b ...O.
 dc.b ...O.
 dc.b ...O.

 dc.b O....
 dc.b O....
 dc.b O....
 dc.b OOO..
 dc.b ..OOO
 dc.b ..O..
 dc.b ..OO.
 dc.b ..O..
 dc.b ..O..

 dc.b O.O..
 dc.b O.O..
 dc.b O.O..
 dc.b .O...
 dc.b ..OOO
 dc.b ...O.
 dc.b ...O.
 dc.b ...O.
 dc.b ...O.

 dc.b OOO..
 dc.b O....
 dc.b OO...
 dc.b O....
 dc.b O.OOO
 dc.b ..O..
 dc.b ..OO.
 dc.b ..O..
 dc.b ..O..

 dc.b .OO..
 dc.b O....
 dc.b O....
 dc.b .OO..
 dc.b .....
 dc.b ..OO.
 dc.b ..O.O
 dc.b ..OO.
 dc.b ..O.O

 dc.b .OO..
 dc.b O....
 dc.b .O...
 dc.b ..O..
 dc.b OO.O.
 dc.b ..O.O
 dc.b ..O.O
 dc.b ..O.O
 dc.b ...O.

 dc.b .OO..
 dc.b O....
 dc.b .O...
 dc.b ..O..
 dc.b OO...
 dc.b ..OOO
 dc.b ...O.
 dc.b ...O.
 dc.b ..OOO
tb_hex ; * 16
 dc.b .OO..
 dc.b O.OO.
 dc.b O..O.
 dc.b OO.O.
 dc.b .OO..
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .OO..
 dc.b ..O..
 dc.b ..O..
 dc.b .OOO.
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b .OO..
 dc.b O..O.
 dc.b ..O..
 dc.b .O...
 dc.b OOOO.
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b OOOO.
 dc.b ..O..
 dc.b .OO..
 dc.b ...O.
 dc.b OOO..
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .OO..
 dc.b O.O..
 dc.b OOOO.
 dc.b ..O..
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b OOOO.
 dc.b O....
 dc.b OOO..
 dc.b ...O.
 dc.b OOO..
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b ..O..
 dc.b .O...
 dc.b OOO..
 dc.b O..O.
 dc.b .OO..
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b OOOO.
 dc.b ...O.
 dc.b ..O..
 dc.b .O...
 dc.b O....
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....
* 24
 dc.b .OO..
 dc.b O..O.
 dc.b .OO..
 dc.b O..O.
 dc.b .OO..
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b .OOO.
 dc.b O..O.
 dc.b .OOO.
 dc.b ...O.
 dc.b ...O.
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b .OO..
 dc.b O..O.
 dc.b OOOO.
 dc.b O..O.
 dc.b O..O.
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b OOO..
 dc.b O..O.
 dc.b OOO..
 dc.b O..O.
 dc.b OOO..
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b .OOO.
 dc.b O....
 dc.b O....
 dc.b O....
 dc.b .OOO.
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b OOO..
 dc.b O..O.
 dc.b O..O.
 dc.b O..O.
 dc.b OOO..
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b OOOO.
 dc.b O....
 dc.b OOO..
 dc.b O....
 dc.b OOOO.
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....

 dc.b OOOO.
 dc.b O....
 dc.b OOO..
 dc.b O....
 dc.b O....
 dc.b .....
 dc.b .....
 dc.b .....
 dc.b .....
* This last one included again for sys_ramt

tb_f1x

        end
