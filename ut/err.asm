* Handles error messages
        xdef    ut_err,ut_err0

        xref    ut_mtext

        include 'dev7_m_inc_sv'

        section ut_err

* Print an error message to channel id 0.

* d0 -ip - error key (ccr is not set)

ut_err0
        move.l  a0,-(sp)        save a0
        sub.l   a0,a0           channel 0
        bsr.s   ut_err          write message
        move.l  (sp)+,a0        restore a0
        rts

* Print an error message to supplied channel.

* d0 -ip - error key (ccr is not set)
* a0 -ip - channel id

ut_err
        movem.l d0-d3/a1,-(sp)  save volatile registers
        move.l  d0,a1           d0 might be pointer to message + $80000000
        add.l   d0,d0
        bcc.s   tidy            positive is not an error message
        bpl.s   write           ... it is pointer to message
        neg.w   d0
        move.w  d0,a1
        moveq   #0,d0
        move.l  a0,-(sp)
        trap    #1
        move.l  sv_mgtab(a0),a0 get base of error table
        move.w  0(a0,a1.w),a1   pick offset to reqd. message
        add.l   a0,a1           make the actual address
        move.l  (sp)+,a0 
        tst.b   (a1)            silly message length? ( > 255 chars )
        bne.s   tidy            yes, so give up
write
        jsr     ut_mtext(pc)    write message
tidy
        movem.l (sp)+,d0-d3/a1  restore volatile registers
        rts

        end
