* Process WHEN stuff
        xdef    ib_whdel,ib_when,ib_whrnm,ib_whzap

        xref    ib_chinl,ib_def1,ib_eos,ib_nxnon,ib_s4non,ib_wscan,ib_wscnx
        xref    bv_frvv

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_token'
        include 'dev7_m_inc_wv'

        section ib_when

* Process WHEN keyword.
* "WHEN ERRor" sets up error trapping.
* "WHEN name{(<range>)...}=<expr>" sets up entry for name.
* "WHEN name" clears all entries for name.
* "WHEN anything" as an immediate command clears all when processing.

* Find and unset all whens on this var
uns_one
        st      wv.row(a6,a2.l) found one, unset it
        subq.w  #1,bv_wvnum(a6) and decrement count
find_uns
        moveq   #1,d3
        jsr     ib_wscan(pc)
        beq.s   uns_one
        bra.s   okrts           none left

ib_when
        tst.w   bv_linum(a6)    is this an immediate command?
        bne.s   inprog          no, so do complex activities
        tst.b   bv_wvbas(a6)    is there a when vv area?
        bmi.s   whkill          no, so don't try to release it
        move.l  bv_wvbas(a6),a0 addr. of when area rel. to vvbas
        add.l   bv_vvbas(a6),a0 made a6 rel.
        move.l  0(a6,a0.l),d1   size of when area
        jsr     bv_frvv(pc)     free area
ib_whzap
        st      bv_wvbas(a6)    mark as gone
whkill
        clr.w   bv_wrlno(a6)    immediate, so switch when error off
        clr.w   bv_wvnum(a6)    and switch off when variable
        bra.s   okrts

inprog
        jsr     ib_nxnon(pc)    what sort of when is this?
        cmp.w   #w.err,d1       when error?
        bne.s   becomes
        move.w  bv_linum(a6),bv_wrlno(a6) save line number
        move.b  bv_stmnt(a6),bv_wrstm(a6) and statement
        jsr     ib_chinl(pc)    is this inline?
        seq     bv_wrinl(a6)    if so, set flag
        beq.s   nxst
findend
        moveq   #b.when,d2      look for an "end when"
        jmp     ib_def1(pc)

colon
        addq.l  #2,a4
nxst
        jsr     ib_eos(pc)      get end of this statement
        bge.s   colon           colon, keep going
okrts
        moveq   #0,d0
        rts

becomes
        move.w  2(a6,a4.l),d4   get row number
        jsr     ib_s4non(pc)    advance pf and get next
        cmp.w   #w.opar,d1      is next an open parenthesis?
        beq.s   find_set        yes, we now allow subscripted arrays
        cmp.b   #b.ops,d0       is next thing on line an operator?
        bne.s   find_uns        no, that's all we expected, so go scrap this
find_set
        moveq   #1,d3           have we been here before?
        jsr     ib_wscan(pc)
tst_lno
        bne.s   empty_s         no, have to make an entry
        move.w  bv_linum(a6),d0
        cmp.w   wv.wlno(a6,a2.l),d0 got match on variable, lnos match too?
        beq.s   set_up          yes, replace this entry
        jsr     ib_wscnx(pc)    no, is there another one?
        bra.s   tst_lno

empty_s
        moveq   #0,d3           find an empty slot
        jsr     ib_wscan(pc)
        addq.w  #1,bv_wvnum(a6) and fill it
set_up
        move.w  d4,wv.row(a6,a2.l) set row number
        move.w  bv_linum(a6),wv.wlno(a6,a2.l) line number
        move.b  bv_stmnt(a6),wv.wstm(a6,a2.l) statement on line
        moveq   #127,d0         default endstatement
        bsr.s   setew           fill in default ew entries
        assert  wv.rtstm,wv.rtinl-1,wv.rtind-2
        move.l  d0,wv.rtstm(a6,a2.l) clear return status
        st      wv.rtlno(a6,a2.l) mark as not in use
        jsr     ib_chinl(pc)    is this an inline?
        seq     wv.inlin(a6,a2.l) set if so
        beq.s   nxst            and find end of line to continue from
        bsr.s   findend         otherwise, scull on to "end when"
        move.b  bv_stmnt(a6),d0
setew
        move.b  d0,wv.ewstm(a6,a2.l)
        move.w  bv_linum(a6),wv.ewlno(a6,a2.l) fill in the position
        bra.s   okrts

* Checks and adjustments for changes in line numbers in when area.

* Three instances crop up:
* 1) A line range has been deleted. We cannot keep any when entry which is
*       currently referencing these line, so they get discarded.
* 2) A line has been editted. As we can no longer trust it to be valid, we must
*       get rid of references as if the line had been deleted.
* 3) A renumber has occurred. All references just need to be adjusted. Their
*       contents have not altered, so entries are kept. 

* (This all used to be done with some horrible flags, etc. Turning the renum
* process around so that this calls the code back there made life much easier!)

* Zap when entries for a line range (cases 1 & 2 above)

* d2 -ip - first line number in delete range, or editted line number
* d6 -ip - last line in delete range, or repeat of editted line number
* d0/a2 destroyed

ib_whdel
        movem.l d1/d4/d6/a1/a5,-(sp)
        lea     eddel,a2
        sub.w   d2,d6
        bsr.s   ib_whrnm
        movem.l (sp)+,d1/d4/d6/a1/a5
        rts

eddel
        move.w  0(a6,a1.l),d0
        sub.w   d2,d0
        cmp.w   d6,d0
        bhi.s   rts1
        addq.l  #4,sp           discard return
delpos
        st      wv.row+4(a6,a5.l) switch off when entry
        subq.w  #1,bv_wvnum(a6) and decrement no. of when vars.
        bra.s   nextpos

* Scan when entries, executing code on each line number reference.

* See renum for details on register usage here
ib_whrnm
        lea     bv_wrlno,a1
        jsr     (a2)            renumber when error
whvar
        tst.w   bv_wvnum(a6)    are there any when var. conds. set?
        beq.s   rts1            no, so give up quickly

whmods
        move.l  bv_wvbas(a6),a5
        add.l   bv_vvbas(a6),a5 a6 rel. addr. of when var. area
        move.l  0(a6,a5.l),d4   length of when space in bytes
        lsr.l   #4,d4           hence no. of entries +1
        subq.w  #2,d4           handy loop count
del_lop
        tst.w   wv.row+4(a6,a5.l) is this entry being used?
        bmi.s   nextpos         no, so look at next one
        lea     wv.wlno+4(a5),a1 set pointer for check operation
        jsr     (a2)            perform operation on when lno (edit/renum)
        addq.l  #wv.ewlno-wv.wlno,a1
        jsr     (a2)            perform operation on end when lno (edit/renum)
        addq.l  #wv.rtlno-wv.ewlno,a1
        jsr     (a2)            perform operation on return lno (edit/renum)
nextpos
        add.w   #wv.len,a5      move to next when table entry
        dbra    d4,del_lop
rts1
        rts

        end
