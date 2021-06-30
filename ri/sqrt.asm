* Square root and mod (2- or n-dimension)
        xdef    ri_mod,ri_sqrt,ri_sss

        xref    ri_abs,ri_add,ri_chkov,ri_errov,ri_squar,ri_swap,ri_zero

        section ri_sqrt

* Square root of sum of squares of tos and nos: tos, nos, ... --> result, ...
ri_mod
        moveq   #2,d3

* Square root of sum of squares of all parameters: list, ... --> result, ...
* d0 -  o- 0 (ccr set)
* d3 -i  - count of fp values to operate on (0..32767!)
* a1 -i o- has (d3-1)*6 added
* d1-d2 destroyed

* Magic number of 17 is the exponent difference where a parameter becomes too
* small to affect the result. If there were a great number of such small
* parameters, this might not be quite right, but short of doing a sort to
* operate on the smaller values first, I don't see that it's too bad. Keeping
* to the minimum value is a moderately good idea, as this code will be able to
* skip parameters more often, saving calculation time where values that are
* "approximately" zero crop up. However, as we aren't being too pedantic about
* this, we'll use the value 20.

reglist reg     d4-d5/a0
ri_sss
        movem.l reglist,-(sp)
        move.w  d3,d4
        moveq   #20,d5
        bra.s   maxent

maxlp
        addq.l  #6,a1
        cmp.w   -6(a6,a1.l),d5
        bgt.s   maxent
        move.w  -6(a6,a1.l),d5
maxent
        dbra    d4,maxlp
        sub.w   #20,d5          d5 is zero or positive
        move.l  a1,a0
        bra.s   upent

uplp
        subq.l  #6,a0
        tst.l   2(a6,a0.l)      skip any zero values, regardless
        beq.s   upent
        cmp.w   0(a6,a0.l),d5   only use values within 17 of max exponent
        bgt.s   upent
        addq.w  #1,d4           count the ones we will use
        subq.l  #6,a1
        move.w  0(a6,a0.l),0(a6,a1.l) pack them all up the top of the stack
        move.l  2(a6,a0.l),2(a6,a1.l)
upent
        dbra    d3,uplp
        tst.w   d4              check how many values we've finished up with
        bgt.s   dosss           more than one, actually do something!
        movem.l (sp)+,reglist   reload regs
        beq.l   ri_abs          abs if we have just one (significant) parameter
        jmp     ri_zero(pc)     nothing (non-zero), so push a true zero

modsq
        sub.w   d5,0(a6,a1.l)
        jmp     ri_squar(pc)

dosss
        sub.w   #$800,d5        exponents will be $800+(0..17) for square
        bsr.s   modsq
addlp
        jsr     ri_swap(pc)
        bsr.s   modsq
        jsr     ri_add(pc)
        subq.w  #1,d4
        bne.s   addlp
        bsr.s   ri_sqrt
        add.w   d5,0(a6,a1.l)   readjust final exponent
        movem.l (sp)+,reglist
        jmp     ri_chkov(pc)    finally check that we haven't overflowed

* Square root: a, ... --> SQRT(a), ...

* d0 -  o- error code (ccr set)
* a1 -i o- ri stack pointer
* a6 -ip - base address
* d1-d2 destroyed

ri_sqrt
        move.l  2(a6,a1.l),d0   get mantissa
        beq.s   rts0            if we actually have sqrt(0), then all is OK
        bmi.l   ri_errov        no messing if it's not strictly positive
        move.w  0(a6,a1.l),d2   get exponent
        add.w   #$801,d2        adjust exponent prior to halving it
unnlp
        add.l   d0,d0
        dbmi    d2,unnlp        roll up to ensure msb is set
        lsr.w   #1,d2           halve exponent
        bcs.s   expodd
        lsr.l   #1,d0           if exponent was even, halve the mantissa
expodd
        move.w  d2,0(a6,a1.l)   store the final exponent (always in range!)
        moveq   #1,d1           clear result mantissa
        ror.l   #32-30,d1       except for initial bit 30
        sub.l   d1,d0           our first subtraction is always OK
        moveq   #28,d2          next test bit is two down, i.e. bit 28
loop
        bset    d2,d1           set the bit we want to compare for
        cmp.l   d0,d1           check test value against remainder
        bhi.s   nosub           if it is greater, we don't want this bit set
        sub.l   d1,d0           subtract from remainder
        addq.b  #1,d2
        bset    d2,d1           set the next bit up
        subq.b  #1,d2
nosub
        bclr    d2,d1           clear the test bit
        add.l   d0,d0           double up the remainder
        dbra    d2,loop
        cmp.l   d0,d1           check for final bit
        bcc.s   nolsb           (bearing in mind bit -1(!) should be set)
        addq.b  #1,d1           this is a proper lsb
        sub.l   d1,d0           over-subtract
        add.b   d2,d2           x=1 corrects the over-subtraction above
nolsb
        addx.l  d0,d0           double up leftover stuff
        cmp.l   d0,d1           final check for rounding
        bcc.s   nornd           (bit -2(!!) should be set)
        addq.l  #1,d1           rounding here never pushes up the exponent!
nornd
        move.l  d1,2(a6,a1.l)
        moveq   #0,d0
rts0
        rts

        end
