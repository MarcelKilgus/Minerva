* Evaluates the trig and log functions
        xdef    ri_acos,ri_acot,ri_arg,ri_asin,ri_atan,ri_cos,ri_cot,ri_exp
        xdef    ri_ln,ri_log10,ri_sin,ri_tan

        xref    ri_abs,ri_add,ri_div,ri_dup,ri_errov,ri_fllin,ri_float
        xref    ri_flong,ri_k_b,ri_lint,ri_mult,ri_neg,ri_nlint,ri_one
        xref    ri_rdiv,ri_renrm,ri_sqrt,ri_squar,ri_sub,ri_swap,ri_zero

        include 'dev7_m_inc_ri'

        section ri_trig

* All entry points expect/affect registers as follows:

* d0 -  o- error code
* a1 -i o- arithmetic stack
* a6 -ip - base address
* d1-d3 destroyed

reglist reg     d4-d7/a4

* Evaluates one or two polynomials

* Treating special cases, e.g. zero argument or coefficient, is not done here,
* as it is better done by putting optimisations in ri_add, etc.

* d4 -  o- exponent word of input tos
* d5 -  o- mantissa longword of input tos
* a1 -i o- arithmetic stack, x -> f(x) or f2(x),f1(x)
* a4 -i o- top of poly coeffs data / start of same
* d0-d3/d6 destroyed

poly
        move.w  0(a6,a1.l),d4   fetch exponent
        move.l  2(a6,a1.l),d5   fetch mantissa
poly1
        move.w  -(a4),d6        find order of polynomial
        move.l  -(a4),2(a6,a1.l) put first coefficient on stack
        move.w  -(a4),0(a6,a1.l)
polylp
        subq.l  #6,a1
        move.l  d5,2(a6,a1.l)   put argument back on stack and multiply
        move.w  d4,0(a6,a1.l)
        jsr     ri_mult(pc)
        subq.l  #6,a1
        move.l  -(a4),2(a6,a1.l) add next coefficient
        move.w  -(a4),0(a6,a1.l)
        jsr     ri_add(pc)
        subq.w  #1,d6
        bgt.s   polylp
rts0
        rts

poly2
        bsr.s   poly            evaluate first polynomial
        subq.l  #6,a1
        bra.s   poly1           evaluate next polynomial using same arg

ri_sin
        movem.l reglist,-(sp)   save data registers
        moveq   #0,d7           set sine flag for argument reduction
        bra.s   sin_cos

ri_cos
        movem.l reglist,-(sp)   save data registers
        jsr     ri_abs(pc)      cosine x = cosine -x
        moveq   #-1,d7          set cosine flag for argument reduction
sin_cos
        bsr.s   argrp           reduce argument by increments of pi
        bne.l   putzero         if huge (+/-), just return zero
        bsr.l   dup3_m          duplicate reduced argument and square
        bsr.s   poly            p(x**2)
        bsr.l   m_a             evaluate p(x**2)*x+x
        lsr.b   #1,d7           check quadrant
        bcc.s   exit0
        jsr     ri_neg(pc)      negate odd ones
exit0
        bra.l   exit

argrp
        lea     sin_tab,a4      polynomial tables

* d0 -  o- error if non-zero
* d7 -i o- 0 normal, -1 for cos / integer reducer
* a1 -ip - arithmetic stack (uses 8 bytes extra)
* a4 -i o- pointer to end of reducer table (if ok, moved to start of table)
* d1-d5 destroyed

argrd
        move.w  -(a4),d0        this is non-zero, so will register as an error
        cmp.w   0(a6,a1.l),d0   is this too huge?
        bcs.s   rts0            yes - get out now
        jsr     ri_dup(pc)      duplicate top of stack
        bsr.s   nxt_mult        multiply by reducer

        tst.b   d7              check for cos
        bne.s   sym_red
        jsr     ri_nlint(pc)    nearest integer for normal
        move.w  d1,d7           save segment number
        jsr     ri_flong(pc)    then float it
        bra.s   reduce

sym_red
        jsr     ri_lint(pc)     cos truncates
        addq.l  #4,a1
        add.w   d1,d7           save segment number for cos
        add.l   d1,d1           to add a half: double,
        addq.l  #1,d1           add one,
        jsr     ri_fllin(pc)    float and
        subq.w  #1,0(a6,a1.l)   halve it
reduce
        move.w  0(a6,a1.l),d4   save floated range reducer
        move.l  2(a6,a1.l),d5
        bsr.s   mult_sub        subtract exact binary near reducer*n
        subq.l  #6,a1
        move.l  d5,2(a6,a1.l)   restore reducer
        move.w  d4,0(a6,a1.l)   subtract corrector*n
