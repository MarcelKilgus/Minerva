* System job utility routines
        xdef    ss_jobx,ss_joby,ss_joba,ss_jobc

        xref    ss_rte

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_jb'

        section ss_job

* Check if a particular job exists
* Must only be called from trap level
* It does not return if job does not exist

* d0  r  set on abnormal exit
* d1 cr  job number to be checked
* a0  r  address of header

ss_jobx
        tst.w   d1              is it current job?
        bge.s   test_job

* ss_joby finds the current job id (d1), and base address (a0)

* d1  r  current job id
* a0  r  base of current job

ss_joby
        move.l  sv_jbpnt(a6),a0 get current job table pointer
        move.w  a0,d1
        move.l  (a0),a0         ... then pointer to job
        sub.w   sv_jbbas+2(a6),d1 calculate job number ... pointer -  base
        lsr.w   #2,d1           div by 4
        swap    d1
        move.w  jb_tag(a0),d1   ... and tag in top end
        swap    d1
exit
        rts

test_job
        bsr.s   ss_joba
        beq.s   exit
        moveq   #err.nj,d0
        addq.l  #4,sp           ... remove return address from stack
        jmp     ss_rte(pc)     ... return direct to trap

* ss_joba finds the address of a job (condition codes zero if ok)

* d1 c p job id
* a0  r  base address of job

ss_joba
        cmp.w   sv_jbmax(a6),d1 is it in range?
        bhi.s   exit
        move.w  d1,a0           find address of job entry
        add.w   a0,a0           ... it is job number * 4
        add.w   a0,a0
        add.l   sv_jbbas(a6),a0 ... + base of table
        tst.b   (a0)            ... is it in table?
        blt.s   exit
        move.l  (a0),a0         set address of job header
        swap    d1              move tag to bottom word
        cmp.w   jb_tag(a0),d1   is this the same?
        bne.s   exit            ... oops
        swap    d1
        cmp.b   d1,d1           set condition codes to 0
        rts

* ss_jobc finds the current job id (d0), and base address (a3)

* d0  r  current job id
* a3  r  base of current job

ss_jobc
        bsr.s   swap
        bsr.s   ss_joby
swap
        exg     a3,a0
        exg     d0,d1
        rts

        end
