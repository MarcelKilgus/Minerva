* Start execution
        xdef    ib_st1,ib_st2,ib_start,ib_stbas,ib_steof
        xdef    ib_stimm,ib_stnxi,ib_stnxl,ib_stsng

        xref    bp_conti
        xref    bv_chss,bv_upnxt
        xref    ib_endw,ib_eos,ib_errnc,ib_error,ib_kywrd,ib_name1
        xref    ib_nxnon,ib_psend,ib_stop,ib_symbl,ib_wscan

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_token'

        section ib_start

st0
        move.l  bv_pfbas(a6),a4 start right at stop
ib_start
        sf      bv_inlin(a6)    set in-line flag off (mainly for singles)
        tst.b   bv_sing(a6)     are we executing a single line?
        bne.s   ib_stsng        yes
nxlin
        bsr.l   ib_stnxl        set variables for the next line
        bne.s   stopit          reached the end of the program

* Starting a single line
ib_stsng
        jsr     bv_chss(pc)

; this is intended to allow clever error handling, but it's not complete...
;       movem.l a6-a7,-(sp)     snapshot base and stack pointer
;       move.l  bv_ssbas(a6),d1 get relative top of basic
;       add.l   (sp)+,d1
;       sub.l   (sp)+,d1        depth of stack where we are now
;       move.l  d1,bv_sssav(a6) save it

ib_stimm
        jsr     ib_nxnon(pc)    locate next token and put it in d0
        tst.b   bv_uproc(a6)    is there a user trace procedure?
        bpl.s   noup
        jsr     bv_upnxt(pc)    yes - call it
noup
        pea     ib_st2
        sub.b   #b.key,d0
        beq.l   ib_kywrd
        subq.b  #b.nam-b.key,d0
        beq.l   ib_name1
        addq.b  #b.nam-b.sym,d0
        beq.l   ib_symbl
        addq.l  #4,sp
        moveq   #err.ni,d0      can't do system variables yet

* I hope this is where functions come to
ib_st2
        tst.l   d0
        bne.l   ib_error        check for execution error in last stmnt
        tas     bv_brk(a6)      no, was there a break
        bpl.l   ib_errnc        treat as a not complete error
stopit
        tas     bv_cont(a6)     no, phew! was that a stop?
        beq.l   ib_stop         go and deal with it

        tst.b   bv_sing(a6)
        bne.s   ib_st1
        cmp.l   bv_pfbas(a6),a4 has user gone to beg of file?
        ble.s   st0             you guessed

ib_st1
        jsr     ib_eos(pc)      find end of current statement
        bge.s   colon           found a colon
        tst.b   bv_inlin(a6)    found line feed, in-line loop?
        beq.s   nx3             no
        blt.s   nx2             no, but it might be a when
        jsr     ib_psend(pc)    ..yes, do a pseudo end
        tst.b   bv_inlin(a6)    is it still inline?
        bne.s   ib_st2          and continue as normal
nx2
        tst.b   bv_wherr(a6)    inline, are we error processing?
        beq.s   nx4
        tst.b   bv_wrinl(a6)    yes, is this an inline when?
        beq.s   nx3
        jsr     bp_conti(pc)    yes, continue from error line then
        st      bv_cont(a6)     put continue flag on again
        jmp     ib_stop(pc)

nx4
        move.w  bv_linum(a6),d4
        moveq   #-1,d3
        jsr     ib_wscan(pc)
        bne.s   nx3
        jsr     ib_endw(pc)
        bra.s   ib_st1

nx3
        tst.b   bv_sing(a6)     have we just executed a single line?
        addq.l  #2,a4
        beq.l   nxlin           ..no, get on with it
        bsr.s   steol          tell unvrs we've stopped
        bra.s   okrts

colon
        addq.l  #2,a4           skip over it
        addq.b  #1,bv_stmnt(a6) increment stat count
        bra.l   ib_stsng

ib_stbas
        move.l  bv_pfbas(a6),a4 start at the top
        sf      bv_sing(a6)
        clr.w   bv_lengt(a6)

ib_stnxl
        sf      bv_inlin(a6)    make sure in-line flag is off

ib_stnxi
        clr.w   bv_linum(a6)
        tst.b   bv_sing(a6)
        bne.s   stmnt_1
        cmp.l   bv_pfp(a6),a4   bottom of file yet?
        bge.s   ib_steof
        move.w  0(a6,a4.l),d0
        add.w   d0,bv_lengt(a6) get length of current line
        move.w  4(a6,a4.l),bv_linum(a6) save line num in 'current' slot
        addq.l  #6,a4
stmnt_1
        move.b  #1,bv_stmnt(a6) initialise statement on line
okrts
        moveq   #0,d0           good return
        rts

ib_steof
        sf      bv_cont(a6)     stop when we get back
steol
        move.w  #-1,bv_nxlin(a6)
        move.w  #4,bv_stopn(a6) pretend we stopped from natural causes
        rts

        end
