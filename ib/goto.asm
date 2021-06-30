* Do an [ON exp] GO TO/SUB exp [{,exp}]
        xdef    ib_goto,ib_ongo

        xref    ca_evali
        xref    ib_call,ib_golin,ib_nxcom,ib_nxnon,ib_stbas

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_token'

        section ib_goto

ib_goto
        moveq   #1,d4           only one linenumber required
        bra.s   get_key

ib_ongo
        bsr.s   read_exp        get control value
        ble.s   err_or          selector not allowed to be -ve or 0
        addq.l  #2,a4           skip the go
get_key
        jsr     ib_nxnon(pc)    get a non-space, it will be a keyword
        move.b  d1,d5           save to or sub
get_exp
        subq.w  #1,d4           are we at the wanted expression yet?
        beq.s   get_lno         yes, go get the line number
        jsr     ib_nxcom(pc)    skip optional expression to get to next comma
        bne.s   get_exp         found a comma, so keep going
err_or
        subq.l  #4,sp
err_nul
        moveq   #err.or,d0
popret
        addq.l  #4,sp           don't bother with immediate return
        rts

read_exp
        move.l  a4,a0           start of expression
        jsr     ca_evali(pc)    get line number!!!
        move.l  a0,a4
        blt.s   popret
        beq.s   err_nul         this was a null (we could allow omitted slots)
        addq.l  #2,bv_rip(a6)
        move.w  0(a6,a1.l),d4
        rts

get_lno
        addq.l  #2,a4           skip to/sub or comma
        bsr.s   read_exp        read the line number
        assert  0,(b.keyto&1)-1,b.sub&1
        lsl.b   #7,d5           is this sub ? (and if so, set d5.b=0)
        bne.s   clinl
        jsr     ib_call(pc)     yes - go do rt setup for this
clinl
        sf      bv_inlin(a6)    inline flag no longer applies
        tst.b   bv_sing(a6)     has user typed go to/sub n as a command?
        beq.s   golin           no, so all is ok
        jsr     ib_stbas(pc)    position at first line in program
        bne.s   okrts           isn't one
golin
        jsr     ib_golin(pc)    move to line
        subq.l  #2,a4           move back over previous line feed
okrts
        moveq   #0,d0
        rts

        end
