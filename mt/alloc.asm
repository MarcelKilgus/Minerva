* Manager trap entries to the memory management system
        xdef    mt_alloc,mt_lnkfr,mt_alchp,mt_rechp
        xdef    mt_alres,mt_reres,mt_albas,mt_rebas

        xref    mm_alloc,mm_lnkfr,mm_alchp,mm_rechp
        xref    mm_altrn,mm_retrn,mm_mdbas,mm_whtrn,mm_gotrn,mm_mvjob
        xref    ss_jobx,ss_noer,ss_rte

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_assert'

bv..int equ     6       jb_rela6 flag that tells us if it's an interpreter

        section mt_alloc

* d0 -  o- error code
* d1 -i o- space to be allocated / actual space allocated
* a0 -i o- rel a6 pointer to free space pointer / rel a6 base of area allocated
* a6 -ip - base address
* d2-d3/a1-a2 destroyed

mt_alloc
        add.l   8(sp),a0        make a0 absolute
        jsr     mm_alloc(pc)
        sub.l   8(sp),a0        make a0 relative
        bra.s   rte1

* d1 -i  - length of space to be freed
* a0 -i  - rel a6 base of new area to be freed
* a1 -i  - rel a6 pointer to pointer to free space
* a6 -ip - base address
* d2/a2-a2 destroyed

mt_lnkfr
        add.l   8(sp),a0        make a0 absolute
        add.l   8(sp),a1        make a1 absolute
        jsr     mm_lnkfr(pc)
rte1
        jmp     ss_rte(pc)

* d0 -  o- error code
* d1 -i o- bytes required / bytes allocated
* d2 -i  - owner job id (-1 for self)
* a0 -  o- address of area allocated, after the heap header

dropres
        jsr     mm_retrn(pc)    give back failed job 0 respr
        move.l  d7,d1           restore size
mychp
        moveq   #-1,d2          allocate to self
mt_alchp
        moveq   #err.bp,d0      could we be in for a shock?
        move.l  d1,d7           save requested length
        bmi.s   rte1            if negative, this is silly!
        bne.s   sensible
        moveq   #8,d7           zero's pretty lunatic too... make it minimum
sensible
        move.l  d2,d1           put job number in expected hole
        jsr     ss_jobx(pc)     does job exist?
        exg     d1,d7           get back length and save job number for later
        moveq   #hp_end,d2      include space for heap header
        add.l   d2,d1
        jsr     mm_alchp(pc)    allocate space
        bne.s   rte1
        addq.l  #hp_drivr,a0
        move.l  sv_chtop(a6),(a0)+ set 'driver' (mm_rechp ptr is at this + $c)
        assert  hp_drivr,hp_owner-4
        move.l  d7,(a0)         set owner (flag address already cleared)
        addq.l  #hp_end-hp_owner,a0 move past heap header header
        bra.s   noer

* d0 -  o- 0
* a0 -i  - base of area to be freed, after heap header

mt_rechp
        lea     -hp_end(a0),a0  backspace pointer to true start of entry
        jsr     mm_rechp(pc)
        bra.s   noer

* d0 -  o- error code
* d1 -i o- number of bytes required, rounded up to a multiple of 16
* a0 -  o- base address of area allocated
* d2-d3/a1-a3 destroyed (except when d1 is zero)

mt_alres
        move.l  sv_respr(a6),a0
        move.l  d1,d7           any space to be allocated?
        ble.s   noer            no, just tell caller where respr starts
        bsr.s   basptr
        cmp.l   sv_jbbas(a6),a3 who's actually asking for the memory?
        bne.s   mychp           if not job 0, get the space from the chp
        jsr     mm_altrn(pc)    allocate area, temporarily in transient area
        bne.s   rte2            no space - too bad
        move.l  sv_respr(a6),a1
        sub.l   d1,a1
        cmp.l   a0,a1           have we got the space right at the top?
        bgt.s   dropres         no - throw it away, then try chp
        bne.s   noer            if even higher, assume extra memory linked in!
        move.l  a0,sv_respr(a6) set bottom of resident proc area
