* Get next item of data
        xdef    bp_data

        xref    ib_golin,ib_gost,ib_nxcom,ib_nxnon,ib_nxst
        xref    ib_s2non,ib_stbas,ib_stnxi

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_token'
        include 'dev7_m_inc_assert'

        section bp_data

* d0 -  o- 0 found, err.ef if not found, ccr set
* a0 -  o- where data item is found, else preserved
* d1-d4 destroyed (d5 now preserved, d3-d4 could be saved easily)

bp_data
        assert  bv_linum,bv_lengt-2,bv_stmnt-4,bv_cont-5,bv_inlin-6,bv_sing-7
        movem.l bv_linum(a6),d1-d2 get context (index doesn't need saving)
        moveq   #err.ef,d0      in case we hit eof
        movem.l d0-d2/a4,-(sp)  save error code, context and program pointer
        jsr     ib_stbas(pc)    always look from top of prog
        bne.s   restore         no file there!
        assert  bv_dalno,bv_dastm-2,bv_daitm-3
        move.l  bv_dalno(a6),d4 current data position
        swap    d4              data line number
        jsr     ib_golin(pc)
        bne.s   restore         no line left in file
        jsr     ib_stnxi(pc)
        rol.l   #8,d4           current data statement
        jsr     ib_gost(pc)
        rol.l   #8,d4           data item to find
        bra.s   find_ent        (d4 shouldn't be zero, but no matter if it is!)

nx_item
        subq.l  #2,a4           unskip the data or comma
        jsr     ib_nxcom(pc)    get the next proper comma
        bne.s   at_item         more items available
find_dat
        moveq   #0,d4
        jsr     ib_nxst(pc)     get start of next statement
        bne.s   restore         aargh, we've run out
find_ent
        jsr     ib_nxnon(pc)
        cmp.w   #w.data,d1
        bne.s   find_dat        not a data line
        tst.l   d4
        bne.s   at_item
        move.l  bv_linum(a6),d4 get new data line number
        assert  0,1&bv_stmnt
        move.w  bv_stmnt(a6),d4 ditto statement
        move.b  #1,d4           first item
        move.l  d4,bv_dalno(a6) set new data position
at_item
        jsr     ib_s2non(pc)    skip data or comma
        subq.b  #1,d4           got there yet?
        bne.s   nx_item         no, keep going
        move.l  a4,a0           this is where to read value from
        clr.l   (sp)            all ok, ccr zero
restore
        movem.l (sp)+,d0-d2/a4
        movem.l d1-d2,bv_linum(a6)
        rts

        end
