* Basic universe
        xdef    sb_read,sb_unvr

        xref    bv_chssx,bv_die
        xref    bp_chnid,bp_comch,bp_detok,bp_list2,bp_rdbuf
        xref    ib_ernol,ib_glin0,ib_gost,ib_npass,ib_st1,ib_start,ib_stnxi
        xref    ib_stop,ib_stsng,ib_unret
        xref    pa_graph,pa_mist,pa_strip,pa_table
        xref    pf_nwlin

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'

c.defcn equ     0       default console channel

        section sb_unvr

* Code for initial entry only. BV area has been generally zeroed out.
sb_unvr
        move.l  a6,sp           move stack right to top of area ...
        add.l   bv_ssbas(a6),sp ... by adding offset to top of superbasic
        tst.l   bv_comch(a6)
        bne.s   nxlset
        subq.w  #1,bv_nxlin(a6) if no command channel, set nxlin -1
nxlset
        bsr.s   universe        entry, putting out-of-memory return on stack
errom
        jsr     ib_stop(pc)     come here when life gets hard
        bsr.s   sb_read         reinstate return for out-of-memory
        bra.s   errom

eof
        tst.l   bv_comch(a6)    were were already reading #0?
        beq.l   bv_die          yes - can't handle that!
        pea     rr_chk
com_zap
        sub.l   a0,a0           flag for #0
        jmp     bp_comch(pc)    set as the new command channel

bad_rdb
        move.l  d0,d1           bad read, see why
        addq.l  #-err.no,d1     not open ...
        beq.s   eof             ... treat as end of file
        addq.l  #err.no-err.ef,d1 really end of file?
        beq.s   eof             yes - probably just end of a load, etc
        jsr     ib_ernol(pc)    different error, tell user
off_auto
        sf      bv_auto(a6)     turn off the auto/edit flag
sb_read
        bsr.s   com_zap         turn off any command file / set initial one
        tst.b   (sp)            was there a command line to restore?
        bpl.s   universe        no, just read a new line then
        addq.l  #2+4,sp         drop misc saved stuff
        add.w   (sp)+,sp        drop length and contents of command line
universe
        clr.l   bv_sssav(a6)    set save pointer to top of ss stack
        move.l  bv_bfbas(a6),bv_bfp(a6) reset buffer
        moveq   #0,d3           show raw new line
        tst.b   bv_auto(a6)     is this an auto/edit or fetch?
        beq.s   edit            ..fetch
        move.w  bv_edlin(a6),d4 set line to edit
        ble.s   off_auto        if the line has become silly ...
        jsr     bp_detok(pc)    go and put the line in the buffer(no lf)
        move.w  bv_edinc(a6),d0 read the increment
        sne     bv_auto(a6)     if it's zero then turn edit off again
        add.w   d0,bv_edlin(a6) otherwise get line to edit next time
        move.l  bv_bfp(a6),d3
        sub.l   bv_bfbas(a6),d3 put cursor at end of line
edit
        bsr.s   comch           only allow edit if reading from console
        jsr     bp_rdbuf(pc)    read line into the buffer
        bne.s   bad_rdb         problem... go sort it out
        tas     bv_brk(a6)      clear break
        moveq   #' ',d7         for space trim and infinite pa_graph buffer
        moveq   #27,d0
        sub.b   -1(a6,a1.l),d0  what was the delimiter?
        scs     bv_arrow(a6)    0 if lf/esc, ff if up/down
        beq.s   off_auto        esc, turn off auto and get a new line
        add.b   #$d8-27,d0      was it down arrow? 
        bne.s   trimit          no - all is ok
        addq.b  #2,bv_arrow(a6) yes - change ff to 01
trimit
        subq.l  #1,a1
        cmp.l   bv_bfbas(a6),a1
        beq.s   universe        ignore totally blank line
        cmp.b   -1(a6,a1.l),d7  strip off trailing blanks
        beq.s   trimit
        addq.l  #1,a1
        move.b  #10,-1(a6,a1.l) put in a straight line feed
        move.l  a1,bv_bfp(a6)   now update the buffer running pointer
        bra.s   parse           go parse the line

comch
        move.l  bv_comch(a6),a0 get command channel
        move.l  a0,d0           ..is there one?
        bne.s   rts0            yes, fine
        moveq   #c.defcn,d1     get default channel
        move.w  #-1,a0          if channel not found, file not open will end us
        jmp     bp_chnid(pc)

rts0
        rts

dumrt
        moveq   #4,d1           select stack depth
        jsr     ib_unret(pc)    error message and unravel all
parse
        lea     pa_table(pc),a2 set start of table
        jsr     pa_graph(pc)    go into graph parsing routine
        beq.s   strip           all ok, go use the line
        bgt.s   dumrt           lno (or new name?) input, unravel needed
        bsr.s   comch           parse failed, is this a file or a user?
        bne.s   mist            it's a file, write mistake into prog
        subq.l  #1,bv_bfp(a6)   lose the terminator
        sub.l   bv_bfbas(a6),a4 we will show where the problems started
        move.w  a4,-(sp)
        moveq   #err.bl,d0
        jsr     ib_ernol(pc)    call error with no line number
        move.w  (sp)+,d3
        bra.s   edit            continue edit

