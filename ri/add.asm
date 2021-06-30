* Floating point additive routines
        xdef    ri_add,ri_chkov,ri_cmp,ri_doubl,ri_errov
        xdef    ri_fllin,ri_float,ri_flong,ri_renrm,ri_sub

        xref    ri_neg

        include 'dev7_m_inc_err'

* General comments:

* All routines return d0 as zero, except for sub/add/renrm/doubl, which may
* return with err.ov, and of course errov, in which case an appropriate +/-
* huge value is left as result.
* Conditions codes on return are effectively the result of "tst.l d0".

* Most routines destroy d1/d2, with the exception that cmp and errov may be
* relied on to return with d1 containing the the mantissa of the result,
* doubl only sets d1 if it overflows, and neither errov nor doubl touches d2.

* The only routine that affects anything on the stack, other than where the
* result is put, is sub, which will have negated the original top of stack.

* These used to be clever(sic) in doing multibit shifts to normalise the result
* for add/sub. This was pretty stupid, as the run-of-the-mill such operations
* will result in numbers not wildly differring from the one with the larger
* exponent. It is still valid to be clever when called specificly to do
* renormalisations, as these probably do have more bits to tidy up.

        section ri_add

* d0 -  o- 0 or err.ov (ccr set)
* a1 -i o- pointer to arithmetic stack, six added
* d1-d2 destroyed

ri_sub  ;...,a1:b(float),a(float),... ==> ...,-b(float),a1:a-b(float),...
        jsr     ri_neg(pc)      negate b - no error exit
ri_add  ;...,a1:b(float),a(float),... ==> ...,b(float),a1:a+b(float),...
        addq.l  #6,a1           only one return arg
        move.l  2(a6,a1.l),d1   get a mantissa
        move.l  -4(a6,a1.l),d0  get b mantissa
        move.w  0(a6,a1.l),d2   get a exponent
        sub.w   -6(a6,a1.l),d2  subtract b exponent from a exponent (if z, x=0)
        bge.s   expok           if aexp >= bexp, keep it
        neg.w   d2              make shift positive
        add.w   d2,0(a6,a1.l)   change aexp to be bexp
        exg     d0,d1           swap over mantissae
expok
        cmp.w   #32,d2          check downshift
        bgt.s   addput          if too large, just (re)store mantissa
        asr.l   d2,d0           shift down (note: if d2=0, x=0 already)
        subx.l  d2,d2           remember the rounding we're using
        addx.l  d0,d1           add mantissae, and rounding
        bvs.s   addvs           if v is set, we modify rounding and downshift
        move.l  d1,2(a6,a1.l)   store the result, with luck, it's ok now
        add.l   d1,d1           check if number really is already normalised
        bvs.s   rtsok           if so, we can skip out this instant
        move.w  0(a6,a1.l),d0   get current exponent
        beq.s   rtsok           if both a and b were unnormal, all done
        add.l   d2,d1           put back any rounding we may have used, as lsb
        bvc.s   addvc           we can have $80000000+$ffffffff
        addq.l  #1,d1           if so, restore the $80000000, it's better
addvc
        bne.s   addnlp          if not pure zero, go to normalise it
        moveq   #1,d0           force drop out of loop
addnlp
        subq.w  #1,d0
        beq.s   addend          stick at zero exponent, maybe unnormal result
        add.l   d1,d1           try for more normalisation
        bvc.s   addnlp          if there is, keep winding down the exponent
        roxr.l  #1,d1           we overshot normalising, so roll back
addend
        move.w  d0,0(a6,a1.l)   store the exponent
addput
        move.l  d1,2(a6,a1.l)   store the result
rtsok
        moveq   #0,d0
        rts

addvs
        roxr.l  #1,d1           put result back down
* Four possibilities:
* x=0 d2=0  q0.0 fine, we didn't round and lsb was zero anyway
* x=0 d2=-1 q1.1 fine, we have already rounded according to next bit
* x=1 d2=0  q1.0 bad! we still need to round up by one
* x=1 d2=-1 q0.1 fine, no rounding was needed, and we just scrapped it anyway
        bcc.s   chovflw
        addx.l  d2,d1
* Note: if d2=-1, it cancels the x=1, and we're OK
* If d2=0, we round up, but the worst case we could have is $7fffffff+$7ffffffe
* -> (x=0)$fffffffd -> $7ffffffe(x=1) -> $7fffffff, so it never overflows.
chovflw
        move.l  d1,2(a6,a1.l)   store result mantissa

* Double floating point value at top of stack.
* d0 -  o- 0 if no problem, err.ov if exponent out of range 0..$FFF, ccr set
* d1 -  o- unchanged if not overflow, else result mantissa
* a1 -ip - pointer to float to be doubled

ri_doubl
        addq.w  #1,0(a6,a1.l)   add one to exponent

