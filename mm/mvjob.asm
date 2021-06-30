* Move basic program area
        xdef    mm_mdbas,mm_mubas,mm_mvjob

        xref    mm_altop,mm_move,mm_retop

        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_sv'

        section mm_mvjob

* d0 -  o- 0 & ccr=z
* d1 -i o- distance basic is wanted to move up. this will be rounded down.
* d3 -  o- copy of d1
* a0 -  o- pointer to new base of job 0
* a1 -  o- pointer to old base of job 0
* a5 -ip - pointer to trap level stack
* a6 -ip - pointer to system variables
* a3 destroyed

mm_mubas
        jsr     mm_retop(pc)    return space (new basic pointer in a0)
        bra.s   domove

* d0 -  o- error code -> ccr (if not zero, registers d1-d3/a0-a3 are undefined)
* d1 -i o- distance basic is wanted to move down. this will be rounded up.
* d3 -  o- copy of d1
* a0 -  o- pointer to new base of job 0
* a1 -  o- pointer to old base of job 0
* a5 -ip - pointer to trap level stack
* a6 -ip - pointer to system variables
* d2/a2-a3 destroyed

mm_mdbas
        jsr     mm_altop(pc)    allocate space (new basic pointer in a0)
        bne.s   rts0
domove
        move.l  d1,d3           hold onto d1
        move.l  sv_trnsp(a6),d1 top of basic
        move.l  sv_jbbas(a6),a3 fetch pointer to job 0 entry in job table
        sub.l   (a3),d1         number of bytes to move

* d0 -  o- 0 (and ccr=z)
* d1 -i o- size of area to be moved / value from d3
* d3 -ip - value to return in d1
* a0 -ip - new position of job
* a1 -  o- old position of job
* a3 -i  - pointer to job table entry for job to be moved

mm_mvjob
        move.l  (a3),a1         get old position of job
        move.l  a0,(a3)         set new position of job
        jsr     mm_move(pc)     move it
        move.l  a1,d0
        sub.l   a0,d0           distance travelled
        sub.l   d0,jb_a0+6*4(a0) update stored a6
        sub.l   d0,jb_a0+7*4(a0) update stored usp

* Check if this is called from job that is itself moving!!!!
* If so, we have to modify a6 which is somewhere on the stack!!!

        cmp.l   sv_jbpnt(a6),a3 is it the current job moving?
        bne.s   stk_ok
        sub.l   d0,8(a5)        update a6 on the stack
        move    usp,a3          move the stack pointer as well
        sub.l   d0,a3
        move    a3,usp
stk_ok
        move.l  d3,d1           set return value
        moveq   #0,d0
rts0
        rts

        end