mult_sub
        pea     ri_sub(pc)
nxt_mult
        subq.l  #6,a1
        move.l  -(a4),2(a6,a1.l) fetch next number
        move.w  -(a4),0(a6,a1.l)
        jmp     ri_mult(pc)

* Tangent and cotangent

ri_tan
        movem.l reglist,-(sp)   save data registers
        moveq   #0,d6           tan is tan
        bra.s   tan_cot

ri_cot
        movem.l reglist,-(sp)   save data registers
        moveq   #-1,d6          cot is 1/tan
        jsr     ri_neg(pc)      (but 1/tan negates)
tan_cot
        clr.w   d7
        addq.w  #1,0(a6,a1.l)   multiply argument by 2
        bsr.s   argrp           reduces original arg by increments of pi/2
        bne.l   putzero         if very large, just say answer is zero
        subq.w  #1,0(a6,a1.l)   divide argument back down
        eor.b   d6,d7           if cot then swap quadrants
        bsr.s   dup3_m          duplicate reduced argument and square
        lea     tan_tab,a4      evaluate p(x**2)
        bsr.l   poly2           and q(x**2)
        addq.l  #6,a1           leave q(x**2) where it is
        bsr.s   m_a             evaluate p(x**2)*x+x
        subq.l  #6,a1
        move.l  -10(a6,a1.l),2(a6,a1.l) move q(x**2) up
        move.w  -12(a6,a1.l),0(a6,a1.l)
        lsr.b   #1,d7           check quadrant
        bcc.s   tc_div
        jsr     ri_swap(pc)     really -q/p
        jsr     ri_neg(pc)
tc_div
        jsr     ri_div(pc)      find p/q
exit
        movem.l (sp)+,reglist
        tst.l   d0
        bne.l   ri_errov (pc)   n.b. this is external
rts1
        rts

dup3_m
        jsr     ri_dup(pc)      stack => x,x
dup2_m
        jsr     ri_dup(pc)      stack => x,x,x
        jmp     ri_squar(pc)    stack => x,x,x^2

m_a
        jsr     ri_mult(pc)     p*next to top
        jmp     ri_add(pc)      p*next to top+next but one

ri_acos
        bsr.s   side2           got x, want y for arctan2
        bne.s   rts1            can't have arg > 1
        jsr     ri_swap(pc)     put 'em the right way round
        bra.s   ri_arg          go do it

ri_asin
        bsr.s   side2           got y, want x for arctan2
        bne.s   rts1            can't have arg > 1
        bra.s   ri_arg          go do it

side2
        bsr.s   dup2_m          stack => y,y**2
        bne.s   rts1            mustn't have overflow!
        bsr.s   put_1_s         stack => y,1,y**2
        pea     ri_sqrt(pc)     stack => y,sqrt(1-y**2)
        jmp     ri_sub(pc)

ri_acot
        pea     ri_arg
put_1_s
        pea     ri_swap(pc)     return via swap
put_1
        jmp     ri_one(pc)

ri_atan
        bsr.s   put_1
ri_arg  ; tos = x, nos = y 
        movem.l reglist,-(sp)
        sf      d7              clear flag byte
        tst.b   6+2(a6,a1.l)    is y coord negative?
        bpl.s   t2_chkx         no, skip negate
        addq.b  #2,d7           set flag bit
        addq.l  #6,a1
        jsr     ri_neg(pc)      force positive y coord (ri_neg leaves x alone!)
        subq.l  #6,a1
t2_chkx
        move.l  2(a6,a1.l),d1   check for negative x coordinate
        bpl.s   t2_chkg
        addq.b  #4,d7           set flag bit
        jsr     ri_neg(pc)
t2_chkg
        move.w  0(a6,a1.l),d0   get x coord exponent
        cmp.w   6(a6,a1.l),d0   compare exponents
        bcs.s   t2_swap         if x << y we swap
        bne.s   t2_div          if x >> y we're ready to divide
        cmp.l   2+6(a6,a1.l),d1 compare mantissas
        bcs.s   t2_swap         if x < y, so swap first
        bne.s   t2_div          if x > y, go do divide
        tst.l   d1              are we being told to do arctan2(0,0)?
        beq.l   tc_div          if so, perform a divide to force the error
t2_swap
        jsr     ri_swap(pc)     swap x <--> y, so we now have nos <= tos
        addq.b  #8,d7           remember we did it (not r = pi/2 - r)