* This does a proper check for overflow.
* d0 -  o- 0 if no problem, err.ov if exponent out of range 0..$FFF, ccr set
* d1 -  o- unchanged if not overflow, else result mantissa
* a1 -ip - RI stack pointer, value replaced by large result on overflow

ri_chkov
        moveq   #-16,d0         mask $f0
        and.b   0(a6,a1.l),d0   is exponent now out of range?
        beq.s   rtsok           nope, that's what we hoped
        ;       we could've allowed min -> max exp like ri_neg, but ...

* This routine replaces the top element of the stack with a maximum value of
* the same sign as was there. It always comes back with err.ov. The usage of
* this, instead of just bombing out on an overflow error, means that callers
* who happen not to check all error returns will likely get away with the odd
* occasion of an overflow error. Also, the top of stack will never get silly.
* d0.l is err.ov, d1.l is the maximum mantissa which has been stored.

ri_errov
        asl     2(a6,a1.l)      was it positive or negative?
        subx.l  d1,d1           x/d0.l = 0/00000000 or 1/ffffffff
        not.l   d1              x/d0.l = 0/ffffffff or 1/00000000
        roxr.l  #1,d1           x/d0.l = 1/7fffffff or 0/80000000
        move.l  d1,2(a6,a1.l)   store the maximum mantissa
        move.w  #$fff,0(a6,a1.l) maximum exponent
        moveq   #err.ov,d0
        rts

* Float a short integer which is on the stack

* d0 -  o- 0 (ccr set)
* a1 -i o- pointer to arithmetic stack, four subtracted
* d1-d2 destroyed

ri_float;...,?(long),a1:a(short),... ==> ...,a1:a(float),...
        move.l  0(a6,a1.l),d1   fetch integer and junk
        move.w  #$80f,d0        set exponent
dropjunk
        clr.w   d1              scrap junk
setshft
        subq.l  #4,a1           space for result
        move.l  d1,d2           duplicate mantissa
        beq.s   minexp          ah! zero mantissa
        asl.l   #8,d2           try eight bit shift
        bvc.s   did8            that worked, so go try 4 using d2 as source
        move.l  d1,d2
        asl.l   #4,d2
        bvc.s   did4            go try two bit shift on d2
try2
        move.l  d1,d2
        asl.l   #2,d2
        bvc.s   did2            go try single bit shift on d2
try1
        move.l  d1,d2
        add.l   d2,d2
        bvc.s   did1            go finish off copying d2 into d1
        bra.s   stack

did8
        subq.w  #8,d0           successful eight bit shift
        move.l  d2,d1
        asl.l   #4,d2
        bvs.s   try2
did4
        subq.w  #4,d0           successful four bit shift
        move.l  d2,d1
        asl.l   #2,d2
        bvs.s   try1
did2
        subq.w  #2,d0           successful two bit shift
        move.l  d2,d1
        add.l   d2,d2
        bvs.s   stack
did1
        subq.w  #1,d0           successful one bit shift
        move.l  d2,d1
stack
        move.w  d0,0(a6,a1.l)   put exponent on
        move.l  d1,2(a6,a1.l)   put mantissa on
        moveq   #0,d0           good return
rtsrnrm
        rts

* Renormalise a value from registers and put it onto the stack

* d0 -i o- exponent in lsw / 0 or err.ov if result overflows (ccr set)
* d1 -i  - mantissa
* a1 -i o- stack pointer, six subtracted
* d2 destroyed

ri_renrm;...,?(float),a1:,... ==> ...,a1:a(float),...
        bsr.s   renrm           nest down to renormalise as ...
        move.b  0(a6,a1.l),d0   ... only here can we end up with duff exponent
        asr.b   #4,d0
        bgt.s   ri_errov
        beq.s   rtsrnrm
        move.w  0(a6,a1.l),d0   underflow, so we have to pick up exponent again
        neg.w   d0              what a tiny number
        asr.l   d0,d1           move mantissa by underflow amount
minexp
        moveq   #0,d0           set exponent to zero
        bra.s   stack

* Float a long integer, input and result on the stack

* d0 -i o- 0 (ccr set)
* a1 -i o- stack pointer, two subtracted
* d1/d2 destroyed

ri_flong;...,?(word),a1:a(long),... ==> ...,a1:a(float),...
        move.l  0(a6,a1.l),d1   fetch long integer
        addq.l  #4,a1           drop it for now

* Float a long integer from a register onto the stack

* d0 -i o- 0 (ccr set)
* d1 -i  - mantissa
* a1 -i o- stack pointer, six subtracted
* d2 destroyed

ri_fllin;...,?(float),a1:,... ==> ...,a1:a(float),...
        move.w  #$81f,d0        set exponent
renrm
        subq.l  #2,a1           make room like an integer
        move.l  d1,d2           take a copy
        ext.l   d2              extend to long
        cmp.l   d1,d2           did that change it?
        bne.s   setshft         yes - go start little shifts
        sub.w   #16,d0          no - knock sixteen of exponent ...
        swap    d1              ... swap single word to msw ...
        bra.s   dropjunk        ... and go on like an integer