noer
        jmp     ss_noer(pc)

* N.B. This functional mt.reres version always succeeds! I can't think of any
* reason why it should fail. If the transient area is empty, sb moves up to
* the top of memory. If the transient area is not empty, extra space goes to
* it. If any extensions are present, the system crashes... but we knew that!
* As previous incarnations never worked, I suspect it might be an idea to
* allow the caller to specify (in d1.l) how much to release.

* d0 -  o- 0
* d1-d3/a0-a3 destroyed

mt_reres
        assert  sv_respr,sv_ramt-4
        movem.l sv_respr(a6),a0-a1
        move.l  a1,d7
        sub.l   a0,d7           size of resident area
        beq.s   noer            if nothing there, forget it!
        move.l  a1,sv_respr(a6) junk resident area
        move.l  d7,(a0)         make resident area look like a transient slot
retrn
        jsr     mm_retrn(pc)    return space to transient area
endreb
        move.l  d7,d1
        bra.s   noer

* The criterion applied for the albas/rebas calls has to be a bit finicky.
* The "grabber" technique for limiting the amount of memory taken up by a job
* involves the pretty dirty trick of allocating the space to job zero, letting
* the job get under way, then releasing the space.
* Unhappily, all the slave blocks get cleaned out in the process!
* There is, unfortunately, no other way to acheive the desired effect, as the
* job may acquire its space from both the common heap and the transient area,
* and job 0 is the only area that can shuffle about to accomodate both.

* ccr-  o- non-zero iff caller is a multibasic job
* a1 -  o- job table entry address of current job
* a2 -  o- header address of current job

basptr
        move.l  sv_jbpnt(a6),a3 get current job entry pointer
        move.l  (a3),a1         get current job's header address
        cmp.l   sv_jbbas(a6),a3 is this really job 0?
        beq.s   rts0            yes - return ccr = z
        btst    #bv..int,jb_rela6(a1) only multibasic tasks return non-zero ccr
rts0
        rts

* d1 -i o- space to be taken off top of interpreter job / actual space removed
* a6 -i o- base address
* a7 -i o- user stack pointer
* d0/d2-d3/a0-a3 destroyed

mt_rebas
        move.l  d1,d7           hold on to space being released
        beq.s   rte2            do nothing if space released is zero
        bsr.s   basptr
        bne.s   rebas           caller is a multibasic task - go handle it
        lea     sv_trnsp(a6),a2
        move.l  (a2),a0
        sub.l   d1,a0           new top of job 0
        move.l  d1,(a0)         make tail end look like an in-use trn bit
        move.l  a0,(a2)         now trn moves down
retrn1
        bra.s   retrn           release the spare bit (it might coalesce)

rebas
        move.l  a1,a0
        add.l   (a1),a0         current top of job
        sub.l   d1,a0           new top of job
        move.l  d1,(a0)         make tail end look like an in-use trn bit
        sub.l   d1,(a1)         now we're shorter
        jsr     mm_retrn(pc)    release it
        bsr.s   basptr
        move.l  (a1),d1         get our new length
        jsr     mm_whtrn(pc)    is there somewhere else we could go?
        beq.s   endreb          no - leave that as it is
        jsr     mm_gotrn(pc)    yes - take it
        bra.s   moveme          go move there

* d1 -i o- space to be added to top of interpreter job / actual space added
* a6 -i o- base address
* a7 -i o- user stack pointer
* d0/d2-d3/a0-a3 destroyed

mt_albas
        bsr.s   basptr
        bne.s   albas           caller is a multibasic task - go handle it
        jsr     mm_mdbas(pc)    move down job 0
rte2
        jmp     ss_rte(pc)

* rats. our attempt to expand the current job's area didn't work!
givein
        move.l  d1,d7           remember the extra required
        add.l   (a1),d1         add old length to extra required
        jsr     mm_altrn(pc)
        bne.s   rte2            ouch! no memory
