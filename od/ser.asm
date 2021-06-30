* Serial port driver
        xdef    od_ser

        xref    io_name,io_qin,io_qout,io_qset,io_qtest,io_relio
        xref    mm_alchp
        xref    ip_adcmd

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_ipcmd'
        include 'dev7_m_inc_q'
        include 'dev7_m_inc_ser'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'

* Notes by lwr:
* This has all been shuffled about quite a bit, in an attempt to get toward
* properly functioning serial channels. The current version still suffers from
* some problems.
* The main problem is that handshaking can only be actioned at the stage of
* actually sending bytes to the IPC. Swapping between 'seri' and 'serh' opens
* will not get this right. However, this seems to be the least of evils, as one
* will usually be changing the harware plugged into the port in these cases.
* All other handling is done here, including making the close do generation of
* ctrl/z if required.
* The serial queues now contain only raw data to/from the serial ports.
* The action of "serc" is now treated as an exchange of cr/lf values.
* The I/O translation routines now occur between parity/handshake and protocol
* (cr<-->lf and ctrl/z) handling.
* The only user translation that is difficult/impossible at the moment is the
* one-to-many conversion of data coming from the serial queue.

* The current sequence of operation goes like this:

* sbyte/close -> lf/cr/cz -> user -> parity_gen -> queue -> handshake -> ipc
* ipc(handshake) -> queue -> parity_check -> user -> cr/lf/cz -> fbyte

        section od_ser

* The rules for the user routines 
od_ser
        dc.w    io-*
        dc.w    open-*
        dc.w    close-*
io
        jsr     io_relio(pc)    use standard relative serial i/o
        dc.w    pend-*
        dc.w    fbyte-*
        dc.w    sbyte-*

* Open a serial i/o channel.

* The name is structured as "ser{1|2}{o|e|m|s}{i|h}{r|z|c}
*       port number (1 or 2, default 1)
*       parity (0=8 bit, 1=odd, 2=even, 3=mark, 4=space)
*       use/ignore transmit handshake signals (0=ignore, other(default)=use)
*       protocol >0 <cr/lf>, 0=ctrlz, <0=raw (default raw)

open
        subq.l  #2*4,sp         make room for parameters
        move.l  sp,a3           point a3 to them

        jsr     io_name(pc)     decode the name
        bra.s   opn_pop         not ser
        bra.s   opn_pop         bad parameter
        bra.s   opn_ser         ok
        dc.w    3,'SER',4,-1,1,4,'OEMS',2,'IH',3,'RZC'

opn_pop
        addq.l  #2*4,sp         discard parameter area
rts0
        rts

opn_ser
        movem.w (sp)+,d4-d7     get parameters
        subq.w  #1,d6           adjust handshake
        subq.w  #2,d7           adjust protocol
        moveq   #err.nf,d0
        move.w  d4,d1
        lea     sv_ser1c(a6),a5 set address of ser1 queue pointer
        subq.w  #1,d1
        beq.s   chk_inus
        addq.l  #sv_ser2c-sv_ser1c,a5 change to ser2 queue pointer
        subq.w  #1,d1
        bne.s   rts0            only support ser1 or ser2
chk_inus
        move    sr,-(sp)        save interrupt status
        or.w    #$700,sr        disable interrupts to enable reopen
        move.l  (a5),d0         is a serial channel already allocated
        beq.s   alloc           no - go allocate it

        move.l  d0,a2           start of receive queue
        lea     -ser_rxq(a2),a0 start of definition
        moveq   #err.iu,d0
        assert  0,q_eoff,q_nextq
        bclr    #7,ser_txq(a0)  was transmit eofed? (but it isn't now)
        beq.s   popsr           no - that's no good, someone's got it open!
*        clr.l   (a2)            clear q_eoff (and q_nextq?) for receive queue
* N.B. We'll leave the receive queue pointers alone, as there may well be
* input buffered up there waiting for us. (lwr)
        bra.s   set_parms

* Allocate definition block and set up queues

