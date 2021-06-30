* Set up FOR/REP machinery
        xdef    ib_for,ib_rep

        xref    ib_chinl,ib_fend,ib_fname,ib_frnge,ib_nxnon,ib_wtest
        xref    bv_alvvz,bv_frvv

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_lpoff'
        include 'dev7_m_inc_nt'
*       include 'dev7_m_inc_token'

        section ib_for

* a4 -i o- program file, positioned on input at token after REP/FOR

ib_rep
        moveq   #t.rep,d5
        bra.s   repfor

err_bn
        moveq   #err.bn,d0      bad name (array or proc or something)
        rts

ib_for
        moveq   #t.for,d5
        move.l  a4,a5           save the position
repfor
        jsr     ib_nxnon(pc)    get next non-space
*       cmp.b   #b.nam,d0       is it a name? (i don't see why? lwr)
*       bne.s   err_bn          no, can't do it yet then
        move.w  2(a6,a4.l),d4   read row of name in name table
        addq.l  #4,a4
        jsr     ib_chinl(pc)    is this REP/FOR inline?
        blt.s   chtype          no
        move.b  #1,bv_inlin(a6) yes, set flag
        move.w  d4,bv_index(a6) (ought to check for absence of ef first)
chtype
        jsr     ib_fname(pc)    move to beginning of name
        clr.w   d2              clear first two bytes
        moveq   #0,d3           clear last four bytes
        move.b  0(a6,a2.l),d2   read type of name (1st byte of type word)
        beq.s   alloc           unset variable, just zoom in there
        cmp.b   d2,d5           is it what we want already?
        beq.s   sametype        yes, just right
        moveq   #lp.lnfor,d1
        subq.b  #t.for,d2       is it a FOR?
        beq.s   freevar         yes, chuck it
        moveq   #lp.lnrep,d1
        addq.b  #t.for-t.rep,d2 is it a REP?
        beq.s   freevar         yes, chuck it
        addq.b  #t.rep-t.var,d2 is it a simple variable?
        bne.s   err_bn          no, we don't like it!
        moveq   #lp.lnvar,d1    almost the right length
freevar
        move.l  4(a6,a2.l),d0   offset on VV area of index
        blt.s   alloc           space not yet allocated
        move.l  bv_vvbas(a6),a0 free current space, point at it
        add.l   d0,a0
        move.w  0(a6,a0.l),d2
        move.l  2(a6,a0.l),d3
        cmp.w   #t.var<<8!t.fp,0(a6,a2.l) is it a simple string?
        bcc.s   freenow         no, go free it as is
        move.w  d2,d1           get current length
        subq.l  #4,d1           is it a bit on the long side?
        ble.s   lenok           no - leave it
        sub.w   d1,d2           yes - truncate the save length to four
* This truncation idea is a right pain! It really should count as an assignment
* to the variable, and cause when processing to happen. However, if you look at
* what's got to be done to implement that, you find it's pretty horrendous.
* Anyway, the only occasion where it crops up as a problem is when it's an
* exhausted FOR or a REP. The user will have to tolerate it, I think.
lenok
        addq.l  #4+2,d1         this will round up right to free old string
freenow
        jsr     bv_frvv(pc)     and free
alloc
        move.l  d5,d1
        subq.b  #5,d1
        lsl.w   #3+1,d1
        assert  (t.rep-5)<<1 (lp.lnrep+7)>>3
        assert  (t.for-5)<<1 (lp.lnfor+7)>>3
        jsr     bv_alvvz(pc)    find a hole to put index description in
        move.w  d2,0(a6,a0.l)   copy var. value to new position
        move.l  d3,2(a6,a0.l)
        sub.l   bv_vvbas(a6),a0 get the offset
        move.b  d5,0(a6,a2.l)   set type to what we want
        move.l  a0,4(a6,a2.l)   update the vv offset in loop description
sametype

        move.l  4(a6,a2.l),a2   get offset on vv table
        add.l   bv_vvbas(a6),a2 add to base of vv
        move.w  bv_linum(a6),d1 read current line number
        move.b  bv_stmnt(a6),d0 also check the statement number on line
        cmp.w   lp.sl(a6,a2.l),d1 is it same as prev loop for this index?
        bne.s   fill            no
        cmp.b   lp.ss(a6,a2.l),d0
        beq.s   nofill          scuse'me, don't change a thing
fill
        move.w  d1,lp.sl(a6,a2.l) fill in the line number
        clr.l   lp.el(a6,a2.l) blank the rest of the loop description
        move.b  d0,lp.ss(a6,a2.l) except for which statement number
nofill
        subq.b  #t.for,d5       are we doing a FOR?
        bne.s   okrts           no - then that's all folks!
        jsr     ib_nxnon(pc)    get the =
        move.l  a4,d0           current pos
        sub.l   a5,d0           minus for pos = no of chars
        move.w  d0,lp.chpos(a6,a2.l) fill in char pos at this moment
        jsr     ib_frnge(pc)    read the range
        bgt.l   ib_fend         FOR line exhausted already, look for an END FOR
        blt.s   rts1            in case we had a problem
        tst.w   bv_wvnum(a6)    any when vars. that might be altered?
        bne.l   ib_wtest        yes - if satisfies when var. cond., act
okrts
        moveq   #0,d0
rts1
        rts

        end
