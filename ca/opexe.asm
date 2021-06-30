* operation evaluator
        xdef    ca_opexe

        xref    ca_cncat,ca_cnvrt
        xref    mm_mrtor
        xref    ri_add,ri_cmp,ri_div,ri_fllin,ri_mult,ri_neg,ri_power,ri_powfp
        xref    ri_sub
        xref    ut_cstr,ut_istr

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'
        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_vect4000'

        section ca_opexe

* Primary operator table... sorts out major decisions
optab1
 dc.w i_asm-e,i_asm-e,i_asm-e,fp2-e     + - * (i/i) / (f/f)
 dc.w c-e,c-e,c-e,c-e,c-e,c-e,c-e       >= > == = <> <= < (i/i or s/s)
 dc.w b_dyad-e,b_dyad-e,b_dyad-e        || && ^^ (i/i)
 dc.w exp-e,str2-e                      ^ (f/i) & (s/s)
 dc.w l_dyad-e,l_dyad-e,l_dyad-e        or and xor (i/i)
 dc.w int2-e,int2-e,str2-e              mod div (i/i) instr (s/s)
* Monadics
 dc.w i_minus-e,i_plus-e,b_not-e,l_not-e - (i) + (n) ~~ not (i) (monadic ops)

* Secondary operator table... catches all the fp/fp stuff we had trouble with
optab2
 dc.w ri_add-e,ri_sub-e,ri_mult-e,ri_div-e      + - * /
 dc.w f-e,f-e,f-e,f-e,f-e,f-e,f-e               >= > == = <> <= <
 dc.w ri_powfp-e                                ^ (adjusted to save waste)

* d0 -  o- error code (not neccesarily in condition codes)
* d4 -i  - operation code in lsb - must not touch msw
* a1 -i o- arithmetic stack pointer (must be stored by calling routine)
* a5 -i o- name table pointer (updated properly here)
* d1-d3 destroyed

* Care must be taken that the exit from this module ensures that the data types
* recorded in the top NT entries always match the data on the RI stack.
* If a dyadic operation removes it's second operand, a5 must be decremented by
* eight and stored in bv_ntp. The returned value of a1 must be stored in bv_rip
* by the calling routine (ca_eval).
* These rules must be followed even on exit with a non-error code, when
* unraveling the table/stack is particularly sensitive!
 
ca_opexe
        moveq   #15,d2
        and.b   -7(a6,a5.l),d2  mask any separator which may be here
        move.b  d2,-7(a6,a5.l)  store the masked type
        clr.w   d1
jmp2
        moveq   #0,d0           assume we'll have no errors
        add.b   d4,d1
        add.w   d1,d1
        move.w  optab1-2(pc,d1.w),d1 what might we do for this operation?
        subq.b  #t.fp,d2        set up condition code for the 2nd operand type
        jmp     e(pc,d1.w)      go do something

i_asm
        ble.s   fp2             not an integer, so we'll have to do fp/fp
        bsr.s   try1st          what's the 1st operand type?
        ble.s   fp2             not integer, so must do fp/fp again
        bsr.l   drop2           we're definately happy...
        move.w  -2(a6,a1.l),d1
        subq.b  #b.dif,d4       which of +, - or * is it?
        bgt.s   i_mul
        beq.s   i_sub
        add.w   d1,0(a6,a1.l)
        bvs.s   i_ext           ouch! have to extend answer into fp
doneit
        rts

i_sub
        sub.w   d1,0(a6,a1.l)
        bvc.s   doneit          nice!
        scc     d3
        add.b   d3,d3           invert the extend bit
i_ext
        move.w  0(a6,a1.l),d3   get the bulk of the answer
        swap    d3
        roxr.l  #1,d3           roll in the extend bit
        subq.l  #4,a1
        move.w  #$810,0(a6,a1.l)
        move.l  d3,2(a6,a1.l)
make_fp
        subq.b  #t.int-t.fp,-7(a6,a5.l)  change type from int to fp
        rts

i_mul
        muls    0(a6,a1.l),d1
        move.w  d1,0(a6,a1.l)   store lsw, and hope it's ok...
        move.w  d1,d2
        ext.l   d2
        cmp.l   d2,d1           did the result still fit into a short integer?
        beq.s   anrts           hurrah!
        addq.l  #2,a1
        jsr     ri_fllin(pc)    go float it
        bra.s   make_fp         change it to fp

