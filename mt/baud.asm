* Sets the baud rate
        xdef    mt_baud

        xref    ip_adcmd
        xref    ss_rte,ss_wser,ss_rser

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_ipcmd'
        include 'dev7_m_inc_assert'

        section mt_baud

* d0 -  o- err.bp if the baud rate is illegal, 0 if it's ok and has been set.
* d1 -i  - baud rate. one of 75/300/600/1200/2400/4800/9600/19200 or negative.

* An extended command for hermes allows the two ports to be individually set,
* and can prevent the simple calls from affecting the baud rates if they say
* not to.
* The format is to give d1.w with bits 15..7 all 1, bit 6 = 0/1 for ser1/ser2,
* Bit 5 zero and a value in bits 4..0 to be stored in the control byte.
* Bit 4 set means ordinary mt.baud calls will no longer affect this port.
* Bit 3 is reserved and should be zero.
* Bits 2..0 give the baud rate.
* Bit 1 of sx_toe may be set to disallow the extended command.
* The existing control byte, with bit 7 set = bytes lost and bit 6 set = frame
* errors detected, is returned in d1.b. Bit 5 is undefined. Bits 4..0 are as
* above. This will also clear bits 7..5 of the control byte.

* The old code simply sets bits 2..0 of each byte of sv_timov to the calculated
* 0..7 baud rate, provided they do not have their inhibit flag (bit 4) set.

reglist reg     d3/d6/a0-a2/a4

mt_baud
        movem.l reglist,-(sp)
        move    sr,d3           save current status register
        or.w    #$700,sr        disable interrupts
        clr.b   d0              actually going to keep ser mode
        jsr     ss_wser(pc)     make sure any current transmit is finished
        jsr     ss_rser(pc)     go back to ser1
        moveq   #err.bp,d0      if baud rate not in table
        move.l  sv_chtop(a6),a4
        assert  1,err.bp&7
        btst    d0,sx_toe(a4)
        lea     sv_timov+2(a6),a4
        bne.s   std_baud
        move.w  d1,d7
        bpl.s   std_baud
        ext.w   d7
        cmp.w   d1,d7
        bne.s   std_baud
        lsl.b   #2,d7
        bmi.s   std_baud
        bcs.s   putser
        subq.l  #1,a4
putser
        move.b  -(a4),d1        pick up old setting
        lsr.b   #2,d7
        move.b  d7,(a4)         replace current setting for ser control
        lea     sv_timov(a6),a4
        bra.s   baud_ok

std_baud
        moveq   #7,d7
        move.w  #300>>1,a0      most double up, 300, 600... 19200 baud
        cmp.w   #75,d1          but first is 75 baud
        bra.s   chk_baud

look_up
        add.w   a0,a0           double baud rate next
        cmp.w   a0,d1           is that it?
chk_baud
        dbeq    d7,look_up      no - keep trying...
        bne.s   baud_ex         the encoded baud rate is in d7

        moveq   #baud_cmd-32*2,d1 change baud rate command plus 1 nibble
        lsl.w   #4,d1
        or.b    d7,d1           slot in baud rate nibble
        ror.l   #4,d1
        jsr     ip_adcmd(pc)    give command and parameter to ipc
        bsr.s   qorin           if allowed, put it into ser2 control
        bsr.s   qorin           if allowed, put it into ser1 control
baud_ok
        moveq   #7,d7
        and.b   (a4),d7         pick up current ser1 baud
        subq.l  #sv_timov-sv_tmode,a4 get address of the system variable
        bsr.s   orinbaud        always put it into sv
        move.b  (a4),pc_tctrl   write it to tx control reg
        moveq   #0,d0           ok
baud_ex
        move    d3,sr           reinstate interrupts
        movem.l (sp)+,reglist
        jmp     ss_rte(pc)      come back from trap

qorin
        btst    #4,-(a4)
        bne.s   rts0            only if inhibit bit is clear
orinbaud
        and.b   #$f8,(a4)
        or.b    d7,(a4)         change baud rate in this slot
rts0
        rts

        end
