* Writes bits of messages

        xdef    ut_mint,ut_mtext,ut_write

        xref    cn_0tod

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_mt'

        section ut_messb

* N.B. This should not be called in user mode by an interpreter job, as a6/a7
* may move! However, it is now fairly safe (see below).

* d0 -  o- error code
* d1 -i o- integer value (ut_mint) / number of characters actually sent
* d2 -  o- number of characters that should have been sent
* d3 -  o- 0 if a0=0, otherwise -1
* a0 -ip - channel id
* a1 destroyed

ut_mint
        subq.l  #8,sp           eight byte workspace & 68020 compatible...
        movem.l a6-a7,(sp)      ... snapshot of a6/a7
        movem.l (sp),d0/d3      get matched copies of a6/a7
        sub.l   d0,d3           this is a good rel a6 offset
        exg.l   a0,d3           save channel while we convert
        move.w  d1,d0           put the number in d0
        jsr     cn_0tod(pc)     convert, putting at (a6,a0)
        move.l  d3,a0           get back the channel id
        move.w  d1,d2           set number of characters
        move.l  sp,a1           set pointer to characters
* This is the point where an interpreter can fail... the stack could move.
* It's not too awful, we just get garbage instead of the proper number.
        bsr.s   ut_write
        addq.l  #8,sp           discard work area
        rts

* d0 -  o- error code
* d1 -  o- number of characters sent
* d2 -  o- lsw gets string length, msw unchanged
* d3 -  o- 0 if a0=0, otherwise -1
* a0 -ip - channel id
* a1 -i o- pointer to string prefixed by length word (updated past last sent)

ut_mtext
        move.w (a1)+,d2         get character count

* d0 -  o- error code
* d1 -  o- number of characters sent
* d2 -ip - text length
* d3 -  o- 0 if a0=0, otherwise -1
* a0 -ip - channel id
* a1 -i o- pointer to text (updated past last sent)

ut_write
        moveq   #-1,d3          return when complete for all but chan 0
        move.l  a0,d0           is it command channel?
        bne.s   trap3
        move.l  d2,-(sp)
        moveq   #mt.inf,d0
        trap    #1
        sf      sv_scrst(a0)    command channel so unfreeze screen
        move.l  (sp)+,d2
        sub.l   a0,a0
        moveq   #0,d3           return immediate for chan 0 (and chan 1 retry)
trap3
        bsr.s   doit
        bne.s   exit
        move.l  #1<<16!1,a0     if not complete it must have been channel 0
        bsr.s   doit            try again on channel 1, but just one try
        sub.l   a0,a0           make it channel zero again
exit
        subq.l  #-err.nc,d0
        rts

doit
        moveq   #io.sstrg,d0    write string of characters
        trap    #3
        addq.l  #-err.nc,d0     was it non complete?
        rts

        end