mist
        jsr     pa_mist(pc)
strip
        jsr     pa_strip(pc)    strip out superfluous spaces
        jsr     pf_nwlin(pc)    save the program line
        bra.s   doline          +0 - no line number, execute at once
*       sf      bv_sing(a6)     +2 - line inserted into program file
* Above line seems redundant - see if it falls over without it
        move.l  d0,d3           state of line for relisting

        bsr.s   qcomch          if lines from file, go to top
        tst.l   d5              new pf_nwlin flag, zero if program is unchanged
        beq.s   sb_rd2          no change to program, so don't relist
        jsr     bp_list2(pc)    relist if d2/d3 imply extant screen change
sb_rd2
        bra.l   sb_read         go and read the next line

qcomch
        bsr.s   comch           are we reading from a file?
        beq.s   rts0            no - carry on
        addq.l  #4,sp           discard return
        bra.l   universe        back up to the top

doline
        move.l  bv_tkbas(a6),a4 tell start where to start
        move.b  #1,bv_stmnt(a6)
        sf      bv_inlin(a6)
        st      bv_cont(a6)     turn continue flag on (ie stop off)
do_1
        st      bv_sing(a6)
        assert  bv_linum,bv_lengt-2
        clr.l   bv_linum(a6)    initialise line number and length
        jsr     ib_npass(pc)
*       sf      bv_comln(a6)    first unset the flag - not needed?
        jsr     ib_stsng(pc)    start the single line
        bne.s   sb_rd2          had an error, close input, read a new line
        tst.b   bv_comln(a6)    must we save the command line
        beq.s   resrun          no
        subq.w  #4,bv_stopn(a6)
        blt.s   do_1            if clear, carry on
        beq.s   sb_rd2          if stop, get a new line
        assert  bv_tkbas,bv_tkp-4
        movem.l bv_tkbas(a6),a0-a1
        moveq   #(256+2+4+2+3)>>2,d1
        lsl.l   #2,d1
        add.l   a1,d1
        sub.l   a0,d1
        jsr     bv_chssx(pc)    ensure space on the stack (added by lwr)
        move.l  a1,a2
push_com
        subq.l  #2,a2
        move.w  0(a6,a2.l),-(sp)
        cmp.l   a2,a0           finished yet?
        bne.s   push_com

* N.B. The following assumes that the token list is never longer than 32766,
* but I guess that's fairly reasonable... lwr

        sub.l   a0,a1           length of token list saved
        move.w  a1,-(sp)
        assert  bv_inlin,bv_sing-1,bv_index-2
        move.l  bv_inlin(a6),-(sp)
        move.b  bv_stmnt(a6),1(sp) the statement number
        sub.l   a4,a0           negative offset of where we got to
        move.w  a0,-(sp)

resrun
        bsr.s   qcomch          if lines from file, go to top
rr_chk
        tst.w   bv_nxlin(a6)    should we restore or run?
        bge.s   run
        tst.b   (sp)            no, is there a command line to restore
        bpl.s   sb_rd3          no, just read a new line then
        move.l  bv_tkbas(a6),a0 start at beginning of toklist
        move.l  a0,a4
        sub.w   (sp)+,a4        a4 now pointing to next bit of sing to do
        move.b  1(sp),bv_stmnt(a6) restore the statement
        move.l  (sp)+,bv_inlin(a6)
        move.w  (sp)+,d0        length of command line
pop_com
        move.w  (sp)+,0(a6,a0.l)
        addq.l  #2,a0
        subq.w  #2,d0           done yet?
        bne.s   pop_com
        move.l  a0,bv_tkp(a6)   reset the running pointer
        bra.s   do_1

sb_rd3
        bra.l   sb_read

run
        jsr     ib_npass(pc)
        sf      bv_sing(a6)
        move.b  #1,bv_stmnt(a6)
        move.w  bv_nxlin(a6),d4 now then, where are we to start?
        jsr     ib_glin0(pc)    find it
        ble.s   sb_rd3          not in program, so ignore
        subq.w  #2,d1
        move.w  d1,bv_lengt(a6) set prior line length
        tst.w   d4
        beq.s   ib_1            start at the top, ignore nxstm
        move.b  bv_nxstm(a6),d4 which statement?
        beq.s   ib_1            the first statement
        jsr     ib_stnxi(pc)
        jsr     ib_gost(pc)
go
        jsr     ib_st1(pc)      start from next statement
ib_ret
        bne.s   sb_rd3          had an error, read a new line (? work ?)
        tst.w   bv_stopn(a6)    why have we come back ?
        beq.s   go              if clear, carry straight on
        bra.s   resrun          if not clear, then read, run or restore

ib_1
        jsr     ib_start(pc)    start from top of a line
        bra.s   ib_ret

        end
