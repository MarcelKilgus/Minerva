* Scheduler entry / re-entry
        xdef    ss_reshd,ss_dljob,ss_rj0

        xref    ss_tlist

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_assert'

sx..brk equ     4       low bit number that indicates ctrl{/alt}/space events
bv..int equ     6       bit number that indicates an interpreter job

        section ss_reshd

* Break (ctrl/space) handling moved here to avoid having it inside interrupt
* service code! Also, ctrl/alt/space breaks all other interpreters.

* The usage of job priorities has been enhanced somewhat. They now behave as:
*       -128..-1        background tasks (see below)
*       0               job is inactive
*       1-127           major active jobs, as before
* Background tasks are split into sixteen levels, according to their top
* nibble, within each of which the low nibble now gives the priority increment.
* Tasks of a given level are never given time unless no major job and no tasks
* at a higher level want time.

* Re-scheduling entry point
ss_reshd
        move.l  sv_jbpnt(a6),a5 find address of base of job
        move.l  (a5),a5
        move.l  (sp)+,d7        the real value of d7
        movem.l d0-d7/a0-a4,jb_d0(a5) save most of the registers
        add.w   #jb_a0+5*4,a5
        assert  jb_a0+8*4,jb_sr,jb_pc-2
        move.l  (sp)+,(a5)+     saved a5
        move.l  (sp)+,(a5)+     saved a6
        move    usp,a0
        move.l  a0,(a5)+        user stack pointer (a7)
        move.w  (sp)+,(a5)+     status register
        move.l  (sp)+,(a5)      program counter

        tst.b   jb_prior-jb_pc(a5) reduce priority
        beq.s   ss_dljob        if it is already zero - don't bother
        move.b  #1,jb_prior-jb_pc(a5)

* Entry when a job has been deleted by man_djob = main scheduler loop
ss_dljob
        lea     sv_pollm(a6),a0
        move.w  (a0),d3         fetch number of missing polls
        sub.w   d3,(a0)         and reset

        assert  sv_rand,sv_pollm-2
        addq.w  #1,-(a0)        update random number

* Now execute all tasks to be done by the scheduler/ioss

        moveq   #sv_shlst-sv_i2lst,d4 set offset of sched list from int 2 list
        jsr     ss_tlist(pc)    go do them (sets d1.l=0)

* Look for next job to execute

* d0 -  o- address of job entry with highest priority (if d1.b is not zero)
* d1 -i o- 0/priority of job d0 or zero if no one can run
* d3 -i  - number of polled interrupts since last go
* a6 -  i- base address of system variables

* d2 priority of this job
* d4 priority increment
* d5 temporary
* d6 break events, bit 31 = ctrl/space and bit 0 = ctrl/alt/space
* d7 max job * 4, complemented as we swap marker
* a0 address of job
* a1 address of hold flag
* a2 address of job entry
* a3 address of marker job entry
* a4 address of system extension block

*       moveq   #0,d1           highest priority starts as zero = no job yet
        assert  sv_jbmax+2,sv_jbpnt,sv_jbbas-4
        movem.l sv_jbpnt-4(a6),d7/a2-a3 max job, current job and base of table
        lsl.w   #2,d7           highest job number * 4
        move.l  sv_chtop(a6),a4 get sysext address
        moveq   #3<<sx..brk,d6
        and.b   sx_event(a4),d6 get both break events (ctrl/{alt/}space)
        eor.b   d6,sx_event(a4) invert events we have picked up
        ror.l   #sx..brk+1,d6   sx..brk to bit 31, sx..brk+1 to bit 0

chk_end
        cmp.l   a2,a3           are we at the marker?
        beq.s   chk_stp         yes - go see it that was the full loop
        move.l  -(a2),d2        is this entry vacant?
        blt.s   chk_end         yes - see if end of scan
        move.l  d2,a0           get address of job
        move.w  #$7000,d4       positive princ's get msb $70
        assert  jb_stat-1,jb_princ
        lea     jb_stat-1(a0),a1
        move.b  (a1)+,d4        check if this job is active
        beq.s   chk_end
        bpl.s   pri_ok
        lsl.w   #4,d4
        lsr.b   #4,d4           turn -ve princ into 16 absolute low levels
pri_ok

        btst    #bv..int,jb_rela6(a0) is this an interpreter?
        beq.s   brk_off         no - break events don't apply
        moveq   #jb_end+bv_brk-$7f,d2 job 0 offset of break flag less a bit
        cmp.l   sv_jbbas(a6),a2 is this job 0?
        seq     d5              job 0 - test bit 7, others - test bit 0
        beq.s   set_brk
        add.w   jb_end+2(a0),d2 others have extra offset
set_brk
        btst    d5,d6           are we processing the appropriate break event?
        beq.s   brk_off         no - forget it
        sf      $7f(a0,d2.w) set break flag
        move.w  (a1),d2         get status
        beq.s   susp_ok         if not suspended, let it carry on
        addq.w  #1,d2           is it waiting on another job (wait -2)
        bge.s   clr_stat        anything but that, release it
brk_off

        move.w  (a1),d2         check if this job is suspended
        beq.s   susp_ok         no - go process priority
        blt.s   chk_end         it's waiting permanently
        sub.w   d3,(a1)         tick its clock
        bgt.s   chk_end         not timed out yet, keep it waiting

clr_stat
        clr.w   (a1)            clear suspension
        move.l  jb_hold(a0),d2  is this job held on something?
        beq.s   susp_ok
        move.l  d2,a1
        sf      (a1)            yes - clear hold flag
susp_ok

        move.b  jb_prior(a0),d2 get current priority
        bne.s   add_prio
        move.b  #1,d4           if first time round - just move up one
add_prio
        add.b   d2,d4           add increment
        scs     d2              has it overflowed?
        or.b    d2,d4           yes - set it to max
        move.b  d4,jb_prior(a0) save new priority
        cmp.w   d4,d1           is this greater than highest so far
        bcc.s   chk_end
        move.w  d4,d1
        move.l  a2,d0           yes - save it
chk_end2
        bra.s   chk_end

chk_stp
* Either: a2=a3=bottom of table and d7<>0, or: a2=a3=current job and d7=0
        lea     4(a3,d7.w),a2   address after highest job
        move.l  sv_jbpnt(a6),a3 stop when we've looked at current job
        not.w   d7              was this the full loop over?
        bmi.s   chk_end2        no - do rest of scan

        tst.w   d1              check if any job found (priority non-zero)
        beq.l   ss_dljob        if not - do (poll)/io operations again

        move.l  d0,sv_jbpnt(a6) set current job table entry

* Entry point from ss_init to start up job zero
* super GC requires a0 to be used here!

ss_rj0
        move.l  sv_jbpnt(a6),a0 find address of job in table
        move.l  (a0),a0         thus base of job

        move.l  jb_trapv(a0),sv_trapv(a6) redirect traps
        add.w   #jb_pc,a0
        move.l  (a0),-(sp)      put the program counter on
        move.w  -(a0),-(sp)     and status register
        move.l  -(a0),a1
        move    a1,usp          restore user stack pointer
        assert  jb_d0+8*4,jb_a0
        movem.l jb_d0-jb_a0-7*4(a0),d0-d7/a0-a6 and all other registers

        rte                     and go!

        end
