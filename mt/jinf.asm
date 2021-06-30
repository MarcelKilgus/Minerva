* Information on, and deletion of, jobs
        xdef    mt_jinf,mt_rjob,mt_frjob,mt_close

        xref    mm_retrn
        xref    ss_dljob,ss_joba,ss_jobx,ss_noer,ss_rte
        xref    io_jbchk

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_assert'

        section mt_jinf

* d0 -  o- 0
* d1 -i o- job id / job id of next job in tree
* d2 -i o- job number at top of tree / job id of owner of requested job
* d3 -  o- msb status (-1 suspended) and lsb priority
* a0 -  o- base address of code of requested job (i.e. job header + jb_end)

mt_jinf
        jsr     ss_jobx(pc)     does job exist?  (sets a0)

        moveq   #0,d3
        tst.w   jb_stat(a0)     is job suspended
        beq.s   set_prio
        moveq   #-1,d3          yes - set suspended
set_prio
        move.b  jb_princ(a0),d3 set priority

        move.l  d2,d0           stop scanning at top of tree
        move.l  a0,-(sp)        save job base address
        bsr.s   tree            ... and find next job
        move.l  (sp)+,a0        restore base address of this job
        move.l  jb_owner(a0),d2 ... find owner of this job
        lea     jb_end(a0),a0   ... and base address of job

        jmp     ss_noer(pc)

* Scans a tree of jobs - one each entry

* d0 -ip - job number at top of tree (d0.w)
* d1 -i o- current job id / next job id (0 = end of tree)
* d2 -  o- id of owner of next job
* a0 -  o- base address of next job
* a1 -  o- pointer to table entry for next job

up_tree
        moveq   #0,d1           next job is 0
        cmp.w   d2,d0           are we already at top of tree?
        beq.s   rts0            yes - there are no more jobs in tree

        move.w  d2,d1           find address of owner
        bsr.s   find_add
        beq.s   rts0            silly! someone gave an invalid job as top!
        move.l  jb_owner(a0),d2 get owner of owner

next_job
        addq.w  #1,d1           next job
        cmp.w   sv_jbmax(a6),d1 is this beyond highest job number
        bgt.s   up_tree         yes - there are no daughter jobs

        bsr.s   find_add        find address of job

        tst.b   (a1)            does it exist?
        blt.s   next_job        no try another

        cmp.l   jb_owner(a0),d2 is this job owned by the right job
        bne.s   next_job        no - try another

        swap    d1              save lsw
        move.w  jb_tag(a0),d1   fetch tag
        swap    d1              full job id
rts0
        rts

tree
        move.l  d1,d2           look for job owned by this job
        moveq   #0,d1           start at beginning of table
        bra.s   next_job

find_add
        bsr.s   jbptr           go make up pointer
        move.l  (a1),a0         this is base of job itself
        rts

* d0 -  o- error flag
* d1 -i  - id of job to be removed
* d3 -i  - error code to send to any waiting jobs
* d2/a0-a3 destroyed

mt_rjob
        jsr     ss_jobx(pc)     check if job exists
        move.l  d1,d0           set top of tree

* Check if any job in tree is active

chk_loop
        tst.b   jb_princ(a0)    is job active
        bne.s   jb_activ        yes - cannot delete
        bsr.s   tree            find next job
        tst.l   d1              is this end of tree
        bne.s   chk_loop        no - check this job
        move.l  d0,d1           restore top of tree job
* Drop into force remove job

* d0 -  o- error flag
* d1 -i  - id of job to be removed
* d3 -i  - error code to send to any waiting jobs
* d2/a0-a3 destroyed

mt_frjob
        jsr     ss_jobx(pc)     check if job exists
        move.l  d1,d0           set top of tree
        bne.s   okdel           do not try to delete job 0
        cmp.l   sv_jbpnt(a6),a0 is this job 0 removing itself!!?
        beq.s   help
jb_activ
        moveq   #err.nc,d0      job still active - not complete
ssrte
        jmp     ss_rte(pc)

help
* Job 0 has suicided, until we can think of something better...
        sf      jb_princ(a0)    make it go very quiet
        bra.s   discard         discard whatever it was doing

del_elop
        moveq   #0,d0           no error
        tst.l   (sp)+           check if this job is deleted
        bpl.s   ssrte           no, that's ok
discard
        add.w   #3*4+2+4,sp     discard stacked d7/a5-a6, sr and pc
        jmp     ss_dljob(pc)    yes, re-enter scheduler, job deleted

jbptr
        move.w  d1,a1           find address of job entry
        add.w   a1,a1           job number *4
        add.w   a1,a1
        add.l   sv_jbbas(a6),a1 + base address
        rts

okdel
        bsr.s   jbptr           make up job pointer
