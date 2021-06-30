* Swap tos with nos, duplicate tos or nos and roll three
        xdef    ri_dup,ri_over,ri_roll,ri_swap

* Note: as all these routines are critical to the overall speed of the system,
* none of them (except roll) share any common code.

        section ri_swap

* Swap tos and nos: b, a, ... --> a, b, ...
* d0 -  o- 0 (ccr set)
* d1 -  o- new tos mantissa longword
* d2 -  o- new tos exponent word

ri_swap
        move.w  0+1*6(a6,a1.l),d2
        move.l  2+1*6(a6,a1.l),d1
        move.w  0+0*6(a6,a1.l),0+1*6(a6,a1.l)
        move.l  2+0*6(a6,a1.l),2+1*6(a6,a1.l)
putit
        move.w  d2,0+0*6(a6,a1.l)
        move.l  d1,2+0*6(a6,a1.l)
        moveq   #0,d0
        rts

* Copy nos over tos to becomes additional tos: b, a, ... --> a, b, a, ...
* d0 -  o- 0 (ccr set)

ri_over
        subq.l  #6,a1
        move.w  0+2*6(a6,a1.l),0+0*6(a6,a1.l)
        move.l  2+2*6(a6,a1.l),2+0*6(a6,a1.l)
        moveq   #0,d0
        rts

* Duplicate tos as additional tos: a, ... --> a, a, ...
* d0 -  o- 0 (ccr set)

ri_dup
        subq.l #6,a1
        move.w 0+1*6(a6,a1.l),0+0*6(a6,a1.l)
        move.l 2+1*6(a6,a1.l),2+0*6(a6,a1.l)
        moveq  #0,d0
        rts

* Roll the third entry around to the top: b, c, a, ... --> a, b, c, ...
* d0 -  o- 0 (ccr set)
* d1 -  o- new tos mantissa longword
* d2 -  o- new tos exponent word

ri_roll
        move.w  0+2*6(a6,a1.l),d2
        move.l  2+2*6(a6,a1.l),d1
        move.l  2+1*6(a6,a1.l),2+2*6(a6,a1.l)
        move.l  4+0*6(a6,a1.l),4+1*6(a6,a1.l)
        move.l  0+0*6(a6,a1.l),0+1*6(a6,a1.l)
        bra.s   putit

        end