alloc
        move.w  #ser_end,d1     number of bytes needed (n.b. d1 msw is zero)
        jsr     mm_alchp(pc)    allocate space
        bne.s   popsr           sorry...

        lea     ser_txq(a0),a2  set start of transmit queue
        moveq   #ser_txql,d1    set queue length
        jsr     io_qset(pc)     set up the transmit queue
        lea     ser_rxq(a0),a2  set start of receive queue
        assert  ser_rxql,ser_txql
        jsr     io_qset(pc)     set up the receive queue
        move.l  a2,(a5)         tell physical layer where new receive queue is

* Store the parameters

set_parms
        assert  ser_chno,ser_par-2,ser_txhs-4,ser_prot-6
        movem.w d4-d7,ser_chno(a0) put them all
        moveq   #ops1_cmd-1-32,d1

* Tell the IPC what's going on
do_com
        assert  ops1_cmd,ops2_cmd-1
        assert  cls1_cmd,cls2_cmd-1
        add.w   ser_chno(a0),d1
        move.l  a0,a2           save channel base
        move.l  d6,d2           just for close, adhere to rule: d6 preserved
        jsr     ip_adcmd(pc)    do ipc command
        move.l  d2,d6
        move.l  a2,a0           restore channel base
        moveq   #0,d0           set return code
popsr
        move    (sp)+,sr        n.b. rte is no good on a 68020, etc
        rts

* Close a serial channel.
* The channel structure is not discarded here, as there may be further data
* pending in the transmit queue. This deserves more thought! (lwr)

close
        tst.b   ser_prot+1(a0)  is it ctrl/z or crlf protocol?
        bmi.s   cl_czok         nope - no ctrl/z needed
cl_czlp
        moveq   #'z'&31,d1      we need to put ctrl/z onto the queue
        bsr.s   sbyte           try to put out the ctrl/z
        addq.l  #-err.nc,d0     is it not complete?
        beq.s   cl_czlp         hopefully, we will eventually get there!

* The above loop is not wildly satisfactory, as it can be held up indefinately
* by a "serh" channel with the handshake holding off output permanently.
* The original technique relied on outputting the ctrl/z when the IPC had
* emptied the queue, but this was prone to the syndrome of changing
* protocols before the code had actioned the protocol. E.g. sending a series
* of small ctrl/z files, then changing to "serr" would not send any ctrl/z's!
* An alternative scheme to avoid the handshake problems suffers from the same
* flaw as the above. This would be to use a special byte in the output queue
* as an "escape" character. A preferred value would be a zero byte. The output
* would then double up single nulls when they were real, say, and restore them
* in the input routine. Other byte values after a null would be used to pass
* open/close parameters down.

cl_czok
        move    sr,-(sp)
        or.w    #$700,sr        be cautious - make sure no mishaps! (lwr)
        tas     ser_txq+q_eoff(a0) ok, so we know how to set end of file!
*        lea     ser_txq(a0),a2  set end of file
*        jsr     io_qeof(pc)     mark queue as end of file
        moveq   #cls1_cmd-1-32,d1
        bra.s   do_com

* Come here to test if the serial port has input pending
pend
        lea     ser_rxq(a0),a2  get queue address
        jmp     io_qtest(pc)    see if queue is empty

* Read a character from a serial port.
* The code that stuffed the bytes into the queue is in the ipc routines.
* This routine takes a byte out of the specified queue, and checks any parity.
* An optional user routine may then be used to convert the byte. This can
* discard unwanted bytes by setting d0=err.nc and skipping its return address.
* Many-to-one conversions may be acheived by retaining context. One-to-many
* conversions are currently difficult/impossible!
* The cr/lf and ctrl/z requirement are actioned last.

fbyte
        lea     ser_rxq(a0),a2  get address of queue
        jsr     io_qout(pc)     take out a byte
        bne.s   rts1            there isn't one...

        move.b  ser_par+1(a0),d2 get parity requirements
        beq.s   rx_pok          no parity required - go check next bit
        subq.b  #2,d2           odd=-1 even=0 mark=1 space=2
        bhi.s   rx_plus         mark/space - go check it
        moveq   #127,d0         don't include the top bit
        and.b   d1,d0
rx_shft
        eor.b   d0,d2           flip lsb of parity reg for one bit
        lsr.b   #1,d0           shift next bit
        bne.s   rx_shft         loop until all non-zero bits done
rx_plus
        lsl.b   #7,d2           move type bit to msb
        eor.b   d2,d1           flip top bit of data byte
        bmi.s   err_te          now set - go report error
