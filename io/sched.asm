* Scans channels for scheduler for an io wait job
        xdef    io_sched,io_jbchk

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_assert'

        section io_sched

* Check out a busy channel so see if the waiting job is still around

* a0 -ip - channel pointer to channel with non-zero ch_stat
* a1 -  o- job header of waiting job, if ccr returned is z
* d0 destroyed (job number * 2^18 if ccr=z)

io_jbchk
        move.l  ch_jobwt(a0),d0 fetch job number
        lsl.w   #2,d0
        move.l  sv_jbbas(a6),a1
        add.w   d0,a1           job table address
        tst.b   (a1)            is it still there?
        bmi.s   rts0            while we waited for io, job went
        move.l  (a1),a1         find base of job
        swap    d0              check tag
        sub.w   jb_tag(a1),d0
rts0
        rts

* This was altered to scan all channels each time, but buttons caused problems.

* d0-d7/a0-a5 destroyed

io_sched
        assert  sv_chmax-2,sv_chpnt-4,sv_chbas-8
        movem.l sv_chmax-2(a6),d7/a3-a4 get channel max, pointer and base
        move.l  a3,a5           save current channel pointer
chk_last
        cmp.l   a4,a5           at marker?
        bne.s   chk_chan        no, carry on
        lsl.w   #2,d7           multiply max by 4 (note: never all that large)
        bcs.s   rts0            second marker, so get out now
        lea     4(a5,d7.w),a5   start again at top of list
        moveq   #-1,d7          set flag so we don't do this again
        move.l  a3,a4           marker now original pointer
chk_chan
        move.l  -(a5),d0        is this vacant
        bmi.s   chk_last        yes, skip it
        move.l  d0,a0
        move.b  ch_stat(a0),d4  is channel waiting for i/o
        beq.s   chk_last        no, forget it

* A channel waiting on io has been found

        move.l  a5,sv_chpnt(a6) reset current channel number
        bsr.s   io_jbchk        check out waiting job
        bne.s   job_gone        while we waited for io, job went!
* A note: can we ever get caught out by a channel that appears to have a job
* waiting on it, but the job has actually got out of suspension somehow?
        moveq   #0,d6           initialise a1 offset as zero
        addq.b  #1,d4           was a1 an absolute address
        beq.s   offdone
        move.l  jb_a0+6*4(a1),d6 no, so add job's a6 to a1, and remember
offdone
        movem.l d6/a1,-(sp)     save offset and job pointer
        moveq   #0,d0           clear msbs of d0
        move.b  ch_actn(a0),d0  ... and restore action key
        moveq   #-1,d3          this is a repeat call
        movem.l jb_d0+4(a1),d1-d2 restore ioss data regs
        movem.l jb_a0+4(a1),a1-a2 restore ioss address regs
        add.l   d6,a1           add any offset to a1
        move.l  ch_drivr(a0),a4 get address of driver definition
        lea     -sv_lio(a4),a3  set base address of definition
        move.l  ch_inout(a4),a4 get i/o entry point
        jsr     (a4)            call it
        sub.l   (sp)+,a1        remove offset from a1
        move.l  (sp)+,a2        restore job pointer
        movem.l d0-d1,jb_d0(a2) save the updated d0 and d1
        move.l  a1,jb_a0+4(a2)  save the updated address reg a1

        addq.l  #-err.nc,d0     check if operation is now complete
        beq.s   rts1            skip if it's still not complete
        clr.w   jb_stat(a2)     set status active
job_gone
        sf      ch_stat(a0)     set status ok
rts1
        rts

        end
