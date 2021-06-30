* RENUM: renumber a program file (also handles AUTO and EDIT)
        xdef    bp_auto,bp_edit,bp_renum

        xref    bp_chunr,bp_gint,bp_gsep,bp_listr
        xref    bv_alvv,bv_chpfx,bv_frvv,bv_uprnm
        xref    ib_cheos,ib_glin0,ib_nxcom,ib_nxnon,ib_nxst,ib_nxtk
        xref    ib_stbas,ib_whrnm
        xref    mm_mrtor
        xref    ri_float,ri_nint

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_token'
        include 'dev7_m_inc_assert'

        section bp_renum

bp_auto
        moveq   #10,d7          default increment is 10 for auto
bp_edit         ;               default increment zero for edit
        moveq   #-1,d6          flag edit/auto by having all 1's in last line
        bra.s   st_arg

bp_renum
        moveq   #10,d7          default steps of 10 for renumber
        moveq   #-2,d6          flag renum by having a zero lsb.
st_arg
        jsr     bp_chunr(pc)    make sure we're allowed to

* First get the arguments. d7 = renumber/edit step, d6 = -1, or -2 for RENUM

        move.l  a5,-(sp)        if all else fails, renumber from top
        move.l  d7,-(sp)        save default step at 2(sp)
        moveq   #100,d7         default starting renumber/edit from 100
        ror.w   #1,d6           form 32767 (max line number) for renum
        bmi.s   ch_num          auto/edit - just go for " {start} {,step} "

* RENUM has optional range first: "{ {first} to {last} }" or "{first/last} ;"

        moveq   #1,d4           first line
        bsr.s   get_arg         get arg and its separator
        cmp.b   #b.septo,d5     " {first} to ... " ?
        bne.s   s_semi
        tst.b   d0              " first to ... " ?
        bne.s   ch_last
        move.w  d1,d4           yes, set first line
ch_last
        bsr.s   get_arg         get another arg, is it " ... to last ... " ?
        bne.s   to_set
        move.w  d1,d6           yes, set last line
to_set
        cmp.b   #b.semi,d5      " {first} to {last} ; ... " ?
        beq.s   ch_num          yes, go get start line
        bra.s   ch_sep          no, go see if final " , {step} " is present

get_arg
        moveq   #0,d5
        cmp.l   8(sp),a3        any args left?
        beq.s   null_arg
        jsr     bp_gsep(pc)     get separator & see if there's an arg
        beq.s   null_arg
        jsr     bp_gint(pc)     get an integer arg > 0
        beq.s   rts0
        addq.l  #4,sp           skip this return
        bra.s   pop8            and complain

null_arg
        moveq   #1,d0
rts0
        rts

s_semi
        cmp.b   #b.semi,d5      " {first/last=only} ; " ?
        bne.s   s_com
        tst.b   d0
        bne.s   ch_num
        move.w  d1,d4           set 1st line
        move.w  d1,d6           set last line

* All can have now is " ... {start} { , {step} } "
ch_num
        bsr.s   get_arg
s_com
        tst.b   d0
        bne.s   ch_sep
        move.w  d1,d7           set new start line
ch_sep
        cmp.b   #b.sepcom,d5
        bne.s   no_sep
        bsr.s   get_arg
        bne.s   no_sep
        move.l  d1,(sp)         overwrite step size at 2(sp)
no_sep
        moveq   #err.bp,d0      in case they try to sneak sommat funny past us!
        subq.l  #1,d5
        bcc.s   pop8            ok if no separator left, and set d5.l=-1
* d7.l = start line to edit or renumber to
* 2(sp).w = step for edit or renumber range
        move.w  d7,(sp)         form start/step on stack at (sp) and 2(sp)
        ext.l   d6              what are we doing? (clear msw if renum)
        bpl.s   renum
        assert  bv_edlin,bv_edinc-2
        move.l  (sp),bv_edlin(a6) start line and increment for subsequent lines
        st      bv_auto(a6)     set auto/edit flag for unvrs
exit
        moveq   #0,d0
pop8
        addq.l  #8,sp
        rts

* Now check that all is OK for renumbering

* d4.l = first line in old range to be renumbered
* d5.l = -1
* d6.l = last line in old range to be renumbered
* d7.l = first line in new renumbered range
* (sp).w = also first line in renumbered range
* 2(sp).w = step for renumbered range

renum
        jsr     ib_glin0(pc)    goto the start line
        ble.s   exit            not in program - that requires no work!
        move.l  a4,a3           duplicate pointer
        cmp.l   d0,a4
        ble.s   preok           no check if at start, and d5=-1 is ok
        sub.w   d1,a4
        cmp.w   4(a6,a4.l),d7   check that new start > previous lno
        ble.s   pop_or          we could allow renumber of no lines through...
        sub.w   4(a6,a4.l),d5   we need pre-start lno plus one - this negated
        add.w   d1,a4