rx_pok

        moveq   #sx_itran,d2    appropriate translation routine offset
        bsr.s   extrn           go see about it

        tst.b   ser_prot+1(a0)  is it ctrl/z or cr/lf protocol?
        blt.s   ok_rts          no - we're finished
        beq.s   rx_cz           zero, just do ctrl/z check
        bsr.s   cr_proto        handle cr/lf exchange

rx_cz
        moveq   #err.ef,d0
        cmp.b   #'z'&31,d1      is it ctrl/z?
        beq.s   rts1
ok_rts
        moveq   #0,d0
rts1
        rts

cr_proto
        moveq   #13,d0
        sub.b   d1,d0           is it cr?
        beq.s   rx_cr           yes, flip it
        subq.b  #13-10,d0       is it lf?
        bne.s   rts1            no, return now
        addq.b  #2*3,d1
rx_cr
        subq.b  #3,d1           cr <--> lf
        rts

err_te
        moveq   #err.te,d0      transmission error (and -ve for proto return)
        rts

* sx_itrn: input translation routine:
* d1 -i o- byte after parity action / byte to be cr/lf/cz processed
* a0 -ip - base of serial channel definition
* a2 -i  - base of serial input queue
* d0/d2-d3/a1/a3 destroyed.

* d1 should be used to supply bytes to the caller.
* Skipping the return address and setting d0 to err.nc will cause the input
* byte to be discarded. (d1 may be destroyed).
* Only one-to-none and one-to-one conversions are convenient.

* sx_otrn: output translation routine:
* d1 -i o- byte after cr/lf/cz action / byte to be parity processed
* a0 -ip - base of serial channel definition
* a2 -i  - base of serial output queue
* d0/d2-d3/a1/a3 destroyed.

* If the value in d1 is not to be sent, an appropriate value should be set in
* d0 (err.nc normally) and the return address skipped.
* A one-to-many translation must verify that the queue has space, by calling
* io_qtest through the vector at $de, and if there is insufficient space,
* set err.nc in d0 and skip the return address.
* If the space is ok, the return address should be "jsr"ed to for all but the
* last byte, leaving that to go as normal.
* Only one-to-none, one-to-one and one-to-many conversions are convenient.

* If the return address mentioned above is used, it requires the following:
* d0 -  o- 0 (or error - queue full (err.nc) - should never happen!)
* d1 -i o- byte to put in queue (output with parity actioned)
* a2 -ip - pointer to queue
* d2/a3 destroyed
 
extrn
        tst.b   sv_tran(a6)     check if translation wanted
        beq.s   rts1            no, leave it alone
        move.l  sv_chtop(a6),a3 dig into system extension
        move.l  0(a3,d2.l),a3   come out with current translate routine addr
        jmp     (a3)            call via vector

* Write a character to a serial port.
* This actions lf<->cr conversions first.
* An optional user routine may then handle the character.
* The byte is then stuffed in the output queue with appropriate parity.

sbyte
        lea     ser_txq(a0),a2  transmit queue address
        tst.b   ser_prot+1(a0)  is it ctrl/z or cr/lf protocol?
        ble.s   tx_nop          no - we're finished
        bsr.s   cr_proto        handle cr/lf exchange
tx_nop
        moveq   #sx_otran,d2    the appropriate user routine slot
        bsr.s   extrn           go do translate, if enabled
* N.B. The remainder of this section may be "jsr"ed to by the user routine.
        move.b  ser_par+1(a0),d2 get parity requirements
        beq.s   tx_pok          no parity, send it as is
        add.b   d1,d1           lose current msb of byte
        lsl.b   #6,d2           odd=$40, even=$80, mark=$c0, space=$00
        add.b   d2,d2           odd/mark=$80, even/space=$00
        bvc.s   tx_par          mark/space - go put in the top bit
        move.b  d1,d0           make copy of remaining 7 bits of byte
tx_shft
        eor.b   d0,d2           flip msb of parity reg for one bit
        add.b   d0,d0           shift up next bit
        bne.s   tx_shft         loop until all non-zero bits done
tx_par
        add.b   d2,d2           move parity bit into x
        roxr.b  #1,d1           put it into the byte
tx_pok
        jmp     io_qin(pc)      stuff byte into queue

        end
