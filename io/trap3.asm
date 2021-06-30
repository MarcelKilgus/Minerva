* Handles input/output traps
        xdef    io_trap3

        xref    io_chanx
        xref    ss_jobc,ss_reshd,ss_rte

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_fs'

        section io_trap3

* Preserves d2,d3,a0,a2,a3 and all non volatile registers
* Used to assume a6 was preserved by I/O routine, but it doesn't now.
* (The manual states that it should be preserved, but JS did save it, and hence
* some idiot distributed a nasty piece of sd.extop code that zapped it!)

io_trap3
        movem.l d7/a5-a6,-(sp)  save standard registers
        move.l  a7,d7
        and.w   #$8000,d7
        move.l  d7,a6           do not assume there is only one screen
        moveq   #127,d7         ensure trap is positive byte only
        and.l   d7,d0

        jsr     io_chanx(pc)    check a0 id, a0->a5 and chan->a0
        tas     ch_stat(a0)     is there a job waiting for completion?
        bne.s   busy

reglist reg     d2-d6/a2-a6
        movem.l reglist,-(sp)
        clr.l   -(sp)           make room for a1 offset
stack_d3 equ    4+4
stack_a6 equ    4+4*9
stack   equ     4+4*10

        cmp.b   #fs.save,d0     is it an unknown key?
        bgt.s   get_job         yes
        cmp.b   #fs.heads,d0    is it header, load or save?
        bge.s   clr_d1          yes
        cmp.b   #io.sstrg,d0    is it a standard io op?
        bgt.s   get_job         no
        btst    #1,d0           is it key 2,3,6 or 7?
        beq.s   get_job         no
clr_d1
        moveq   #0,d1           set initial number of bytes sent / fetched
get_job
        move.l  sv_jbpnt(a6),a3 get address of job
        move.l  (a3),a3
        bclr    #7,jb_rela6(a3) test and clear msb of relative flag
        beq.s   go
        move.l  stack+8(sp),(sp) get user value of a6
        add.l   (sp),a1         make a1 absolute
go
        move.l  ch_drivr(a0),a4 fetch address of driver
        move.b  d0,ch_actn(a0)  save action
        moveq   #0,d3           this is first call for operation
        lea     -sv_lio(a4),a3  set base address of definition block
        move.l  ch_inout(a4),a4 indirect
        jsr     (a4)            go
        sub.l   (sp),a1         reset a1 to relative (if it was)
        addq.l  #-err.nc,d0     was operation complete?
        bne.s   exit_don
        move.w  stack_d3+2(sp),d3 was immediate return requested?
        bne.s   wait
exit_don
        subq.l  #-err.nc,d0     put back proper error code
        addq.l  #4,sp           get rid of a1 offset
        movem.l (sp)+,reglist
        sf      ch_stat(a0)     channel not in use
exit
        move.l  a5,a0           restore channel id
        jmp     ss_rte(pc)

busy
        tst.w   d3              is this an immediate return
        beq.s   exit_nc         yes - return non-complete
        subq.l  #2,14(sp)       no - backspace pc by two
        bra.s   re_sched        and re-schedule

exit_nc
        move.l  sv_jbpnt(a6),a0 get address of job
        move.l  (a0),a0
        bclr    #7,jb_rela6(a0) clear msb of relative flag
        moveq   #err.nc,d0
        bra.s   exit

wait
        move.l  stack_a6(sp),a6 restore a6
        jsr     ss_jobc(pc)     get job entry address and id
        move.l  d0,ch_jobwt(a0) and set id of waiting job

        lea     ch_stat(a0),a0  get pointer to wait flag (already $80)
        tst.l   (sp)+           check if this was a relative a1 call
        bne.s   mark_job
        st      (a0)            set wait flag (a1 abs)
mark_job
        move.l  a0,jb_hold(a3)  tell the scheduler where it is
        move.w  d3,jb_stat(a3)  set wait status
        sf      jb_prior(a3)    reset priority
        moveq   #err.nc,d0      restore error flag
        movem.l (sp)+,reglist   and registers
re_sched
        move.l  a5,a0           restore channel id
        jmp     ss_reshd(pc)    re-schedule

        end