mrk_loop
        addq.b  #8,(a1)         mark job
        bsr.s   tree            find next job
        tst.w   d1              is this end of tree
        bne.s   mrk_loop        no - mark this job

* All jobs to be deleted have been marked with +ve in msb of table entry

* We get cleverer these days... first close all channels, in case any other
* jobs are waiting on a channel that goes with this set of jobs.

        assert  sv_chbas,sv_chtop-4
        movem.l sv_chbas(a6),a2-a3
chloop
        move.l  -(a3),d0        get next channel pointer
        bmi.s   chnext          not in use, skip it
        move.l  d0,a0
        move.w  ch_owner+2(a0),d1 fetch owner job number, then make pointer
        bsr.s   jbptr
        tst.b   (a1)
        ble.s   chnext
        bsr.s   mt_close        if one of ours, close the channel now
chnext
        cmp.l   a2,a3
        bne.s   chloop          carry one through all the channel table

* Close entries in common heap for all jobs being deleted.
* This used to be done on a per job basis, but it's quicker to do a single scan
* as there can be a lot of cases of released memory joining up.

        move.l  sv_cheap(a6),a2 start scanning through common heap
chk_tbl
        move.w  hp_owner+2(a2),d0
        cmp.w   sv_jbmax(a6),d0 a safety check, in case memory corrupted
        bhi.s   nxt_tbl
        lsl.w   #2,d0
        beq.s   nxt_tbl         don't touch it if it's got job 0 as owner
        move.l  sv_jbbas(a6),a0
        add.w   d0,a0
        tst.b   (a0)            are we removing this job?
        ble.s   nxt_tbl         no - don't think about it any more
        move.l  a2,a0           put heap pointer in right register
        bsr.s   close           get rid of it
        cmp.l   sv_free(a6),a2  is it off end?
        bcc.s   mem_ex          yes! memory must have been released to sb's!
nxt_tbl
        assert  hp_len,0
        add.l   (a2),a2         move to next item
        cmp.l   sv_free(a6),a2  is it off end?
        bcs.s   chk_tbl
mem_ex

* All common heap has been cleaned out, now see off the jobs themselves

        clr.l   -(sp)           set job number, msb set if current job deleted

del_loop
        addq.l  #1,(sp)         next job
        move.l  (sp),d1
        cmp.w   sv_jbmax(a6),d1 all done?
        bhi.s   del_elop
        bsr.s   jbptr           make up the job pointer
        tst.b   (a1)            is this job to be deleted?
        ble.s   del_loop        ... no

* this job is to be deleted

        cmp.l   sv_jbpnt(a6),a1 is this the current job
        bne.s   notcur
        tas     (sp)            set flag to say current job is deleted
notcur

        sf      (a1)            remove the mark so address is valid
        move.l  (a1),a2         get address of header
        st      (a1)            mark it deleted now

* Release any waiting jobs

        tst.b   jb_wflag(a2)    is a job waiting?
        beq.s   del_tbl
        move.l  jb_wjob(a2),d1  get job id
        jsr     ss_joba(pc)     find job address
        bne.s   del_tbl         oops - it's gone away!!
        cmp.w   #-2,jb_stat(a0) is this waiting on job completion?
        bne.s   del_tbl
        clr.w   jb_stat(a0)     release job
        move.l  d3,jb_d0(a0)    set error return
del_tbl

* Finally, release job space

        move.l  a2,a0
        move.l  d3,-(sp)
        jsr     mm_retrn(pc)
        move.l  (sp)+,d3

        bra.s   del_loop        next job

* a0 -i  - area in common heap to be "closed"
* d0/a1 destroyed (a1 could be saved...)

clreg   reg     d1-d7/a2-a6     all registers can be smashed by close
mt_close
        tst.b   ch_stat(a0)     is anyone waiting on this channel?
        beq.s   close           nope, just scrap it
        jsr     io_jbchk(pc)    check if job is still around
        bne.s   close           nope, forget about it
        moveq   #err.no,d0
        move.l  d0,jb_d0(a1)    tell job the channel is no longer open
        clr.w   jb_stat(a1)     job is no longer waiting
close
        movem.l clreg,-(sp)     save registers
        assert  0,hp_drivr-4,hp_owner-8,hp_rflag-12
        lea     hp_rflag(a0),a1
        move.l  (a1),d0         check release flag address
        beq.s   cls_tbl
        move.l  d0,a3
        st      (a3)            flag this entry gone
        clr.l   (a1)            clean out the release flag now!
cls_tbl
        clr.l   -(a1)           discard the owner now!
        move.l  -(a1),a1        fetch address of driver for this item
        lea     -sv_lio(a1),a3  set base of driver definition block
        move.l  hp_close(a1),a1 close item
        jsr     (a1)
        movem.l (sp)+,clreg     restore registers
        rts

        end
