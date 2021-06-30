* multiplication and division
        xdef    ri_div,ri_mult,ri_rdiv,ri_recip,ri_squar

        xref    ri_dup,ri_errov,ri_one,ri_swap

        section ri_mldv

* Multiplication and division routines:

* On entry:
*  (a6,a1.l) - b exponent/mantissa
* 6(a6,a1.l) - a exponent/mantissa

* On return, b will be totally unchanged, but the result (a*b or a/b) will have
* replaced a and will now be top of the stack (a1 will have had 6 added).

* Square and reciprocal routines:

* On entry:
* 0(a6,a1.l) - a exponent/mantissa

* On return, a copy of a will have appeared at -6(a6,a1.l), but the result
* (a^2 or 1/a) will have replaced a.

* Note that these routine now not only work with unnormalised inputs, but will
* keep accuracy with them. Unnormalised results may be produced, but they may
* be one bit out, as precise rounding is a lot of extra work.

* All routines expect/affect registers as follows:

* d0 -  o- error code: 0=ok or err.ov (ccr set)
* d1 -  o- result mantissa, always
* d2 -  o- result exponent (only if d0=0)
* a1 -i o- always six added in ri_mult/div, unchanged by ri_squar/recip
* a6 -ip - base address for a1
* d3 destroyed

* Low order words of a and/or b were zero, so we can save multiplies

mbl0
        exg     d1,d3           swap over am and bm to make life easier
mjusta
        swap    d1              am(bm): high order mantissa ($8000..$ffff)
        swap    d3              bm(am): high order mantissa ($8000..$ffff)
        mulu    d1,d3           am*bm ($40000000..$fffe0001)
        mulu    d2,d1           am*bl(bm*al) (0..$fffd2002)
        sub.b   d0,d0           set x=0, as we have no clever carry to do
        bra.s   mbasic          can now go back to form basic mantissa

mal0
        move.w  d3,d2           bl: low order mantissa ($0..$fffe)
        bne.s   mjusta          can only save two multiplies if bl non-zero
        move.w  0(a6,a1.l),d2   get basic exponent
        swap    d1              am: high order mantissa ($8000..$ffff)
        swap    d3              bm: high order mantissa ($8000..$ffff)
        mulu    d3,d1           am*bm ($40000000..$fffe0001)
        bmi.s   mround          skip if we're unnormalised at the moment
        bra.s   result          already normalised - go finish exponent

ri_squar
        jsr     ri_dup(pc)      duplicate tos, then multiply
ri_mult
        add.l   #6,a1           drop b
        move.w  -6(a6,a1.l),d2  get b exponent
        sub.w   #$17ff,d2       adjust exponent
        move.l  2(a6,a1.l),d1   get a mantissa
        bgt.s   manorm          if it's positive, we're ok to go on
        beq.s   mzera           if zero, leave pure zero result
        neg.l   d1
        bvs.s   maset           if msb set, all ok
manorm
        subq.w  #1,d2           reduce exponent
        add.l   d1,d1           shuffle up a (to force msb always 1)
        bvc.s   manorm          insist on msb 1, even if exponent goes -ve
maset

        move.l  -4(a6,a1.l),d3  get b mantissa
        bgt.s   mbnorm
mzera
        beq.s   zero            if zero, make zero result
        not.b   2(a6,a1.l)      invert negative flag
        neg.l   d3
        bvs.s   mbset
mbnorm
        subq.w  #1,d2           reduce exponent
        add.l   d3,d3           shift along b (so msb is always 1)
        bvc.s   mbnorm          insist on msb 1, even if exponent goes -ve
mbset

        add.w   d2,0(a6,a1.l)   add modified b exponent into a exponent

        move.w  d1,d2           al: low order mantissa (0..$fffe)
        beq.s   mal0            can save two or three multiplies if al is zero
        move.w  d3,d0           bl: low order mantissa ($0..$fffe)
        beq.s   mbl0            can save two multiplies bl is zero
        swap    d1              am: high order mantissa ($8000..$ffff)

        mulu    d2,d0           al*bl (1..$fffc0001)
        move.w  d3,d0           we don't need al*bl lsw, but we want bl again
        swap    d3              bm: high order mantissa ($8000..$ffff)
        mulu    d3,d2           al*bm (0..$fffd2002)
        mulu    d1,d3           am*bm ($40000000..$fffe0001)
        mulu    d0,d1           am*bl (0..$fffd2002)

        clr.w   d0              finished with bl, want zero for msw
        swap    d0              wriggle top 16 down (0..$0000fffc)
        add.l   d0,d1           cannot overflow! ($0..$fffdfffe)
        add.l   d2,d1           this may (0..$xfffb0000)

