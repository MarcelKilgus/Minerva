* Negate or abs a normalised number
        xdef    ri_abs,ri_neg

        section ri_nabs

* d0 -  o- zero
* d1 -  o- resulting a mantissa
* a1 -ip - rel a6 offset to fp to be negated

* Note: as a feature of this code, a zero resulting mantissa can only come out
* if the original mantissa was zero. This fact is used by at least ri_mult.

* Special cases must be coped with. The normalised +/-2**n must be handled.
* Also, extreme values need care and unnormalised values are now noticed.

* This routine never gives an error, though it does fudge two cases:

* 1) max negative ($0fff80000000) gives max positive ($0fff7fffffff). 
* 2) min positive ($000040000000) gives unnormalised ($0000c0000000).

* As an improvement, instead of comparing with $c0000000 to just detect
* negation of +2**n, this now does a check for an unnormalised result, which
* will also tend to normalise tiny values.
* Another mod is that zero is not treated specially, but is allowed to find its
* way through the unnormalised route, where it's exponent will be forced zero.
* This routine can be mildly slow if the impossible (sic) happened, and an
* unnormalised mantissa came in with an invalid exponent!

* The code is optimised to handle general values.
* It could be made quicker if zero and minus one were very frequent inputs.

unnorm
        exg     d0,d1           it was unnormalised, so used doubled one
        subq.w  #1,0(a6,a1.l)   and decrement exponent
        bpl.s   norm            no underflow, so we may be able to shift again!
        exg     d0,d1           rats, gotta leave it unnormalised
        clr.w   0(a6,a1.l)      return zero exponent for unnormalised
        bra.s   stack           ok

ovfl
        move.w  0(a6,a1.l),d0   $80000000 overflowed, so get the exponent
        addq.w  #1,d0           increase it
shift
        lsr.l   #1,d1           shift down mantissa ($40000000 or $7fffffff)
        move.w  d0,0(a6,a1.l)   put in the exponent
        lsl.w   #3,d0           has is it overflowed?
        bpl.s   stack           no, go stack mantissa
        moveq   #-2,d1          ah well! go for 31 1's, largest positive value
        move.w  #$0fff,d0       precise maximum exponent
        bra.s   shift           go store them

ri_abs
        tst.b   2(a6,a1.l)      check if already positive
        bpl.s   exit            yes, then we don't touch it
ri_neg
        move.l  2(a6,a1.l),d1   get mantissa
        neg.l   d1              negate it
        bvs.s   ovfl            must have been $80000000
norm
        move.l  d1,d0           take a copy of the result so far
        add.l   d0,d0           is the result now normalised?
        bvc.s   unnorm          no, go see what we can do
stack
        move.l  d1,2(a6,a1.l)   put negated mantissa back on stack
exit
        moveq   #0,d0
        rts

        end