preok

* Establish how many lines in range, and get a final, out-of-range line number
        move.w  d1,d4           duplicate length+2
        moveq   #-1,d3
countup
        move.w  4(a6,a3.l),d0   get line number
        cmp.w   d0,d6           have we gone past end of range?
        blt.s   counted         yes - we're ready
        addq.l  #1,d3           counting lines after 1st line in range
        add.w   0(a6,a3.l),d1   adjust length
        add.w   d1,a3           and move to the end
        cmp.l   d2,a3
        blt.s   countup
* Note: we have one problem that we must avoid. If there is not yet a line
* number 32767, we cannot allow renumbering to produce one, in case there exist
* references to beyond the last line actually present!
        addq.w  #1,d0           check if genuine line 32767 was present
        bmi.s   counted         yes! leave with 32768 as pseudo end line
        move.w  #32767,d0       pretend post-range lno is max possible lno
counted
        move.w  d0,d6           now we have the first line above range ready
        move.l  (sp),d2         step in lsw
        muls    d3,d2           * ( lines - 1 )
        bmi.s   exit            if there were no lines in range, exit ok!
        add.l   d7,d2           + start line = new number for last line
        cmp.l   d6,d2           check renumbered end < post range line number
        blt.s   ready           good stuff, now we can get on!
pop_or
        moveq   #err.or,d0
        bra.s   pop8            go report out-of-range

ready
        move.l  (sp),d7         more convenient later to keep start/step in d7
 
* We are now fully prepared to start actioning the renum

* Some (rambling) implementation notes:
* We can keep d5-d7 and a-regs except a1 preserved while we actually do the
* program renumbering (plus a4 is program pointer).
* It does not matter if we include the post lno in the renumber, but all is
* much nicer if we don't include it!
* The range of the renumber contains just pre+1 to post-1 inclusive.
* We want a fast compare by "move (),ds:sub.w dy,ds:add.w dx,ds:bcc.s done".
* So we must get a value 0..post-(pre+1)-1 in ds after the comparison.
* So we want post-(pre+1) and post for dx/dy. We'll use d5=dx and d6=dy.
* We need post and lastreal-(pre+1) so we can renumber final set.
* We only need table entries for the comparisons we need to make.
* Table entry "-1" is a pseudo zero, so they must have (pre+1) knocked off.
* Last table entry will be lastreal-(pre+1), used only for final set.
* Total table comparison words needed is number of real lines.
* Need table base and top, for which we'll use a0/a3.
* Need start, step for renumbering all but last set in range (in d7 now).

* d3.l lines in range less one (i.e. 0 if single line)
* d4.w length of line at a4, plus 2 for effeciency
* d5.l (-ve) pre-range line number plus one (i.e. first line ref to be altered)
* d6.l post range line number (may be real line or pseudo 32767/8)
* d7.msw start line for renumbered range
* d7.lsw step for renumber line

* Allocate table, then fill it in as we renumber lines in the range.
* Minimal table (for single line renumber) will contain just 1 word (plus w/s).
* We're using a VV area, so called routines shouldn't be too restricted.
* Also, using space there is probably not causing the VV area to expand
* unneccessarily, as the space used will be proportionate to the size of the
* program, and, assume that does do some work, it'll probably need variables!
* Finally, at least CLEAR will wipe the VV area if it's called later on.

ren.ws  equ     6*2             workspace used as RI type stack at top of table

        moveq   #1+ren.ws/2,d1  we need one line, plus the workspace.
        add.l   d3,d1
        add.l   d1,d1           * 2 = no bytes needed in table
        jsr     bv_alvv(pc)     allocate the space
        move.l  a0,a3           copy table base
nx_lno
        move.w  4(a6,a4.l),d2   get old lno
        add.w   d5,d2           adjust to what we want in table
        move.w  d2,0(a6,a3.l)   store old line number less (pre+1)
        move.w  (sp),4(a6,a4.l) edit program to new line number
        add.w   d7,(sp)         update new line number
        add.w   0(a6,a4.l),d4   adjust length
        add.w   d4,a4           and move to the end
        addq.l  #2,a3           next table entry
        dbra    d3,nx_lno       we now know exactly how many lines we're doing
        add.l   d6,d5           now we have post-(pre+1), as we wish for
        lea     get_new,a2      address of renumber routine

