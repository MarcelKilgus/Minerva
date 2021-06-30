* Raise fp to fp or integer power
        xdef    ri_power,ri_powfp

        xref    ri_exp,ri_errov,ri_ln,ri_mult,ri_one,ri_recip,ri_squar,ri_swap

        section ri_power

* Raise a to power b... check if b is integer, and do faster code if so

* On entry
* 0(a1) - b exponent/mantissa
* 6(a1) - a exponent/mantissa

* On exit, both a and b will have been removed from the stack and replaced
* by the result (a**b) (a to the power of b)

* d0 -  o- error code
* a1 -i o- arithmetic stack pointer, 6 added
* d1-d3 destroyed

ri_powfp
        move.l  2(a6,a1.l),d1   get mantissa of b
        move.w  0(a6,a1.l),d2   get exponent of b
        beq.s   fp_to_un        it's zero
        move.w  #$80f,d0        set up shift to make integer
        sub.w   d2,d0
        blt.s   fp_to_fp        too big (should we abs(a)? power is even?)
        cmp.w   #$f,d0
        bgt.s   fp_to_fp        too small
        tst.w   d1
        bne.s   fp_to_fp        bottom end has some fractional bits
        asr.l   d0,d1           shift it down
        tst.w   d1
        bne.s   fp_to_fp        bottom bit now has some fractional bits
swap_i
        swap    d1              get integer in bottom end
fp_to_i
        addq.l  #4,a1           remove fp from stack
        move.w  d1,0(a6,a1.l)   put integer on and do fp to integer
* Drop into ri_power

* On entry
*  (a1) - b signed integer, even including -32768!
* 2(a1) - a exponent
* 4(a1) - a mantissa

* On exit, both a and b will have been removed from the stack and replaced
* by the result (a**b) (a to the power of b)

* Hmmm.... there is a slightly better way of doing this, by examining the
* required power in more detail. The first power that can be improved upon is
* fifteen. This routine does a**15 as "a * a**2 * a**4 * a**8", which costs six
* multiplies. Doing it as (a * a**4)**3 only takes five, and is more accurate
* as well! The next cases that get worse are 63 (10 versus 8 multiplies), 255
* (14 versus 10) and 4095 (22 versus 15). On average, up to the power of 4095,
* the current algorithm requires about 18% more multiplies than optimal.
* To the absolute top (32767) the average comes out at 22.37%.
* Unfortunately, a simpler algorithm than the one below for finding the optimal
* method escapes me at the moment, except that it's certainly not just
* factorising the power. E.g. 33 takes just six multiplies here, whereas done
* as 3*11 it takes eight!
* The optimal method can be done using the algorithm below, but one should
* notice that it will requires additional stack space.

* def fn f(b):loc k,i,l,t
*  if b<2:ret 0
*  if b&&1=0:c=1:ret f(b/2)+1
*  k=f(b-1)+1:t=2
*  for i=3to sqrt(b)step 2
*   if int(b/i)*i=i:l=f(b/i)+f(b):if l<=k:t=i:k=l
*   end for i:c=t:ret k:end def

* def fn p(a,b) 
*  if b=1:ret a
*  d=f(b)
*  if c=1:d=p(a,b/2):ret d*d
*  if c=2:d=p(a,(b-1)/2):ret d*d*a
*  ret p(p(a,b/i),i):end def

* def fn power(a,b):loc c,d
*  if b>0:ret p(a,b)
*  if b<0:ret p(1/a,-b)
*  ret 1:end def

* So it goes...

* d0 -  o- error code
* a1 -i o- arithmetic stack pointer, 2 added
* d1-d3 destroyed

reglist reg     d4-d6

ri_power
        movem.l reglist,-(sp)
        moveq   #0,d0           we get straight out if b = 0 or 1
        moveq   #0,d6           clear flag in msb shows no partial result yet
        addq.l  #2,a1           adjust stack
        move.w  -2(a6,a1.l),d6  take initial b off the stack
        bgt.s   shift           if b is positive, ok
        bne.s   invert          if strictly negative, do (1/a)^(-b)
        tst.l   2(a6,a1.l)      are we trying to do 0^0?
        beq.s   invert          yes, force it to give an error
        addq.l  #6,a1           drop a
        jsr     ri_one(pc)      put answer, a^0 = 1.0 if a<>0
        bra.s   exit            that's all done

zapit
        moveq   #-1,d1          force error for -ve^fp
zero_pow
        addq.l  #6,a1           drop power
        tst.l   d1              was it raise to positive power?
        bgt.s   rts0            0^+ve is finished, 0^0 and 0^-ve are no good
        jmp     ri_errov(pc)

fp_to_un
        tst.l   d1              check in case b is unnormal
        beq.s   fp_to_i         nope, go do a^0
fp_to_fp
        move.l  2+6(a6,a1.l),d0 are we doing 0 ^ b?
        beq.s   zero_pow        yes, go check sign of power
        jsr     ri_swap(pc)     save power
        jsr     ri_ln(pc)       log a
        bne.s   zapit           complains if trying to log zero or negative
        pea     ri_exp(pc)      (note: huge negative power is fine!)
mult
        jmp     ri_mult(pc)

invert
        jsr     ri_recip(pc)    take the reciprocal (force error if 0^0 now!)
        bne.s   exit            error on invert, leave it and get out
        neg.w   d6              negate power
shift
        lsr.w   #1,d6           get bottom-most bit of power
        bcc.s   square          0 there, so no multiply
        move.w  0(a6,a1.l),d5   save current a exp
        move.l  2(a6,a1.l),d4   save current a mantissa
        bset    #31,d6          have we had a partial result yet?
        beq.s   putpart         no, effectively just dup
        bsr.s   mult            yes, r = a * r
putpart
        subq.l  #6,a1
        bne.s   qdrop           overflowed?
        move.l  d4,2(a6,a1.l)   replace a on stack
        move.w  d5,0(a6,a1.l)
        tst.w   d6
square
        beq.s   qdrop           have we done all the bits of b?
        jsr     ri_squar(pc)    and square current a
        beq.s   shift           repeat if no error
qdrop
        tst.l   d6              did we just have b = 2**n?
        bpl.s   exit            yes, then answer is already at top of stack
drop
        addq.l  #6,a1           reposition stack pointer
exit
        movem.l (sp)+,reglist   restore external data
rts0
        tst.l   d0
        rts

        end