moveme
        bsr.s   basptr
        move.l  (a1),d1         fetch old length
        move.l  (a0),d3         we want to patch back in the new length
        jsr     mm_mvjob(pc)    move the job
        move.l  d3,(a0)         put correct length back
        move.l  a1,a0           release old position
        bra.s   retrn1

* We look here for preceeding and following free areas that we can incorporate.
* The simpler techniques were fairly awful.
* It will be clever to shuffle other basics to make space!
* We have to round up d1 same as altrn would...
* This should all be proper routines in the mm library.

albas
        subq.l  #1,d1
        or.b    #16-1,d1
        addq.l  #1,d1
        ble.s   rte2            get out if silly request
        move.l  (a1),d0
        add.l   a1,d0           top edge of current area
        moveq   #0,d2           start by showing no following spare space
        lea     sv_trnfr-hp_next(a6),a0
        sub.l   a2,a2           remember not to count trnfr as a free space!
scntrn
        move.l  a2,d7
        move.l  a0,a2
        move.l  hp_next(a0),d3
        beq.s   scnex           end of free list, so no space above us
        add.l   d3,a0
        cmp.l   d0,a0
        bcs.s   scntrn          carry on until we reach our top edge
        bne.s   scnex
        move.l  (a0),d2         if exactly on top edge, remember size as useful
scnex
* We've found any free transient space around us.
        sub.l   d1,d2           how does the space above look?
        beq.s   stealit         exact fit - go take the whole space above
        bpl.s   split           more than enough room above - take some
        move.l  d7,d3           do we have a preceeding space?
        beq.s   givein          no - can't fit job in same patch
        move.l  (a2),d3         size of preceeding piece
        add.l   a2,d3           end of preceeding bit
        cmp.l   d3,a1           is it the immediately preceeding area?
        bne.s   givein          no - once again, this patch is too small
        sub.l   a2,d3           ok, so keep this length
        add.l   d2,d3           count off how much more we needed
        bmi.s   givein          still not enough, so give up completely

* With space before, and maybe the space after, we have enough room.

        add.l   d1,d2           put back size of space above
        beq.s   joined          if there was a useful space above ...
        bsr.s   unlink          ... unlink free space at a0 pointed to from a2
joined

        move.l  a2,a0           now point at preceeding free space
        move.l  d3,(a0)         put leftover length, do we have an exact fit?
        bne.s   prevset         no - that's done
        move.l  d7,a2           we have to go back one more to unlink this
        bsr.s   unlink          unlink free space at a0 pointed to from a2
prevset

        add.l   d3,a0           new position
        move.l  d1,d3           we want this back
        move.l  (a1),d1         current size
        jsr     mm_mvjob(pc)    move the job to its new position
        bra.s   doneit          that's all folks!

unlink
        move.l  hp_next(a0),d2  get forward link
        beq.s   putit           if there's nothing beyond, just say that
        add.l   a0,d2
        sub.l   a2,d2
putit
        move.l  d2,hp_next(a2)
        rts

* We need to split the area, 'cos it's bigger than we want...
* Note that we avoid moving ourselves about the place if we don't have to.
split
        move.l  hp_next(a0),d0  get forward link
        beq.s   nosub           if it's zero, leave it
        sub.l   d1,d0           otherwise we get closer, so want a shorter link
nosub
        add.l   d1,a0           this is where the remainder goes
        move.l  d2,(a0)+        set it's length
        move.l  d0,(a0)+        set it's link
        clr.l   (a0)            and make it owned by job 0
        add.l   d1,hp_next(a2)  finally, move prior link forward
        bra.s   samepos

* By amazing coincidence, the space was just the size we wanted. take it!
stealit
        bsr.s   unlink          unlink free space at a0 pointed to from a2
samepos
        move.l  a1,a0           we haven't actually moved...
doneit
        add.l   d1,(a0)         say we've got bigger
        jmp     ss_noer(pc)     done!

        end
