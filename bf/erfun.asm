* Error functions
        xdef    bf_erlin,bf_ernum,bf_fllin + bf_errxx from macro

        xref    bv_chri,ri_fllin

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'

bf_err macro
i setnum [.nparms]
l maclab
        assert -[i],err.[.parm([i])]
t setstr bf_err[.parm([i])]
        xdef    [t]
[t]
        addq.b  #1,d7
i setnum [i]-1
 ifnum [i] <> 0 goto l
 endm

        section bf_erfun

        bf_err  nc nj om or bo no nf ex iu ef df bn te ff bp fe xp ov ni ro bl
        add.l   bv_error(a6),d7 is it the right error?
        beq.s   true
        sub.l   d7,d7           yipe! I made this moveq, and X was left set!
true
        addx.b  d7,d7
        bra.s   numlin

bf_erlin
        move.w  bv_erlin(a6),d7 should always be positive
        bra.s   numlin

bf_ernum
        move.l  bv_error(a6),d7 bv_error is long, get it right!
numlin
        moveq   #err.bp,d0
        cmp.l   a3,a5           shouldn't be any parameters
        bne.s   rts0
        jsr     bv_chri(pc)     make sure enough room on stack
        move.l  bv_rip(a6),a1   where to put 
        subq.l  #2,a1           space for an integer
        move.w  d7,0(a6,a1.l)
        moveq   #t.int,d4
        move.l  d7,d1
        ext.l   d7
        cmp.l   d7,d1
        beq.s   setrip
        addq.l  #2,a1
bf_fllin
        jsr     ri_fllin(pc)    should rarely happen!
        moveq   #t.fp,d4
setrip
        move.l  a1,bv_rip(a6)   save a1
        moveq   #0,d0           no errors
rts0
        rts

        end
