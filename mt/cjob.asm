* Creates a new job in the trans prog area
        xdef    mt_cjob,mt_cj0

        xref    ss_jobx,ss_jtag,ss_rte
        xref    mm_altrn

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_assert'

        section mt_cjob

reg_save reg    d1-d2/a1-a4
reg_pick reg    d0/d2/a1

* d0 -  o- error flag
* d1 -i o- owner job / job id
* d2 -ip - length of code or 0
* d3 -i o- length of data space (rounded up to fill acquired transient space)
* a0 -  o- base address of job
* a1 -ip - job start address or zero to use base of job area
* a6 -ip - base address of system variables
* d7 destroyed

mt_cjob
        jsr     ss_jobx(pc)
        movem.l reg_save,-(sp)

        moveq   #err.nj,d0      error code we want from sys_jtag if it fails
        add.l   d2,d3           this will be the prog + data size requested
        ble.s   exit            a minor point - refuse silly parameters
        jsr     ss_jtag(pc)     go get us a new job slot
        bmi.s   exit            return negative means d0 not changed

        move.l  a3,a4           save pointer into job table
        move.l  (sp),d7         fetch owner off the stack
        move.l  d0,(sp)         put new job id on the stack

        moveq   #jb_end,d1      header is not included
        add.l   d3,d1           so add it to length required
        jsr     mm_altrn(pc)    and allocate space
        bne.s   exit            ok?
        movem.l (sp),reg_pick   restore prog space and start (d0 ignored)

* Now set up the job control block in the header

        lea     jb_end(a0),a2   job base for misc setup
        assert  ((jb_end-jb_tag)/4)*4,jb_end-jb_tag
        moveq   #(jb_end-jb_tag)/4-1,d0 clear all but length/start/owner/hold
clr_head
        clr.l   -(a2)
        dbra    d0,clr_head
        move.l  sv_trapv(a6),jb_trapv(a0) dup callers trap vector ptr
        move.l  sv_jbpnt(a6),a3
        move.l  (a3),a3
        moveq   #15,d0          allow for four inherited flag bits
        and.b   jb_rela6(a3),d0
        move.b  d0,jb_rela6(a0) dup caller's flag bits
        move.w  (sp),(a2)       set tag
        clr.l   -(a2)           clear jb_hold, as it happens
        assert  jb_owner,jb_tag-8
        move.l  d7,-(a2)        set owner
        move.l  a4,a3           put back pointer to job table
        bsr.s   mt_cj0          do the bit in common with sys_init
        move.l  d2,-(a3)        set length of code in saved a4
        sub.l   d2,d3           d3 = real data size... not that anyone cares!
        moveq   #0,d0           no error
exit
        movem.l (sp)+,reg_save
        jmp     ss_rte(pc)

* A bit of code shared with sys_init

* d1 -i  - overall size of area, including header
* d3 -  o- prog+data size, i.e. d1 less jb_end
* a0 -i o- pointer to job header / job base address
* a1 -i o- start address or zero / new job's usp
* a3 -i o- pointer into job table where a0 is to go / jb_a5(a0)

mt_cj0
        move.l  a0,(a3)         set up pointer in job table
        moveq   #-jb_end,d3     discount header
        sub.l   d3,a0           set job base
        add.l   d1,d3           form prog+data size
        lea     jb_pc-jb_end(a0),a3
        move.l  a1,(a3)         was a start address given?
        bne.s   startok         yes - accept it
        move.l  a0,(a3)         no - use base of job
startok
        move.l  (a3),jb_start-jb_end(a0) copy start to saved pc
        subq.l  #jb_pc-(jb_a0+7*4),a3
        lea     -4(a0,d3.l),a1  job top less 4 will be user stack pointer
        clr.l   (a1)            with two zero words on it
        move.l  a1,(a3)         set saved a7 (usp)
        move.l  a0,-(a3)        set job base in saved a6
        move.l  d3,-(a3)        set length of code+data in saved a5
        rts

        end
