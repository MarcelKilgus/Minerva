* EXIT from a loop
        xdef    ib_exit,ib_fend

        xref    ib_eos,ib_golin,ib_gost,ib_gtlpl,ib_nxnon,ib_s2non,ib_stnxl

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_lpoff'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ib_exit

ib_exit
        jsr     ib_gtlpl(pc)    get loop line
        bne.s   rts0            there isn't one
        move.w  lp.el(a6,a2.l),d4 get end line number
        beq.s   nolin           there isn't one
        jsr     ib_golin(pc)    go to it
        bne.s   okrts           (quicker but not strictly necessary)
        jsr     ib_stnxl(pc)
        bne.s   okrts
        move.b  lp.es(a6,a2.l),d4 get statement on end line
        jsr     ib_gost(pc)     go to it
okrts
        moveq   #0,d0           good
rts0
        rts

nolin
        move.w  -2(a6,a4.l),d4  read the loop name, need to check it
        moveq   #t.for,d5
        sub.b   d1,d5           d5 will now be 0 for FOR, 1 for REP

ib_fend
nxstat
        jsr     ib_eos(pc)      find end of current statement
        blt.s   lf              found a line feed
        addq.l  #2,a4           skip colon
        addq.b  #1,bv_stmnt(a6) increment statement count
        bra.s   checkend_

lf
        tst.b   bv_inlin(a6)    lf, is this the end?
        beq.s   skip
        sf      bv_inlin(a6)    yes, so turn inline flag off
        move.w  bv_linum(a6),d0 is this inline the loop I'm trying to exit
        cmp.w   lp.sl(a6,a2.l),d0
        beq.s   okrts           yes, we've got to end
skip
        tst.b   bv_sing(a6)     single line command?
        bne.s   okrts           silly user
        addq.l  #2,a4           skip

        jsr     ib_stnxl(pc)    start the next line off
        bne.s   okrts
checkend_
        jsr     ib_nxnon(pc)    get 1st non-space
        cmp.w   #w.end,d1       END?
        bne.s   nxstat
        jsr     ib_s2non(pc)    yes, skip it
        assert  (t.for-t.rep)*2,w.rep-w.for
        sub.b   d5,d1           what sort of loop're we looking for?
        sub.b   d5,d1           1..REP, 0..FOR, for.b = rep.b - 2
        cmp.w   #w.for,d1       want FOR (REP converted)
        bne.s   nxstat
        jsr     ib_s2non(pc)    skip key and get next non-space
        cmp.w   2(a6,a4.l),d4   is it the right name?
        bne.s   nxstat
        move.w  bv_linum(a6),lp.el(a6,a2.l) yes! quick,fill in the endline and
        move.b  bv_stmnt(a6),lp.es(a6,a2.l) st in case we use this loop again
        bra.s   okrts

        end