* Notes:
* d5-d7/a0/a2-a3 must be preserved for the renumber routine.
* a2 is the address of the renumber routine.
* The when and uproc routines may use d4 and a5 as they wish.
* On calling the routine at a2, they must supply d5-d7/a0/a3 as given to them.
* They must set a1 as the rel-a6 pointer to the word containing the line number
* to be adjusted. a1 is preserved.
* If the line is renumbered, its new value is returned in d0.l (1-32767).
* If the line is not renumbered, d0.l returns with zero.
* The condition code on return is the result of testing d0.l, in effect.
* d1-d3 will be destroyed.

* N.B. d0-d4/a1 variously zapped in the following

        tst.b   bv_uproc(a6)    is there a user trace procedure?
        bpl.s   noup
        jsr     bv_uprnm(pc)    yes - go see to it
noup
        jsr     ib_whrnm(pc)    go let when do it's checks
        jsr     ib_stbas(pc)
        bra.s   on_line         go start a new line

st_1
        tst.b   d0
        beq.s   on_stmt
on_line
        move.l  a4,(sp)         save marker for start of line, in case shi->lgi
on_stmt
        bsr.s   nxnon           get 1st token in statement
        sub.w   #w.go,d1
        beq.s   skip_go         if go, skip it
        subq.w  #w.rstr-w.go,d1
        beq.s   ch_fp           go skip restore and look for fp
        subq.w  #w.on-w.rstr,d1
        bne.s   nx_stmnt        if not on, try again
nx_token
        jsr     ib_nxtk(pc)     get next token
        bsr.s   noncheos        skip spaces & check for end-statement
        beq.s   nx_stmnt
        cmp.w   #w.go,d1
        bne.s   nx_token        if not go, go get next token
skip_go
        bsr.s   skpnonc         skip go, get to/sub
ch_fp
        bsr.s   skpnonc         get 1st token of expression, checking for eos
        beq.s   nx_stmnt
        sub.b   #b.lgi,d0       long integers are lovely, and most frequent
        bne.s   others
        lea     2(a4),a1
        jsr     (a2)
nx_exp
        jsr     ib_nxcom(pc)    get a comma not inside ()'s
        bne.s   ch_fp           ok, check the first token
nx_stmnt
        jsr     ib_nxst(pc)     get start of next statement
        beq.s   st_1
        bra.s   tidy_up

skpnonc
        addq.l  #2,a4           skip over word token
noncheos
        pea     ib_cheos(pc)    check end-of-statement after nxnon
nxnon
        jmp     ib_nxnon(pc)

others
        lea     6(a3),a1        use RI-type workspace at top of table
        addq.b  #b.lgi-b.shi,d0 short integers are a pain! they may not fit!
        beq.s   doshi           changing lgi/shi both ways needs PF reshuffle!
        sub.w   #$f000,d1       float needs some fiddling
        bcs.s   nx_exp          anything else, we'll skip, cos we're dumb
        move.w  d1,0(a6,a1.l)   put on exponent
        move.l  2(a6,a4.l),2(a6,a1.l) put on mantissa
        jsr     ri_nint(pc)     convert it to an integer line number
        bne.s   nx_exp          didn't convert, so ignore it
        jsr     (a2)            give the current number and get new one
        beq.s   nx_exp          not renumbered, so leave original unchanged
        jsr     ri_float(pc)
        movem.w 0(a6,a1.l),d0-d2 get new fp
        or.w    #$f000,d0       insert token into exponent
        movem.w d0-d2,0(a6,a4.l) replace fp
nx_exp2
        bra.s   nx_exp

tidy_up
        addq.l  #8,sp           we're finished with the stacked values
        st      bv_cont(a6)     because nxst will have set stop
        st      bv_edit(a6)     say the program has changed

* Finally, tidy up all line numbers in bv area, and relist

        movem.l bv_lnbas(a6),a1/a5 get line number table pointers
        bra.s   lnent           enter loop at end

* This is the naff one... renumbering a short integer
doshi
        ext.w   d1
        move.w  d1,0(a6,a1.l)   put on word value
        jsr     (a2)            give the current number and get new one
        beq.s   nx_exp          not renumbered, so leave original unchanged
        move.b  d0,1(a6,a4.l)   replace value, we hope
        cmp.w   #128,d0         does it still fit?
        bcs.s   nx_exp          yes - great
