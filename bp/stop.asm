* All stopping routines
        xdef    bp_run,bp_lrun,bp_load,bp_new,bp_mrun,bp_merge
        xdef    bp_clear,bp_stop,bp_retry,bp_conte,bp_conti,bp_chunr,bp_comch

        xref    bp_fopin
        xref    ca_gtin1

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_stop'
        include 'dev7_m_inc_assert'

        section bp_stop

bp_retry
        subq.b  #1,bv_cnstm(a6) redo the last statement
        bge.s   bp_conte        assuming it's non zero!
        sf      bv_cnstm(a6)    start at beginning then
bp_conte
        bsr.s   optlin
        beq.s   bp_conti
        move.w  d4,bv_cnlno(a6) set continue line number
        sf      bv_cnstm(a6)    statement zero
        clr.w   bv_cnind(a6)    no in-line index
        sf      bv_cninl(a6)    not in-line
bp_conti
        sf      bv_wherr(a6)    set when off again
        moveq   #s.retry-s.stop,d7
bp_stop
        addq.b  #s.stop-s.new,d7
bp_new
        addq.b  #s.new,d7
stops
        moveq   #-1,d4
        bra.s   setnxl

bp_run
        moveq   #s.run,d7
        pea     setnxs          d0=0, set to request 1st statement

* d0 -  0- 0
* d4 -  o- zero (ccr = z) or optional line number present (ccr gt).
* d1-d3 destroyed iff line number returned

optlin
        moveq   #0,d4           default zero line number
        cmp.l   a3,a5
        beq.s   retok
        jsr     ca_gtin1(pc)
        bne.s   popex
        move.w  0(a6,a1.l),d4   optional line number must be 1..32767
        bgt.s   rts1
        moveq   #err.bp,d0
popex
        addq.l  #4,sp           skip return address, no need to go back
rts1
        rts

bp_load
        pea     bp_lrun
tstsing
        tst.b   bv_sing(a6)     if not single, load->lrun and merge->mrun
        beq.s   rts1
        assert  s.load-s.lrun,s.merge-s.mrun
        addq.b  #s.load-s.lrun,d7
        rts

bp_merge
        bsr.s   tstsing         if not a single line, merge -> mrun
bp_mrun
        addq.b  #s.mrun-s.lrun,d7
        bsr.s   bp_chunr        can't do merging if in proc/fn
bp_lrun
        addq.b  #s.lrun,d7
        jsr     bp_fopin(pc)
        bne.s   rts1
        bsr.s   bp_comch        set new command channel
        assert  0,s.lrun-8,s.load-10,s.mrun-12,s.merge-14
        move.w  d7,d4           00001ms0 m=merge, s=stop
        lsl.b   #6,d4           s0000000 c=merge
        bmi.s   stops           load/merge: don't carry on at all
        bcc.s   setnxl          lrun: run from top
        bra.s   snglin          mrun: run from top if single line, else next

bp_clear
        moveq   #-1,d4
snglin
        tst.b   bv_sing(a6)     if single line, don't run anything
        bne.s   setnxl
        move.w  bv_linum(a6),d4 continue running from current pos
        move.b  bv_stmnt(a6),d0
setnxs
        move.b  d0,bv_nxstm(a6)
setnxl
        move.w  d4,bv_nxlin(a6)
        sf      bv_cont(a6)
        move.w  d7,bv_stopn(a6)
retok
        moveq   #0,d0
        rts

bp_chunr
        move.l  bv_rtp(a6),d0
        sub.l   bv_rtbas(a6),d0
        beq.s   rts1            fine if nothing on return stack
        tst.b   bv_sing(a6)
        sne     bv_undo(a6)     if single line, undo, and try again
        moveq   #err.ni,d0      if in prog, say not implemented
        bra.s   popex

* d0 -  o- 0 (ccr set)
* a0 -ip - new channel ID to put in comch
* a1 destroyed
bp_comch
        move.l  a0,-(sp)
        move.l  bv_comch(a6),d0 if current comch is non-zero, close it
        beq.s   comclr
        move.l  d0,a0
        moveq   #io.close,d0
        trap    #2
comclr
        move.l  (sp)+,bv_comch(a6)
        bra.s   retok

        end
