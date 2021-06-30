* Strip superfluous tokens
        xdef    pa_strip

        xref    ib_nxtk

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_token'
        include 'dev7_m_inc_vect4000'

        section pa_strip

* N.B. This routine was unsafe for some fp numbers (e.g. 1073776525!) text in
* quotes or remark statements, etc... total rehash by lwr (saves all regs now)

* a6 -ip - basic area

reglist reg     d0-d2/a2-a5
pa_strip
        movem.l reglist,-(sp)
        assert  bv_tkbas,bv_tkp-4
        movem.l bv_tkbas(a6),a4-a5 start and end of token list
        move.l  a4,a2           where to store stripped line
        moveq   #1,d2           flag for start of line
        bra.s   enter

skip
        sf      d2              no more space skipping
        addq.l  #2,a4           drop forced or single space
enter
        move.w  0(a6,a4.l),d1   pick up next token
        bra.s   loop

next
        cmp.w   #w.space,d1     check for a forced space
        beq.s   skip            if so, we can scrap it
        assert  0,b.spc&127
        lsr.w   #7,d1
        lsr.b   #1,d1
        bne.s   other
        neg.b   d2              still at start of line?
        bmi.s   skip            yes - leave off leading spaces
        sub.b   d2,1(a6,a4.l)
        beq.s   skip            skip if no more than a single space
other
        cmp.b   #b.lno-b.spc,d1 line no?
        seq     d2
        subq.b  #b.key-b.spc,d1 keyword?
        seq     d1
        or.b    d1,d2           either leaves d2.b=-1 as space flag
copy
        move.l  a4,a3           remember where we are
        jsr     ib_nxtk(pc)
clp
        move.w  0(a6,a3.l),0(a6,a2.l) copy down what we just moved past
        addq.l  #2,a2
        addq.l  #2,a3
        cmp.l   a4,a3
        bne.s   clp
loop
        cmp.l   a5,a4           are we finished?
        bcs.s   next            no - try next token
        move.l  a2,bv_tkp(a6)   set new end of list
        movem.l (sp)+,reglist
        rts

        vect4000 pa_strip

        end
