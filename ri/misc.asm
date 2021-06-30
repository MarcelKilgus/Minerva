* Miscellaneous arithmetic stack operations
        xdef    ri_halve,ri_k,ri_k_b,ri_n,ri_n_b,ri_one,ri_zero

        xref    ri_renrm

        section ri_misc

ri_halve
        subq.w  #1,0(a6,a1.l)   subtract one from exponent
        bpl.s   okrts
        move.l  2(a6,a1.l),d0   get the mantissa
        asr.l   #1,d0           shift it down
        addq.l  #6,a1           (using ri_zero code)
        bra.s   unnorm          go put it back (now unnormalised, or zero)

* These put constants onto the stack:
* Note that the fact that a5 points to the block being interpreted is crucial
* for ri_n and ri_k. The entry points ri_n_b and ri_k_b can be used as direct
* calls, if the need arises, but note that only d0.b is used.
* Direct calls to ri_zero and ri_one are fine.

ri_one
        move.w  #$801,-6(a6,a1.l)
        moveq   #1,d0           quick one
        ror.l   #2,d0
        bra.s   push

ri_zero
        moveq   #0,d0           quick zero
unnorm
        clr.w   -6(a6,a1.l)
push
        subq.l  #6,a1
put
        move.l  d0,2(a6,a1.l)
okrts
        moveq   #0,d0
        rts

ri_n
        move.b  (a5)+,d0        convenient -128..127
ri_n_b
        moveq   #0,d1
        move.b  d0,d1           set mantissa
        ror.l   #8,d1
        move.w  #$807,d0
        jmp     ri_renrm(pc)    go renormalise (fairly quick)

* These constants are accessed in a strange, but clever fashion. Only the
* mantissa is held here, and the exponent is constructed from part of the
* selecting byte. We limit ourselves to 16 mantissas, each of which will have
* an exponent constructed for it. E.g. we have the mantissa for pi here,
* but we can supply 2*pi, pi/2, pi/4, etc as well. There is a further twist,
* in that the sixteen constants are arranged in order of their typically
* required magnitude. The exponent we build for them is the sum of a base
* exponent and both nibbles of the selector, giving us a fairly wide range of
* possible values, and variations on the same. At present, we have only found
* duplication in the system code of the constants pi and pi/180, the other
* entries are not heavily used at the moment...

ri_k
        move.b  (a5)+,d0        convenient constants
ri_k_b                          ;       exp     d0
        move.w  #$07f0,-6(a6,a1.l)      07f0    xxhl
        or.b    d0,-5(a6,a1.l)          07fl
        lsr.b   #4,d0                           xx0h
        ext.w   d0                              000h
        add.w   d0,-6(a6,a1.l)          done
        lsl.b   #2,d0
        move.l  ktab-8*4(pc,d0.w),d0 mantissa
        bra.s   push

*               mantissa  exp err  what     value         reference
;       dc.l    $???????? ??? +.?? ???????? 0.??????????? $00-$4f
        dc.l    $477d1a89 7fb +.29 pi/180   0.01745329252 $56 ri.pi180
        dc.l    $6f2dec55 7ff -.41 log10(e) 0.4342944819  $69 ri.loge
        dc.l    $430548e1 800 -.29 pi/6     0.5235987756  $79 ri.pi6
ktab
        dc.l    $58b90bfc 800 -.09 ln(2)    0.6931471806  $88 ri.ln2
        dc.l    $6ed9eba1 801 +.38 sqrt(3)  1.732050808   $98 ri.sqrt3
        dc.l    $6487ed51 802 +.07 pi       3.141592654   $a8 ri.pi $a7=ri.pi2
;       dc.l    $???????? ??? +.?? ???????? ?.?????????   $b0-$ff

        end