mbasic
        move.w  0(a6,a1.l),d2   get basic exponent
        move.w  d1,d0           save bit 15 of sum, in case normalised mantissa
        clr.w   d1              clear bottom
        addx.w  d1,d1           put extend bit in there
        swap    d1              ready for final add (0..$0001fffb)
        add.l   d3,d1           basic mantissa ($40000000..$fffffffb)
        bmi.s   mround          skip if we're unnormalised at the moment
        add.w   d0,d0           get saved rounding bit into extend
        moveq   #0,d0
        addx.l  d0,d1           add it into the mantissa ($40000001..$80000000)
        bvc.s   result          provided it's not $80000000 we're ok
mround
        addq.w  #1,d2           add one to basic exponent
dround
        addq.l  #1,d1           round up ($80000001..$fffffffc)
down
        lsr.l   #1,d1           normalised now ($40000000..$7ffffffe)
result
        tst.b   2(a6,a1.l)      do we want a negative result?
        bpl.s   sortit          no, leave it at that
        neg.l   d1
        move.l  d1,d0
        add.l   d0,d0
        bvs.s   sortit          tacky, but we mustn't return $c0... for -1
        move.l  d0,d1
        subq.w  #1,d2
sortit
        add.w   #$1000,d2       final exponent, if all is ok
        bcs.s   stack           finished up in range 0..$fff, so it's fine
errov
        bpl.l   ri_errov        finished up in range $1000..$7fff, overflow
        neg.w   d2              ok, so how far did it underflow?
        asr.l   d2,d1           adjust mantissa, but correct rounding is tough!
        asr.w   #5,d2           was shift count more than 31?
        beq.s   stack           no - that's an ok unnormalised mantissa
zero
        moveq   #0,d2           clear exponent
        moveq   #0,d1           clear mantissa
stack
        move.w  d2,0(a6,a1.l)   store exponent
        move.l  d1,2(a6,a1.l)   store mantissa
        moveq   #0,d0           good exit
        rts

fastdiv
        swap    d3              divisor to lsw
        cmp.w   #-$8000,d3      even better if the divisor is a power of two!
        bne.s   usediv
        move.l  d0,d1           did we adjust the value down?
        bpl.s   result          yes, go stack it as it is
        addq.w  #1,d2           put exponent up
dshift
        bra.s   down            go shift result down one

usediv
        divu    d3,d0           main divide
        move.w  d0,d1           save msw of result (always >= $8000)
        swap    d1
        clr.w   d0              clear the lsw
        divu    d3,d0           get lsw of result
        move.w  d0,d1           put in result
        bra.s   dround          go round and shift result down one

ri_recip
        jsr     ri_one(pc)      put 1.0 on tos
ri_rdiv
        jsr     ri_swap(pc)     divide tos by nos
ri_div
        addq.l  #6,a1           move past b
        move.w  0(a6,a1.l),d2   get a exponent
        move.l  2(a6,a1.l),d0   get a mantissa
        sub.w   #$800,d2        adjust exponent
        sub.w   -6(a6,a1.l),d2  subtract b exponent
        move.l  -4(a6,a1.l),d3  get b mantissa
        bgt.s   dbnorm
        beq.s   errov           zero divide
        not.b   2(a6,a1.l)      flip input a sign for result sign
        neg.l   d3              negate b mantissa
        bvs.s   dbset           if $80..., we're in luck!
dbnorm
        addq.w  #1,d2
        add.l   d3,d3           make sure b has msb set, and lsb 0
        bpl.s   dbnorm          shouldn't happen, unless b was unnormalised
dbset
        tst.l   d0              check a mantissa
        bgt.s   danorm
        beq.s   zero            make certain all is tidy for 0/b, b<>0
        neg.l   d0
        bvs.s   daset           once again, in luck if $80...
danorm
        subq.w  #1,d2
        add.l   d0,d0           make sure a has msb set and lsb zero
        bpl.s   danorm          shouldn't happen, unless a was unnormalised
daset
        cmp.l   d3,d0           is dividend less than divisor?
        bcs.s   divok           yes - that's just how we like it
        addq.w  #1,d2           otherwise, increment the exponent
        lsr.l   #1,d0           and put back the normalised dividend
divok

        tst.w   d3              interesting... if lsw of divisor is zero...
        beq.s   fastdiv         ... we can use the machine's divide!
        lsr.l   #1,d3           we guarantee that the top bit will be clear
        sub.l   d3,d0           do first subtraction
        moveq   #-2,d1          31 more one bits to shift out
dloop
        add.l   d0,d0           shift next dividend up one
        sub.l   d3,d0           take divisor away from dividend
        bcc.s   doksub          good one
        add.l   d3,d0           put it back (c/x will be set again)
doksub
        addx.l  d1,d1           roll in this bit
        bmi.s   dloop           carry on while our one bits are coming out
        neg.l   d1              all the bits were inverted, and this rounds it
        bra.s   dshift          go shift result down one

        end
