* END statements
        xdef    ib_end,ib_endw

        xref    ib_ewret,ib_gtlpl,ib_loop,ib_nxnon,ib_ret,ib_wscan
        xref    bp_conti

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_lpoff'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ib_end

* d4 -  o- name row
* a4 -i o- program file
* a2 -  o- loop description pointer
* d0 -  o- worked (0) or failed

ib_end
        jsr     ib_nxnon(pc)    get next non-space
        sub.w   #w.rep,d1       REPeat?
        beq.s   repfor          yes, go REP it (extend clear)
        addq.w  #w.rep-w.for,d1 FOR?
        beq.s   repfor          yes, go FOR it (extend set)
        subq.w  #w.when-w.for,d1 WHEN?
        beq.s   when            yes, go when it
        subq.w  #w.def-w.when,d1 DEFine?
        beq.l   ib_ret          yes, treat as a return
* Anything else (SEL, IF) we just ignore
okrts
        moveq   #0,d0           don't have to do anything special
rts0
        rts

repfor
        moveq   #t.rep>>1,d5
        addx.b  d5,d5
        addq.l  #2,a4           skip keyword
        jsr     ib_gtlpl(pc)
        bne.s   rts0
        moveq   #err.nf,d0
        cmp.b   d5,d1           check the loop type is what we expected
        bne.s   rts0
        move.w  bv_linum(a6),lp.el(a6,a2.l) fill in endloop pointer
        move.b  bv_stmnt(a6),lp.es(a6,a2.l) and which statement on line it is
        jmp     ib_loop(pc)     repeat or continue (see next)

when
        tst.b   bv_wherr(a6)    are we doing a when?
        bne.l   bp_conti        yes, do a continue
ib_endw
        move.w  bv_linum(a6),d4 current lno
        moveq   #-1,d3          look for it
        jsr     ib_wscan(pc)
        bne.s   okrts
        jmp     ib_ewret(pc)

        end
