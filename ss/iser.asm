* Handle serial port interleaving
        xdef    ss_rser,ss_wser

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_vect4000'

        section ss_iser

* Wait for completion of serial transmit

* Note: this uses an entirely new method of waiting, which depends on bit 7, in
* the pc_intr byte (which i will refer to as "baud", and which is a square wave
* at the current baud rate), making it totally gold card compatible.
* experimentally verified, the following sequence of events takes place during
* serial transmissions:

* 1) a byte written to pc_tdata will instantly set pc..txfl in pc_ipcrd.
* 2) this is recognised at the next trailing edge of baud (going from 1 to 0)
* 3) at the next trailing edge of baud, pc..intt in pc_intr is set to one.
* 4) not quite instantly after this, pc..txfl goes to zero.
* 5) another byte may be sent at this point.
* 6) on the next leading edge of baud, the serial line begins the start bit.
* 7) the data bits and two stop bits are started on subsequent leading edges.
* 8) if another byte had been sent, pc..txfl will go to zero half way through
*    the final stop bit, just after that trailing edge of baud, and thus
*    repeating the pattern from 4) above.

* Unfortunately, once pc..txfl has gone away, there is no guaranteed way to
* tell where within the last byte one might be.

* d0 -i  - pc.netmd for net required, pc.mdvmd for mdv required

ss_wser
        subq.w  #1,sv_timo(a6)  decrement timeout
        blt.s   nowait          fine if it was zero (or negative!)
wait
        move.l  d0,-(sp)        save operation
full
        btst    #pc..txfl,pc_ipcrd
        bne.s   full            wait until transmit buffer is empty
        moveq   #12-1,d0        start bit comes 1/2 bit later, 8 data + 2 stop
high
        tst.b   pc_intr
        bmi.s   high             (actually always low when buffer empties)
low
        tst.b   pc_intr
        bpl.s   low
        dbra    d0,high
        move.l  (sp)+,d0        restore operation
nowait
        clr.w   sv_timo(a6)     clear wait
        and.b   #pc.notmd,sv_tmode(a6) not rs232
        or.b    d0,sv_tmode(a6) either mdv or net
        assert  1<<7,pc.maskt
        bclr    #7,sv_pcint(a6) disable transmit interrupt
        bra.s   exit

* Re-enable serial transmit

ss_rser
        and.b   #pc.notmd,sv_tmode(a6) set rs232 mode, ser1
        tas     sv_pcint(a6)    enable transmit interrupt
exit
        move.b  sv_tmode(a6),pc_tctrl set pc
        rts

        vect4000 ss_rser,ss_wser

        end
