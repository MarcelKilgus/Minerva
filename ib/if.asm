* Interpret IF and ELSE keywords
        xdef    ib_else,ib_if

        xref    ca_evalc
        xref    ib_chinl,ib_eos,ib_nxnon,ib_nxst

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_token'

        section ib_if

* d0 -  o- error code
* a4 -i o- pointer to program file
* d1/d3 destroyed, plus d2/a0-a1/a3/a5 for ib_if

ib_if
        move.l  a4,a0
        jsr     ca_evalc(pc)    is expression true or false?
        move.l  a0,a4
        ble.s   rts0
        tst.b   bv_inlin(a6)    is this already embedded in-line?
        bne.s   torf            yes, leave it as is
        jsr     ib_chinl(pc)    is it now an in-line IF?
        bne.s   torf            no, get on with it
        st      bv_inlin(a6)    set in-line, if it needs it
torf
        addq.l  #2,bv_rip(a6)
        move.w  0(a6,a1.l),d3   was condition non-zero?
        bne.s   okrts           yes, true, so we're ready to roll
go_eos
        jsr     ib_eos(pc)      get end of statement
        blt.s   do_eol
        addq.l  #2,a4           skip colon/THEN/ELSE
countit
        addq.b  #1,bv_stmnt(a6) increment statement on line
chk1st
        jsr     ib_nxnon(pc)    get next non-space
        cmp.b   #b.key,d0       is it a keyword?
        bne.s   go_eos          no, not interested then

        addq.l  #2,a4
        subq.b  #b.if,d1        check for IF
        beq.s   do_if
        addq.b  #b.if-b.end,d1  check for END
        beq.s   do_end
        cmp.b   #b.else-b.end,d1 check for ELSE
        bne.s   go_eos

        tst.w   d3              is this else any levels deep?
        bne.s   countit         yes, count it as a statement
        subq.l  #2,a4           ELSE needs to be seen/counted as statement end
        bra.s   okrts           end of nest, so finish

ib_else
        clr.w   d3              set nest level and find ELSE or END IF
        bra.s   countit         go count it

do_end
        jsr     ib_nxnon(pc)    what's after the END?
        cmp.w   #w.if,d1        check for END IF
        bne.s   go_eos
        dbra    d3,go_eos       up a level, and continue if still in nest
okrts
        moveq   #0,d0
rts0
        rts

do_if
        tst.b   bv_inlin(a6)    are we already doing an in-line?
        bne.s   add1            yes, add 1 to the count
        jsr     ib_chinl(pc)    is this in-line?
        beq.s   iglin           yes, start to ignore whole line
add1
        addq.w  #1,d3           add 1 to the nest level
        bra.s   go_eos

igskp
        addq.l  #2,a4           skip colon, then or else
iglin
        jsr     ib_eos(pc)      ignore this whole line
        bge.s   igskp
do_eol
        tst.b   bv_inlin(a6)    line feed, is this a single line IF?
        bne.s   okrts           yes, then we've finished
        jsr     ib_nxst(pc)     move to beginning of next statement
        bne.s   okrts           run out of file
        bra.s   chk1st

        end