try1st
        moveq   #15,d3
        and.b   -15(a6,a5.l),d3 what's the 1st operand type?
        move.b  d3,-15(a6,a5.l)
        subq.b  #t.fp,d3
        rts

e
fp2x
        subq.w  #3,d4           adjust opcode to save 3 words in table for pow
fp2
        bsr.s   cnvrtf          convert 2nd operand to float
        bne.s   anrts           nasty - it didn't work!
        bsr.s   drop6           that's taken care of
        move.l  -4(a6,a1.l),-(sp)
        move.w  -6(a6,a1.l),-(sp) save 2nd operand
        bsr.s   cnvrtf          convert 1st operand to float
        bne.s   ohdear6
        subq.l  #6,a1           space down the stack
        move.w  (sp)+,0(a6,a1.l) restore 2nd operand
        move.l  (sp)+,2(a6,a1.l)
        moveq   #(optab2-optab1)/2,d1
        bra.l   jmp2            go do secondary jump table

ohdear6
        addq.l  #6,sp           discard the saved fp
anrts
        rts

exp
        ble.s   fp2x            2nd operand not integer - do the standard stuff
        bsr.s   drop2
        move.w  -2(a6,a1.l),-(sp) save integer power
        bsr.s   cnvrtf          convert 1st operand to float
        bne.s   ohdear2
        subq.l  #2,a1
        move.w  (sp)+,0(a6,a1.l)
        jmp     ri_power(pc)    go do integer power

* Various comparisons
c
        beq.s   fp2             if fp, make both fp
        bmi.l   c_fpstr         if str, go see if both are strings
        bsr.s   try1st          what's the 1st operand like?
        ble.s   fp2             if not int, must do fp/fp
        bsr.s   drop2           yipee! we have int/int compare... do it here
        moveq   #1,d0
        move.w  0(a6,a1.l),d1
        cmp.w   -2(a6,a1.l),d1
        bgt.s   c_bit
        sne     d0
        ext.w   d0
c_bit
        clr.w   d1
        dc.w    $093b,patcmp+1-*-2 btst    d4,patcmp+1(pc,d0.w)
        sne     d1
        neg.b   d1
storeint
        move.w  d1,0(a6,a1.l)
        moveq   #0,d0
        rts

        assert  8+b.near-7,8+b.gt-6,8+b.ge-5,8,b.lt-3,b.le-2,b.ne-1,b.eq
patcmp  dc.b    %00001110,%10100101,%01100010,0 patterns for <, = and >

cnvrtf
        moveq   #t.fp,d0
        jmp     ca_cnvrt(pc)

drop6
        addq.l  #4,a1
drop2
        addq.l  #2,a1
        move.l  a1,bv_rip(a6)
drop
        subq.l  #8,a5
        move.l  a5,bv_ntp(a6)
        rts

int2
        moveq   #t.int,d0
        bsr.s   cnvrt0          convert 2nd operand to int
        bne.s   aprts
        bsr.s   drop2           that's taken care of
        move.w  -2(a6,a1.l),-(sp) save 2nd operand
        moveq   #t.int,d0
        bsr.s   cnvrt0          convert 1st operand to int
        beq.l   div_mod

ohdear2
        addq.l  #2,sp           discard saved 2nd operand
aprts
        rts

cnvrts
        moveq   #t.str,d0       make operand into a string (can't fail!)
cnvrt0
        jmp     ca_cnvrt(pc)

gostr2
        lsr.b   #2,d4           which of & or instr are we doing?
        bcc.s   gocncat         & is the hard one

        movem.l d7/a0,-(sp)
        bsr.s   add_a1          step over first string
        move.l  a1,d7           remember where it started
        bsr.s   add_a1_0        step past second string
        exg     a0,d7           now put a0/a1 strings and d7 = top of stack
        bra.s   istrnow

gocncat
        pea     ca_cncat(pc)
drops
        bra.s   drop

str2
        bsr.s   cnvrts          make the 2nd operand into a string
        bsr.l   try1st          what's the 1st parameter like?
        blt.s   gostr2          phew! already a string, so no need for ....

        movem.l d7/a0,-(sp)     registers that need to be saved

        bsr.s   add_a1          find out where the second operand lives
        moveq   #2,d7           length of an int
        tst.b   d3
        bne.s   cop1wrd
        moveq   #6,d7           length of an fp
        move.l  2(a6,a0.l),-4(a6,a1.l) copy mantissa
