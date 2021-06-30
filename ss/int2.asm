* Entry for level 2 interrupt and return points
        xdef    ss_int2,ss_intrd,ss_noer,ss_rte

        xref    md_serve
        xref    ip_ipcr,ip_txqo
        xref    ss_tlist,ss_reshd

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_bt'
        include 'dev7_m_inc_assert'

        section ss_int2

regsone reg     d7/a5-a6        a data reg, a5, and base of sys_var
regstwo reg     d0-d6/a0-a4     the rest

gpint
*       moveq   #0,d3           already set for us
        move.b  sv_mdrun(a6),d3 get number of drive running
        beq.s   no_op
        lea     sv_mddid(a6),a5
        sf      sv_mdsta-sv_mddid-1(a5,d3.w) clear service request
        move.b  -1(a5,d3.w),d3  get drive id*4
        move.l  sv_fsdef-sv_mddid(a5,d3.w),a5 ...hence address of definition
        lsl.b   #4-2,d3         drive id * 16
        addq.b  #1<<bt..file,d3 + compare for file blocks
        movem.l d0-d3/a4-a5,-(sp) set up stack frame (d0-d2 & d3.msw = buff)
        move.l  sp,a1           and point to it
        jsr     md_serve(pc)
        add.w   #6*4,sp         remove sector, drive id, a4 and a5 from stack
no_op
        moveq   #-1-pc.maskg-pc.intrg,d7
        and.b   sv_pcint(a6),d7 temporarily mask gap interrupt
        addq.b  #pc.intrg,d7    clear this interrupt
        move.b  d7,pc_intr-pc_mctrl(a3)
        clr.b   d7              next reset the gap mask to normal
        bra.s   clearint        generate an interrupt if gap is already there

ss_intrd
* Non-redirected traps come here... maybe we can get away with just this.

ss_int2
        movem.l regsone,-(sp)
        move.l  a7,d7
        and.w   #$8000,d7
        move.l  d7,a6           do not assume there is only one screen
        movem.l regstwo,-(sp)

        lea     pc_mctrl,a3
        assert  pc_mctrl,pc_intr-1
        move.w  (a3),d7         fetch the interrupt register to lsb (tigeftig)
        assert  1<<4,pc.intre,pc.intrf<<1
        lsl.b   #4,d7           check for external or frame interrupts
        bcs.s   exint
        bmi.s   frint
        moveq   #0,d3           no missing polls is common-ish
        assert  1<<2,pc.intrt,pc.intri<<1
        lsl.b   #2,d7           check for transmit, interface & gap interrupts
        bcs.s   txint
        bmi.s   inint
        bne.s   gpint
        bra.s   nonred          no bits set! used for non-redirected traps!

exint
        moveq   #sv_i2lst-sv_i2lst,d4 set offset of int 2 list from int 2 list
        jsr     ss_tlist(pc)    do all external interrupt tasks
        moveq   #pc.intre,d7    clear external
clearint
        or.b    sv_pcint(a6),d7 get current interrupt mask
        move.b  d7,pc_intr
        movem.l (sp)+,regstwo
one_rte
        movem.l (sp)+,regsone
        rte

ss_noer
        moveq   #0,d0           no error
ss_rte
        tst.w   sv_pollm(a6)    check for missing polls
        beq.s   one_rte         none - return now
is_sup
        moveq   #1<<5,d7
        and.b   12(sp),d7       check if called from supervisor state
        bne.s   one_rte         yes - direct return
        jmp     ss_reshd(pc)    reenter scheduler

* Serial port transmit interrupt
txint
*       moveq   #0,d3           no missing polls already set
        st      d4              not called from scheduler
        jsr     ip_txqo(pc)     send any rs232
        moveq   #pc.intrt,d7    clear this interrupt
        bra.s   clearint

* Interface interrupt, serial data available
inint
*       moveq   #0,d3           no missing polls alredy set
        jsr     ip_ipcr(pc)     read status and handle anything it says
        moveq   #pc.intri,d7    clear this interrupt
        bra.s   clearint

* Frame interrupt, 50Hz (or 60Hz USA)
frint
        addq.w  #1,sv_pollm(a6) increment count of poll interupts
        bvc.s   do_poll         ... ok?
        subq.w  #1,sv_pollm(a6) ... no reset it (slightly unsafe!)
do_poll
        moveq   #1,d3           just one poll since last time!!
        moveq   #sv_plist-sv_i2lst,d4 set offset of poll list from int 2 list
        jsr     ss_tlist(pc)    scan the list
        moveq   #pc.intrf,d7    set to clear frame interrupt
        or.b    sv_pcint(a6),d7 fetch interrupt register value
        move.b  d7,pc_intr      and clear it
nonred
        movem.l (sp)+,regstwo
        bra.s   is_sup          go see if we were in supervisor mode

        end
