* I/O channel open, close, format and delete traps
        xdef    io_trap2

        xref    io_chanx,io_fopen,io_fdriv
        xref    mt_close
        xref    ss_jobx,ss_joby,ss_tag,ss_rte

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_assert'

        section io_trap2

io_trap2
        movem.l d7/a5-a6,-(sp)  save standard registers
        move.l  a7,d7
        and.w   #$8000,d7
        move.l  d7,a6           do not assume there is only one screen
        moveq   #127,d7         ensure trap is positive byte only
        and.l   d7,d0

        move.l  sv_jbpnt(a6),a5 get current job pointer
        move.l  (a5),a5         ... thus base of job
        bclr    d7,jb_rela6(a5) clear and test relative addressing flag
        beq.s   trap_sel
        add.l   2*4(sp),a0      add a6 offset to address of name
trap_sel
*       move.l  sp,a5           set trap level pointer to stack

        subq.b  #io.open,d0
        beq.s   io_open
        assert  1,io.close-io.open,io.formt-io.close
        subq.b  #io.formt-io.open,d0
        bcs.s   io_close
        beq.s   io_formt
        subq.b  #io.delet-io.formt,d0
        beq.s   io_delet
        moveq   #err.bp,d0      oh dear!
        bra.s   ssrte

* d0 -  o- error code
* d1 -  o- drive number (msw) and number of good sectors (lsw)
* d2 -  o- total number of sectors
* a0 -i  - pointer to medium name
* a1 destroyed, though it needn't be

fmt_reg reg     d3-d6/a2-a4
io_formt
        movem.l fmt_reg,-(sp)

        jsr     io_fdriv(pc)    go look up a device driver for this name
        blt.s   fmtexit         driver not found
        bne.s   fmtok           no physdef is ok
        tst.b   fs_files(a1)    any files open on the medium?
        beq.s   fmtok           no - fine
        move.l  sv_chtop(a6),a1 get extension address
        tst.b   sx_toe(a1)      are we to treate this as an error?
        bmi.s   fmtok           nope, allow silly bug in dp's conqueror
        moveq   #err.iu,d0      surely can't do it with files open? (added lwr)
        bra.s   fmtexit

fmtok
        move.l  a0,a1           oh me, oh my. why does is have to be in both?
*       movem.l (sp),d3-d4      should we really have to do this? (lwr)
        lea     -sv_lio(a2),a3  set up base driver definition block
        move.l  ch_formt(a2),a4
        jsr     (a4)
fmtexit
        movem.l (sp)+,fmt_reg
        bra.s   ssrte

* d0 -  o- error code (well... close calls should never say they fail!)
* a0 -i  - channel id
* a1 destroyed (though mt_close could save it...)

io_close
        jsr     io_chanx(pc)    check that channel exists (a0->a5, chan->a0)
        jsr     mt_close(pc)    go do the closure
ssrte
        jmp     ss_rte(pc)

* d0 -  o- error code
* d1 -  o- current job id
* a0 -i  - pointer to word length prefixed device/file name
* d3/a1 destroyed

io_delet
        move.l  a0,a1           save address of name
        jsr     ss_joby(pc)     get own job id in d1, address in a0
        exg     a0,a1           address of job goes to a1
        st      d3              d3 key for delete
        jsr     io_fopen(pc)    delete file
        bra.s   ssrte

* d0 -  o- error code
* d1 -i o- job id (real one on output)
* d3 -ip - access code
* a0 -i o- filename / cahnnelid
* a1 destroyed

op_save reg     a0/a2-a4
opn_reg reg     d1-d6/a1-a3/a6  open allowed to destroy all regs, as per doc!
io_open
        move.l  a0,a1           save address of name
        jsr     ss_jobx(pc)     check if job exists (no return on failure)
        exg     a0,a1           address of job goes to a1
        movem.l op_save,-(sp)   save a few registers to be used here
        moveq   #err.no,d0      out of room / select sys_tag table
        lea     sv_chbas(a6),a4 this is the table to look in
        jsr     ss_tag(pc)      look for new channel slot
        bmi.s   exit_op         couldn't find a new slot
        move.l  d0,(sp)         set new channel id (maybe)

        lea     sv_drlst(a6),a2 get address of first device driver
chk_next
        move.l  (a2),a2         try next driver
        move.l  a2,d0
        beq.s   chk_file
chk_loop
        movem.l opn_reg,-(sp)
        lea     -sv_lio(a2),a3  set base of driver definition block
        move.l  ch_open(a2),a4  indirect
        jsr     (a4)            try opening this device type
        movem.l (sp)+,opn_reg
        tst.l   d0
        beq.s   open            was channel opened
        cmp.w   #err.nf,d0      check if error was 'not found'
        beq.s   chk_next        that was ok
exit_op
        movem.l (sp)+,op_save
        bra.s   ssrte

* Finally try the file system

chk_file
        moveq   #err.bp,d0
        cmp.b   #io.dir,d3      check access key
        bhi.s   exit_op

        jsr     io_fopen(pc)
        bne.s   exit_op
open
        move.l  a0,(a3)         set address of channel definition block
        addq.l  #4,a0           length of block is in header already
        move.l  a2,(a0)+        put address of device driver in
        move.l  d1,(a0)+        put job id in
        move.l  a3,(a0)+        address of release flag
        move.w  (sp),(a0)+      put tag in
        clr.w   (a0)+           status ok, no pending action
        clr.l   (a0)+           no job waiting
        bra.s   exit_op

        end