cop1wrd
        sub.l   d7,a1
        move.w  0(a6,a0.l),0(a6,a1.l) copy exponent or integer
        add.l   a0,d7           this is the top of the stack
        move.l  a1,bv_rip(a6)   say where we are at the moment
        move.b  -15(a6,a5.l),-7(a6,a5.l) fudge top entry look like 2nd!!!
        sub.l   bv_ribas(a6),d7 make it depth of stack, in case it moves
        bsr.s   cnvrts          make the 1st operand into a string (d0.l=0)
        add.l   bv_ribas(a6),d7 add back base of stack
        assert  0,b.join&2,b.instr&2-2
        lsr.b   #2,d4           which of & or instr are we doing?
        bcc.s   gocnc           & is the hard one
        bsr.s   add_a1
istrnow
        exg     a0,a1
        moveq   #1,d0           set for instr
        jsr     ut_istr(pc)
        move.l  d7,a1
        movem.l (sp)+,d7/a0
        subq.l  #2,a1           where to put integer result
        bsr.s   drops
        move.b  #t.int,-7(a6,a5.l)
        bra.l   storeint

add_a1_0
        move.l  a0,a1
add_a1
        move.w  0(a6,a1.l),d2   length of string now at tos
        lea     2(a1,d2.w),a0   drop length and chars
        rol.b   #8,d2           check for odd length
        bcc.s   rts9
        addq.l  #1,a0           skip pad byte
rts9
        rts

* d0.l = 0
gocnc
        bsr.s   drops
        move.b  #t.str,-7(a6,a5.l)
        bsr.s   add_a1          now a1 = 1st string, a0 = 2nd string
        move.w  d2,d4           save 1st string length
        move.w  0(a6,a0.l),d1   2nd string length
        add.w   d1,d2           combined length
        exg     d7,a1
        exg     a0,a1           source into a1, destination into a0
* d7/d4 = tos string, a1/d1 = nos string, a0 = all removed, d2 = d1+d4
        cmp.w   #32765,d2       we won't let it get too huge...
        bcs.l   cncat
        moveq   #err.ov,d0      overflow error
        moveq   #0,d2
putlen
        lea     -2(a0),a1
        movem.l (sp)+,d7/a0
        move.w  d2,0(a6,a1.l)
        rts

c_fpstr
        bsr.l   try1st          what's the 1st operand like?
        bge.l   fp2             if not str, must do fp/fp
* We have two strings to compare... so do it
        bsr.l   drop
        cmp.b   #b.near,d4      is it == ?
        sne     d0
        addq.b  #3,d0
        move.l  a0,-(sp)
        bsr.s   add_a1          a0 is at start of string b
        jsr     ut_cstr(pc)
        bsr.s   add_a1_0        a0 is at end of string b
        lea     -2(a0),a1       a1 is now ready for t or f value
        move.l  (sp)+,a0
        bra.l   c_bt2

b_dyad
        moveq   #t.int,d0
        bra.s   logic

l_dyad
        assert  b.lor-b.bor,b.land-b.band,b.land-b.band
        subq.b  #b.lor-b.bor,d4
        moveq   #t.log,d0
logic
        move.w  d0,-(sp)
        bsr.s   lcnv
        bsr.l   drop2
        move.w  (sp),d0
        move.w  -2(a6,a1.l),(sp)
        bsr.s   lcnv
        move.w  (sp)+,d1
        assert  0,b.bor&3,b.band&3-1,b.bxor&3-2
        asl.b   #7,d4
        bmi.s   l_and
        bcs.s   l_xor
        or.w    d1,0(a6,a1.l)
        rts

l_and
        and.w   d1,0(a6,a1.l)
        rts

l_xor
        eor.w   d1,0(a6,a1.l)
        rts

lcnv
        bsr.s   cnv0
        beq.s   aorts
        addq.l  #6,sp           drop saved word and return address
        rts

i_minus
        ble.s   f_minus         rats! have to do it in fp
        neg.w   0(a6,a1.l)
        bvc.s   aorts           only $8000 screws up here, and stays!
f_minus
        bsr.s   cnvf
        bne.s   aorts
        jmp     ri_neg(pc)

