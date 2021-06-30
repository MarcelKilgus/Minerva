* vect user vectors
        nolist

addr setnum $c0

vec macro
i setnum 0
loop maclab
i setnum [i]+3
 ifstr [.parm([i]-2)] = k goto nxt
[.parm([i]-1)].[.parm([i])] equ [addr]
nxt maclab
addr setnum [addr]+2
 ifnum [i] < [.nparms] goto loop
 endm

* utility vectors - words

s vec.w 0 mm alchp 0 mm rechp 0 ut windw 0 ut con   ;  $c0 -  $c6
s vec.w 0 ut scr   0 ut err0  0 ut err   0 ut mint  ;  $c8 -  $ce
s vec.w 0 ut mtext 0 ut link  0 ut unlnk k .. 0     ;  $d0 -  $d6
s vec.w 0 mm alloc 0 mm lnkfr 0 io qset  0 io qtest ;  $d8 -  $de
s vec.w 0 io qin   0 io qout  0 io qeof  0 ut cstr  ;  $e0 -  $e6
s vec.w 0 io serq  0 io serio 0 cn date  0 cn day   ;  $e8 -  $ee
s vec.w 0 cn ftod  0 cn itod  0 cn itobb 0 cn itobw ;  $f0 -  $f6
s vec.w 0 cn itobl 0 cn itohb 0 cn itohw 0 cn itohl ;  $f8 -  $fe
s vec.w 0 cn dtof  0 cn dtoi  0 cn btoib 0 cn btoiw ; $100 - $106
s vec.w 0 cn btoil 0 cn htoib 0 cn htoiw 0 cn htoil ; $108 - $10e
s vec.w 0 bp init  0 ca gtint 0 ca gtfp  0 ca gtstr ; $110 - $116
s vec.w 0 ca gtlin 0 bv chrix 0 ri exec  0 ri execb ; $118 - $11e
s vec.w 0 bp let   0 io name  4 md read  4 md write ; $120 - $126
s vec.w 4 md verin 4 md sectr 4 pa graph 4 pa table ; $128 - $12e
s vec.w 4 pa expr  4 pa strip 4 pa mist  4 ed nwlin ; $130 - $136
s vec.w 4 ed liste 4 pa ini   4 ut istr  4 go new   ; $138 - $13e
s vec.w 4 bp chan  4 bp chand 4 bp chnid 4 bp chnew ; $140 - $146
s vec.w 4 bp fname 4 ca cnvrt 4 ca opexe 4 ca eval  ; $148 - $14e
s vec.w 4 ip kbrd  4 ip kbend 4 sb start k .. -1    ; $150 - $156
s vec.w 4 mm move  4 mm mrtoa 4 mm mator 4 mm mrtor ; $158 - $15e
s vec.w 4 ss wser  4 ss rser  4 md selec 4 md desel ; $160 - $166
s vec.w 4 mm clear 4 mm clrr  4 io qsetl k .. -1    ; $168 - $16e
s vec.w 4 ii raw   4 ii drive k .. -1    k .. -1    ; $170 - $176

        list
