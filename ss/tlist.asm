* Executes tasks in the poll or I/O list
        xdef    ss_tlist

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_assert'

        section ss_tlist

* d1 -  o- 0
* d3 -ip - count of missing poll interrupts
* d4 -i  - offset from sv_i2lst (0, 4 or 8 for i2lst, plist or shlst)
* a0 -  o- 0
* a6 -ip - base of sytem variables
* d0/d2/d5-d6/a1-a5 destroyed

ss_tlist
        move.l  sv_i2lst(a6,d4.w),a0 get base entry of linked list
        assert  (sv_i2lst-sv_i2lst)*2,sv_lxint
        assert  (sv_plist-sv_i2lst)*2,sv_lpoll
        assert  (sv_shlst-sv_i2lst)*2,sv_lschd
        add.b   d4,d4
        neg.l   d4              convert to device drive definition offset
        movem.l d3-d4/a6,-(sp)  save stuff
        bra.s   enter

loop
        moveq   #127,d3         making it a positive byte (why? lwr)
        and.b   d2,d3           set up for positive byte missing polls
        add.l   a0,a3           set base of driver definition block
        move.l  4(a0),a0        start address is one long word on from link
        jsr     (a0)            call the entry point
        move.l  (sp)+,a0        restore pointer
        move.l  (a0),a0         take next
enter
        movem.l (sp),d2/a3/a6   set registers ready
        move.l  a0,-(sp)        save base address of task
        bne.s   loop            next pointer

        movem.l (sp)+,d1/d3-d4/a6 restore d3 properly, d1=0
        rts

        end
