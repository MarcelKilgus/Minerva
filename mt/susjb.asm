* Set priority, activate, suspend or release a job
        xdef    mt_susjb,mt_reljb,mt_activ,mt_prior

        xref    ss_jobx,ss_jobc,ss_reshd

        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_err'

        section mt_susjb

* d0 -  o- error return
* d1 -i o- job id (-1 = self)
* d2 -ip - new priority
* a0 -  o- base address of job
* a6 -ip - base address of system variables

mt_prior
        jsr     ss_jobx(pc)     check if job exists
        move.b  d2,jb_princ(a0) set new priority
        bne.s   exit_ok         is priority zero
        sf      jb_prior(a0)    ... yes - kill it
        bra.s   exit_ok

* d0 -  o- error return
* d1 -i o- job id (-1 = self)
* d2 -ip - new priority
* d3 -ip - timeout (anything but zero is wait for completion)
* a0 -  o- base address of job
* a6 -ip - base address of system variables
* a3 destroyed iff d3 <> 0

mt_activ
        jsr     ss_jobx(pc)     check if job exists
        moveq   #err.nc,d0
        tst.b   jb_princ(a0)    is job active?
        bne.s   re_sched        yes - can't do it twice!
        move.b  d2,jb_princ(a0)
        move.l  jb_start(a0),d7 do it have the facilty to be activated?
        ble.s   re_sched        no - don't do anything silly!
        move.l  d7,jb_pc(a0)    set start address in saved pc
        tst.w   d3              is it wait on completion?
        beq.s   exit_ok         ... no - just reschedule
        st      jb_wflag(a0)    set job waiting flag
        jsr     ss_jobc(pc)     get current job id and address
        move.l  d0,jb_wjob(a0)  ... and set id of waiting job
        move.w  #-2,jb_stat(a3) ... then timeout
* note - when suspended jobs can be reactivated we could set d0 to err.nc here

exit_ok
        moveq   #0,d0           set no error
re_sched
        jmp     ss_reshd(pc)    ... and re-schedule

* d0 -  o- error flag
* d1 -i o- job id (-1 = self)
* d3 -ip - timeout
* a0 -  o- address of job header
* a1 -ip - zero or address of hold flag byte
* a6 -ip - base address of system variables

mt_susjb
        jsr     ss_jobx(pc)     check job number
        move.w  d3,jb_stat(a0)  suspend
        move.l  a1,jb_hold(a0)  and set hold
        bra.s   exit_ok         no error

* d0 -  o- error flag
* d1 -i o- job id (-1 = self)
* a0 -  o- address of job header
* a6 -ip - base address of system variables

mt_reljb
        jsr     ss_jobx(pc)     check job number
        tst.w   jb_stat(a0)     is it suspended?
        beq.s   exit_ok
        clr.w   jb_stat(a0)     release it

        move.l  jb_hold(a0),d0  and check if hold flag exists
        beq.s   exit_ok
        exg     d0,a0
        sf      (a0)            clear hold flag byte
        move.l  d0,a0
        bra.s   exit_ok

        end