i_plus
        bge.s   aorts           don't bother if it's already numeric
cnvf
        moveq   #t.fp,d0
cnv0
        jmp     ca_cnvrt(pc)

b_not
        moveq   #t.int,d0
        bsr.s   cnv0
        bne.s   aorts
        not.w   0(a6,a1.l)      invert all bits
        rts

l_not
        moveq   #t.log,d0
        bsr.s   cnv0
        bne.s   aorts
        bchg    d0,1(a6,a1.l)   swap 0 <--> 1
aorts
        rts

f
        jsr     ri_cmp(pc)
        addq.l  #4,a1
        cmp.b   #b.near,d4      if op was == ...
        beq.s   f_approx        go see to that
        move.b  -2(a6,a1.l),d0  get msb mantissa, $80 <, 0 = or $40 >
        beq.s   c_bt2           zero result is ready
        rol.b   #2,d0           that was $40 -> 1, $80 -> 2
        bcs.s   c_bt2           so carry will be set if we've got a good 1
c_bt1
        moveq   #-1,d0          set -1
c_bt2
        move.b  #t.int,-7(a6,a5.l) make into an integer
        bra.l   c_bit

f_approx
        move.b  -4(a6,a1.l),d0  msb exponent is 0 if == is true, 8 otherwise
        bne.s   c_bt1
        bra.s   c_bt2

div_mod
        move.w  0(a6,a1.l),d1   get a
        ext.l   d1
        move.w  (sp)+,d0        get b
        beq.s   dmzero          oops
        smi     d2              flag if negative, as remainder will need negate
        bpl.s   dmbypos
        neg.l   d1              if b was -ve, negate a and b
        neg.w   d0
        bvs.s   dmby32k         sort out div/mod -32768
dmbypos
        divs    d0,d1           get a/b
        bvs.s   dmovr           oops (must have been trying to do -32768/-1)
dmok
        tst.l   d1              has remainder come out negative?
        bpl.s   dmrpos          no, that's ok
        swap    d0              (note, msw was zero, as no error at int cnvrt)
        add.l   d0,d1           force remainder to positive
        subq.w  #1,d1           push quotient down one (can't overflow)
dmrpos
        assert  0,b.idiv&1-1,b.mod&1
        asr.b   #1,d4
        bcs.s   storint2
        swap    d1
        tst.b   d2              was it a negative divisor?
        beq.s   storint2        no - leave positive remainder
        neg.w   d1              yes - make remainder negative
storint2
        bra.l   storeint

dmby32k
        add.w   d1,d1           was original a zero or -32768?
        beq.s   dma32k0         yes, go sort those as special cases
        lsr.w   #1,d1           force +ve and mod is ready
        swap    d1              +/-ve div -32768 = -1/0, mod is -a&&32767
        bra.s   dmrpos

dma32k0
        addx.b  d1,d1           ahah! 0 = 0/0, -32768 div/mod -32768 = 1/0
        bra.s   dmrpos

dmovr
        clr.w   d1              -32768 mod -1 = 0 is a valid answer ...
        asr.b   #1,d4           ... but -32768 div -1 = 32768 doesn't fit!
        bcc.s   storint2
dmzero
        moveq   #err.ov,d0
        rts

* d0=0, d7/d4 = tos string, a1/d1 = nos string, a0 = all removed, d2 = d1+d4
cncat
        btst    d0,d2           is length going to be odd?
        beq.s   notodd
        subq.l  #1,a0           yes - leave the odd junk byte
notodd
        bsr.s   copup           copy 2nd operand bytes up the stack
        move.l  d7,a1           get back 1st string
        move.w  d4,d1           length of 1st string
        pea     putlen          go back to store length
copup
* The following test needs tuning... the break even point must come somewhere
        add.w   d1,a1           end of source string
        cmp.w   #64,d1          is it worth getting clever?
        bcs.s   copsent         no - go do slow stuff
        sub.w   d1,a1           back to start of source string
        addq.l  #2,a1           miss out length
        sub.w   d1,a0           start of destination area
        ext.l   d1              clear msw
        jmp     mm_mrtor(pc)    go use the fast copy

copsl
        subq.l  #1,a0
        subq.l  #1,a1
        move.b  2(a6,a1.l),0(a6,a0.l)
copsent
        dbra    d1,copsl
        rts

        vect4000 ca_opexe

        end