* ri_cmp simplifies, speeds up, and makes consistent, floating point compares.
* It expects two fp values on the stack, and leaves only one. This is similar
* to ri_sub, but the value left is arranged to make determination of the
* comparison result very easy.
* In essence, the value left will be zero for identical equality, negative for
* a < b or positive for a > b. The absolute value of the result will be
* approximate the condition abs(a-b) > max(abs(a),abs(b)) / 1e7, i.e. the
* result will be +/-1 if the comparison is pretty definate, +/- a tiny value if
* we have a == b but not a = b, and zero iff a is exactly equal to b (a = b).
* The actual bytes stored are arranged for easy tests as follows:

*       a < b and not a == b    08 00 80 00 00 00
*           a < b and a == b    00 00 80 00 00 00
*                      a = b    00 00 00 00 00 00
*           a > b and a == b    00 01 40 00 00 00
*       a > b and not a == b    08 01 40 00 00 00

* Thus testing the msb of the exponent establishes approximate equality if it
* is zero, and testing the msb of the mantissa is used in all other cases.

* Registers...
* d0 -  o- 0 (ccr set)
* d1 -  o- mantissa of result
* a1 -i o- stack pointer, six subtracted
* d2 destroyed

ri_cmp;...,a1:b(float),a(float),... ==> ...,b(float),a1:sgn(a-b)ish(float),...
        addq.l  #6,a1           set stack ready for exit
        move.w  0(a6,a1.l),d2   get a exponent
        clr.w   0(a6,a1.l)      wipe it out
        move.l  2(a6,a1.l),d0   get a mantissa
        bne.s   anz
* a is zero, therefore we need only consider the sign, and zero-ness of b
        move.l  -4(a6,a1.l),d1  how is b?
        beq.s   ret0            if it's zero, we only need to get out now (0=0)
        bpl.s   msbexp          if it's positive, a < b (0<+ve)
setagb
        addq.b  #1,1(a6,a1.l)   set the "a > b" bit
msbexp
        addq.b  #8,0(a6,a1.l)   set the "not a == b" bit
msbman
        moveq   #2,d1           2
        sub.b   1(a6,a1.l),d1   (1/2) did we set "a > b"?
        ror.l   #2,d1           $40000000/$80000000
setman
        move.l  d1,2(a6,a1.l)   store mantissa
ret0
        moveq   #0,d0
        rts

* Right, a isn't zero, so we'll see what b looks like
anz
        move.l  -4(a6,a1.l),d1  pick up b mantissa
        bne.s   bnz
btozero
        tst.l   d0              if b is 0 direction from a, check a's sign
        bpl.s   setagb          if positive set a > b (big+ve>little+ve,0,-ve)
        bra.s   msbexp          if negative leave it (big-ve<little-ve,0,+ve)

* Neither a or b is zero, so see if a and b differ in sign
bnz
        eor.l   d0,d1           temporarily flip b
        bmi.s   btozero         their sign's differ, go set accordingly
        eor.l   d0,d1           put b back normal

* Now we're getting down to the nitty-gritty bits. Have to look at exponents

        sub.w   -6(a6,a1.l),d2  calculate exp(a) - exp(b)
        bne.s   shuff           not the same, so we haven't got exact equals
        sub.l   d0,d1           are they exactly the same?
        beq.s   setman          yes - that's exact equality finished with
bitgame
        bgt.s   bitlook         if a < b leave that (nb see below why bgt test)
        addq.b  #1,1(a6,a1.l)   set the "a > b" bit
        not.l   d1              now difference is positive
bitlook
        move.l  d1,d2
        lsr.l   #8,d2           are difference bits 31 to 8 all zero?
        bne.s   msbexp          no - then go set not ==
        mulu    #39063,d1       multiply by 1e7/256 (exact is 39062.5)
        asl.l   #8,d1           did any bits get right into the top?
        bvs.s   msbexp          yes - then set not ==
        tst.l   d0
        bpl.s   okbig
        not.l   d0              saves checking for overflow, and is good enuff
okbig
        cmp.l   d0,d1           finally compare them
        bge.s   msbexp          if abs(a-b)*1e7 >= abs(b or a), set not ==
        bra.s   msbman          otherwise, leave ==

shuff
        subq.w  #1,d2           is exp(a) > exp(b) + 1?
        bgt.s   btozero         yes, then set result according to sign
        beq.s   shft            if exp(a) = exp(b) + 1, go do shift
        exg     d0,d1           swap over a and b
        not.l   d0              and invert both
        not.l   d1              which will be good enough for our purposes
        addq.w  #2,d2           is exp(a) < exp(b) - 1?
        bne.s   btozero         yes, once again the sign is the answer
shft
        asr.l   #1,d1           shift down the smaller exponent
        sub.l   d0,d1           how do they compare?
        bra.s   bitgame         nb test up there is bgt, so lost carry is ok

        end
