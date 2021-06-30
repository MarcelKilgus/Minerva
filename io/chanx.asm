* Checks if a particular channel exists
        xdef    io_chanx

        xref    ss_rte

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_jb'

        section io_chanx

* Only call from trap level as it does not return if channel does not exist.
* Bad channel, drop return, d0 = error not open, a0 unchanged and reshedule.
* a0 -i o- channel id to be checked / address of definition block
* a5 -  o- channel id
* d7 destroyed

io_chanx
        move.l  a0,d7           copy channel id
        cmp.w   sv_chmax(a6),d7 is it off end of table
        bhi.s   err_no          yes - actually an invalid id
        lsl.w   #2,d7           address of entry is 4*channel number
        move.l  sv_chbas(a6),a5 + base address
        add.w   d7,a5
        tst.b   (a5)            is it in table
        bmi.s   err_no          no - channel closed
        move.l  (a5),a5         set pointer to definition block
        swap    d7              get tag in bottom end
        cmp.w   ch_tag(a5),d7   is this the same tag?
        bne.s   err_no          no - channel re-used
        exg     a5,a0           swap channel address and channel id
        rts                     o.k. return

err_no
        move.l  sv_jbpnt(a6),a5 get current job slot
        move.l  (a5),a5         point to header
        bclr    #7,jb_rela6(a5) clear msb of relative flag
        addq.l  #4,sp           remove return address from stack
        moveq   #err.no,d0
        jmp     ss_rte(pc)      return direct to trap

        end