* Disaster time... we can't fit the new line number in. We have to move the
* program. We don't like this, but we have had complaints. This is pretty much
* guaranteed to work, assuming that we have managed to save the right amount of
* info. I don't think it's going to be a major disaster, provided someone is
* not lunatic enough to have a RENUM inside their program code!
* If we get an out of memory error, it's a total disaster.
        sub.l   a0,a3
        sub.l   bv_vvbas(a6),a0 protect our table pointers
        moveq   #2,d1           one extra word needed
        jsr     bv_chpfx(pc)    we hope this does nothing...
        add.l   bv_vvbas(a6),a0 restore our table pointers
        add.l   a0,a3
        move.l  (sp),a1         get marker for start of line
        addq.w  #2,bv_lengt(a6) this line will get longer
        addq.w  #2,-6(a6,a1.l)  its pre-word goes up
        add.w   bv_lengt(a6),a1 step to end of line (includes pre-word)
        subq.w  #2,-6(a6,a1.l)  next pre-word (or word past pfp) goes down
        move.l  a4,a1           source (include token, to save a word)
        move.l  a0,-(sp)        save table base
        lea     2(a1),a0        destination
        move.l  bv_pfp(a6),d1   top of program
        addq.l  #2,bv_pfp(a6)   it's growing
        sub.l   a1,d1           total length
        jsr     mm_mrtor(pc)    shuffle the whole damn thing up        
        move.l  (sp)+,a0
        addq.b  #b.lgi-b.shi,0(a6,a4.l) change token to long integer
        ; N.B. we've left the lsb with junk, instead of the "official" zero.
        ; This shouldn't be a problem, and a SAVE/LOAD is a good idea anyway.
        move.w  6(a6,a3.l),2(a6,a4.l) put new line number
        bra.s   nx_exp2

* Finishing off bits
lnloop
        jsr     (a2)
        addq.l  #4,a1
lnent
        cmp.l   a1,a5
        bgt.s   lnloop

        lea     bvtab,a5        miscellaneous variables
        moveq   #bv_linum,d0    start with this one
newlp
        move.w  d0,a1
        jsr     (a2)            renumber it
        moveq   #0,d0
        move.b  (a5)+,d0
        bne.s   newlp

        moveq   #ren.ws,d1
        add.l   a3,d1
        sub.l   a0,d1           amount to free
        jsr     bv_frvv(pc)
        jsr     bp_listr(pc)    relist the current window
okrts
        moveq   #0,d0
        rts


* Renumbering subroutine

* d0 -  o- new line number value at 0(a6,a1.l), or zero if not changed.
* d5 -ip - post lno - (pre+1)
* d6 -ip - post lno
* d7 -ip - start/step for renumbered line numbers
* a0 -ip - base of table
* a1 -i o- rel a6 pointer to line number to examine
* a3 -ip - top of table
* ccr-  o- zero if line not renumbered or positive if it was
* d1-d3 destroyed

* 0(a6,a0.l) first, or only, real lno of renumber range, less (pre+1)
* -2(a6,a3.l) last, or only, real lno of renumber range, less (pre+1)

get_new
        move.w  0(a6,a1.l),d3   get line number there
        sub.w   d6,d3           subtract post-lno, which is out of the range
        add.w   d5,d3           add line range: post-lno less pre-lno less one
        bcc.s   okrts           not in range, go say we didn't change this one
        move.w  d6,d0           lines above last renumber to post-lno
        cmp.w   -2(a6,a3.l),d3  are we matching the last+1 to post-1 range?
        bhi.s   lkput           yes, we've finished, so go put new number
        move.l  a0,d1           lower limit (may stop here)
        move.l  a3,d2           upper limit (never stop here)
lkup
        addq.l  #2,d1           round up this time
        move.l  d1,d0           set new low limit
        cmp.l   d0,d2           is there still more than one entry to check?
        ble.s   lklast          no, so we finish at this, or the earlier one
        add.l   d2,d1
lkchop
        lsr.l   #2,d1           lose lsb's
        add.l   d1,d1           middle, rounded
        cmp.w   -2(a6,d1.l),d3
        bhi.s   lkup            search > entry, so we can move low limit
lkent
        subq.l  #2,d1           search <= entry, so never look there again
        move.l  d1,d2           save upper limit which may still work
        add.l   d0,d1
        cmp.l   d0,d2           ah! but what is left in the range?
        bgt.s   lkchop          more than one, so keep chopping
lklast
        bne.s   lkback          if range exhasted, must want earlier one
        cmp.w   -2(a6,d0.l),d3  final, single compare
        bhi.s   lkok            search > entry, so this is the one
lkback
        subq.l  #2,d0           back up to final one that worked
* We have {-2(a6,d0.l)} < d3 <= 0(a6,d0.l), therefore...
lkok
        sub.w   a0,d0
        lsr.w   #1,d0
        mulu    d7,d0
        swap    d7
        add.w   d7,d0           calculate new lno
        swap    d7
lkput
        move.w  d0,0(a6,a1.l)
        rts

               ;bv_linum done at start
bvtab   dc.b    bv_nxlin,bv_cnlno,bv_dalno,bv_lsbef,bv_lsbas,bv_lsaft
        dc.b    bv_edlin,bv_lsfil,bv_erlin,0 (bv_wrlno already done)
*       Note: only some of these used to be done... some are almost certainly
*       irrelevant... but adding dalno was really needed!

        end