t2_div
        bsr.s   div             now we have a nice 0..1 to arctan(x)
        cmp.w   #$7ff,0(a6,a1.l)
        bcs.s   atn_eval        if t < .25, ok
        bne.s   atn_pi6         if t >= .5, must reduce
        cmp.l   #$4498517a,2(a6,a1.l) compare to tan(pi/12) = 2 - sqrt(3)
        ble.s   atn_eval        if it's not bigger than that, we're ok
atn_pi6         ; arctan(x) = pi/6 + arctan((sqrt(3)*x-1)/(x+sqrt(3))
        jsr     ri_dup(pc)      x,x
        bsr.s   sqrt3           x,x,sqrt(3)
        bsr.s   mult0           x,sqrt(3)*x
        jsr     ri_one(pc)      x,sqrt(3)*x,1
        jsr     ri_sub(pc)      x,sqrt(3)*x-1
        jsr     ri_swap(pc)     sqrt(3)*x-1,x
        bsr.s   sqrt3           sqrt(3)*x-1,x,sqrt(3)
        jsr     ri_add(pc)      sqrt(3)*x-1,x+sqrt(3)
        bsr.s   div             (sqrt(3)*x-1)/(x+sqrt(3))
        addq.b  #1,d7           set r = r + pi/6 flag
        ; note. we now have a range -pi/12..pi/12 left to do. 

atn_eval
        bsr.l   dup3_m          stack => f,f,f*f
        lea     atn_tab,a4      load address of arctan table
        bsr.s   p2div           evaluate both polynomials and divide them
        bsr.l   m_a             form result
        lsr.b   #1,d7           check whether to add pi/6
        bcc.s   chk_aneg
        moveq   #ri.pi6,d0
        bsr.s   k_b             put pi/6 on stack
        jsr     ri_add(pc)      add it
chk_aneg
        moveq   #%01101001,d1
        btst    d7,d1           check whether to negate result (odd octant)
        bne.s   chk_ppi         if tos<0 eor nos<0 eor swapped = 1, no negate
        jsr     ri_neg(pc)
chk_ppi
        subq.b  #2,d7           is that all (-pi/4 to +pi/4)
        bmi.s   exit2           yes, get out
        moveq   #ri.pi,d0
        subq.b  #2,d7           do we need pi? (-pi..-3pi/4 & 3pi/4..-pi)
        spl     d1
        add.b   d1,d0           halve pi to pi/2 usually
        bsr.s   k_b
        lsr.b   #1,d7           do we want to negate it?
        bcc.s   add_pi_k        nope, go add the constant
        neg.l   2(a6,a1.l)
add_pi_k
        jsr     ri_add(pc)
exit2
        bra.l   exit

p2div
        bsr.l   poly2           evaluate both polynomials, and then
div
        jmp     ri_div(pc)      divide

sqrt3
        moveq   #ri.sqrt3,d0
k_b
        jmp     ri_k_b(pc)

ri_log10
        bsr.s   ri_ln           evaluate natural log
        bne.s   rts2
        moveq   #ri.loge,d0     put log10(e) on stack
        jsr     ri_k_b(pc)
mult0
        jmp     ri_mult(pc)     multiply

rts2
        rts

ri_ln
        movem.l reglist,-(sp)
        move.w  #$800,d0        prepare to float (and d0<>0)
        move.l  2(a6,a1.l),d1   pick up mantissa
        ble.s   exit2           negative log?
        move.w  0(a6,a1.l),d7   pick up exponent
        sub.w   d0,d7           get rid of offset

* Now we have the problem of putting the numerator in d0,d1 and the denominator
* in d5 (always between .5 and 1)
 
        moveq   #2,d2           ready to add 1
        cmp.l   #$5a82799a,d1   check for > sqrt(1/2)
        bgt.s   note_10
        subq.w  #1,d7           reduce exponent
        moveq   #1,d2           change to .5
note_10
        move.l  d1,d5
        ror.l   #2,d2           1 (.5)
        sub.l   d2,d1           subtract 1 (.5) from numerator
        add.l   d2,d5           add .5 (.25) to denominator
        lsr.l   #1,d5           sort out denom
        move.w  d0,0(a6,a1.l)
        move.l  d5,2(a6,a1.l)   put denominator on stack
        jsr     ri_renrm(pc)    and renormalise numerator and put on stack
        jsr     ri_rdiv(pc)     reversed divide
        bsr.l   dup3_m          set up stack for poly evaluation (z,z,w)
        jsr     ri_dup(pc)      z,z,w,w
        lea     log_tab,a4      use coefficients for log
        bsr.s   p2div           eval polynomials (z,z,w,a(w),b(w)) and divide
        bsr.s   mult0           multiply to form z,z,r(w)
        bsr.s   m_a1            form final reduced result

* Now add the exponent

        subq.l  #2,a1
        move.w  d7,0(a6,a1.l)   float it on stack
        jsr     ri_float(pc)
        moveq   #ri.ln2,d0      ln(2)
        jsr     ri_k_b(pc)
        pea     exit
m_a1
        bra.l   m_a             multiply and add

ri_exp
        movem.l reglist,-(sp)
        clr.w   d7              exp needs d7 = 0
        lea     exp_tab,a4      exponent polynomial tables
        bsr.l   argrd           reduce argument by increments of ln(2)
        bne.s   expbad          if exponent large, go see about under/overflow
        bsr.l   dup2_m          stack => g,g**2
        bsr.l   poly2           stack => g,p,q
        addq.l  #6,a1           work on p
        jsr     ri_mult(pc)     stack => g*p,-,q
        jsr     ri_dup(pc)      stack => g*p,g*p,q
        subq.l  #6,a1
        jsr     ri_swap(pc)     stack => g*p,q,g*p
        jsr     ri_sub(pc)      stack => g*p,q-g*p
        jsr     ri_div(pc)      stack => g*p/(q-g*p)
        addq.w  #1,0(a6,a1.l)   stack => 2*g*p/(q-g*p)
        jsr     ri_one(pc)      stack => 2*g*p/(q-g*p),1.0
        jsr     ri_add(pc)      stack => (q+g*p)/(q-g*p)
        add.w   d7,0(a6,a1.l)   add exponent
        move.b  0(a6,a1.l),d0
        asr.b   #4,d0           if ok or overflow, we're ready
        bmi.s   putzero         if negative, we've underflowed
exit3
        bra.l   exit

expbad
        tst.b   2(a6,a1.l)      big exponent, check for +ve or -ve mantissa
        bpl.s   exit3           force overflow for large values
putzero
        addq.l  #6,a1
        jsr     ri_zero(pc)     make result be zero
        bra.s   exit3

* Exponent tables

        dc.w    $0800,$4000,$0000       0.5
        dc.w    $07fc,$6db4,$ce83       0.05356751765
        dc.w    $07f5,$4def,$09ca       0.0002972936368
        dc.w    2
        dc.w    $07ff,$4000,$0000       0.25
        dc.w    $07f9,$617d,$e4ba       0.005950425498
        dc.w    1
        dc.w    $07ed,$5fdf,$473e       corrector 1.42860682e-6
        dc.w    $0800,$58b9,$0000       near ln(2) .69314575
        dc.w    $0801,$5c55,$1d95       1/ln(2) 1.44269504
        dc.w    $80b                    silly range (under/overflow certain)
exp_tab

* Log tables

        dc.w    $0803,$a6bc,$eee1       -5.5788737502
        dc.w    $0801,$4000,$0000       1.0
        dc.w    1
        dc.w    $07ff,$88fb,$e7c1       -0.4649062303
        dc.w    $07fa,$6f6b,$44f3       0.01360095469
        dc.w    1
log_tab

* Arctangent tables

        dc.w    $0803,$451f,$bedf       4.3202503892
        dc.w    $0803,$4c09,$1df8       4.7522258460
        dc.w    $0801,$4000,$0000       1.0
        dc.w    2
        dc.w    $0000,$0000,$0000       0.0
        dc.w    $0801,$a3d5,$ac3b       -1.4400834487
        dc.w    $0800,$a3d6,$2904       -0.7200268489
        dc.w    2
atn_tab

* Tangent tables

        dc.w    $0801,$4000,$0000       1.0
        dc.w    $07ff,$8e28,$7bc1       -0.44469477203
        dc.w    $07fb,$416d,$50cd       0.01597339213
        dc.w    2
        dc.w    $0000,$0000,$0000       0.0
        dc.w    $07fd,$8df7,$443e       -0.11136144036
        dc.w    $07f7,$4676,$1a70       0.001075154738
        dc.w    2
tan_tab

* Sine/cosine table

        dc.w    $0000,$0000,$0000       0.0
        dc.w    $07fe,$aaaa,$aab0       -0.16666666609
        dc.w    $07fa,$4444,$42dd       0.8333330721e-2
        dc.w    $07f4,$97fa,$15c1       -0.1984083282e-3
        dc.w    $07ee,$5c5a,$e940       0.2752397107e-5
        dc.w    $07e7,$997c,$79c0       -0.2386834641e-7
        dc.w    5
        dc.w    $07f0,$b544,$42d2       corrector -8.9089102e-6
        dc.w    $0802,$6488,$0000       near pi 3.14160156
        dc.w    $07ff,$517c,$c1b7       1/pi .31830989
        dc.w    $81f                    silly range (all accuracy lost)
sin_tab

        end
