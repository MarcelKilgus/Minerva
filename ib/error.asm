* Error processing
        xdef    ib_errep,ib_errnc,ib_ernol,ib_error,ib_pserr

        xref    cn_itod
        xref    ut_err
        xref    ib_golin,ib_gost,ib_nxnon,ib_st1,ib_stbas,ib_stnxl

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_token'

        section ib_error

* Set up continue line number, etc., for present line.

ib_pserr
        tst.b   bv_sing(a6)
        sne     d1
        ext.w   d1              if single line command, no restart
        or.w    bv_linum(a6),d1 otherwise, possible restart from here
        move.w  d1,bv_cnlno(a6)
        move.b  bv_stmnt(a6),bv_cnstm(a6)
        move.b  bv_inlin(a6),bv_cninl(a6)
        move.w  bv_index(a6),bv_cnind(a6)
        move.l  bv_rtp(a6),d1   check whether there's anything on the
        sub.l   bv_rtbas(a6),d1 return stack, and if so
        sne     bv_unrvl(a6)    then tell world we want to unravel it
        rts

* Report errors during parsing

ib_ernol
        st      bv_sing(a6)     pretend single line
        moveq   #err.bl,d1      trap parsing error
        cmp.l   d1,d0
        beq.s   not_when

* Deal with general errors - reports them using ut_err if appropriate, and also
* implements when error trapping.

ib_error
        moveq   #err.nc,d1      trap break
        cmp.l   d1,d0
        beq.s   not_when
        bsr.s   q_save          if already doing a when, doesn't come back
        move.w  bv_linum(a6),bv_erlin(a6) save line number
        move.b  bv_stmnt(a6),bv_erstm(a6) save statement (new - lwr)
        move.l  d0,bv_error(a6) and error number
        bge.s   m1_rts
        move.w  bv_wrlno(a6),d4 is there a when to do?
        beq.s   errep           nope
        st      bv_wherr(a6)    set when_error flag on
        jsr     ib_stbas(pc)    to set a4
        jsr     ib_golin(pc)    set when line
        jsr     ib_stnxl(pc)
        beq.s   is_when         still a line there, go set if it's got when
un_when
        clr.w   bv_wrlno(a6)    turn when processing completely off
        sf      bv_wherr(a6)
        move.l  bv_error(a6),d0 get back error number
        bra.s   errep

* A common test, so make it clever

q_save
        tst.b   bv_wherr(a6)    are we doing a when already ?
        beq.s   ib_pserr        no - save status and return
        addq.l  #4,sp           discard return
        bsr.s   errep           report the error
        clr.b   bv_wherr(a6)    clear when processing flag
        moveq   #err.wh,d0      complain we were doing when at the time!
err_mess
        jsr     ut_err(pc)      print the error message
m1_rts
        moveq   #-1,d0
        rts

* The order of checking here used to disallow constructs like:
*               IF traperrors:WHEN ERRor: ...
* I.e. it didn't like inline when clauses that didn't start at the start of
* the line. It now permits them. lwr

is_when
        move.b  bv_wrstm(a6),d4
        jsr     ib_gost(pc)     and statement
        jsr     ib_nxnon(pc)
        cmp.w   #w.when,d1      finally check this is still a when line
        bne.s   un_when         it isn't. (How on earth did that happen!)
        move.b  bv_wrinl(a6),bv_inlin(a6)
        jmp     ib_st1(pc)      and carry on from there

* Entrypoint for dealing with break reporting - puts err.nc in d0,
* then reports error as ib_error, except ignoring WHEN ERRor status.

ib_errnc
        moveq   #err.nc,d0      not complete
not_when
        bsr.s   q_save          if already doing a WHEN, doesn't come back
errep
        move.l  bv_chbas(a6),a0 pos of command channel block
        move.l  0(a6,a0.l),a0   channel id #0
        move.w  #-1,bv_nxlin(a6) don't run when we go back
        tst.b   bv_sing(a6)     is there a line number?
        bne.s   err_mess        no
* Note: ib_errep used to include the above 3 lines... wrongly, I believe (lwr)
* By taking them out, we now can find out not only the last error that
* occured, but also where it was, by just asking for report.
        move.l  bv_linum(a6),d3 get line number to msw
        move.b  bv_stmnt(a6),d3 get statement to lsb

* Reports an error, using ut_err, showing line number if appropriate.
* Also prints the statement number now! lwr
* Also now takes line and statement as parameters, to avoid fiddling about.
* Finally, usage of the BF area is avoided by employing the stack instead.
* Note: the longest string we construct is "-32768;255 ", i.e 11 chars.

* a0 -i  - channel to write to (set in bp_report)
* d0 -i  - error number
* d3 -i  - msw error line, lsb error statement (actually stmt stays)
* d1-d2 destroyed (a1/a5 no longer smashed. lwr)

ib_errep
        movem.l d0-d3/a1,-(sp)  save error number, 8 junk, line/statement & a1
        moveq   #err.at,d0      say "at line "
        bsr.s   err_mess
        subq.l  #8,sp           68020 compatible...
        movem.l a6-a7,(sp)      ... snapshot of a6/a7
        moveq   #12,d2
        sub.l   (sp)+,d2
        add.l   (sp),d2         construct offset to buffer on stack
        move.l  a0,(sp)         leave channel id for later
        move.l  d2,a0           where to put the string
        lea     8(a0),a1        where we have the line/statement
        sf      2(a6,a1.l)      zero out top byte of statement
        moveq   #';',d3         delimit with a semicolon
        bsr.s   numlin          put line number and semicolon in buffer
        bsr.s   numstm          put statement and whatever in buffer
        move.l  d2,a1           where to print from
        move.w  a0,d2
        sub.w   a1,d2           length of text
        move.l  (sp)+,a0
        moveq   #io.sstrg,d0    send it
        moveq   #-1,d3
        trap    #4
        trap    #3
        movem.l (sp)+,d0-d3/a1  restore err number and a1, rest is junk
        bra.s   err_mess        go say it

numstm
        moveq   #' ',d3         trailing space
        tst.b   (sp)            are we actually going to say anything?
        bmi.s   numlin
        moveq   #10,d3          no - make it finish there!
numlin
        jsr     cn_itod(pc)     put number in the buffer
        move.b  d3,0(a6,a0.l)   put trailing character
        addq.l  #1,a0           move past extra character
        rts

        end
