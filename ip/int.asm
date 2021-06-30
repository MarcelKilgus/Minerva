* IPC interrupt routine
        xdef    ip_ipcr,ip_poll,ip_sched,ip_txqo
        xdef    ip_adcmd,ip_rdwr,ip_setad

        xref    ip_kbend,ip_kbrd
        xref    io_qin,io_qout,io_qtest
        xref    mm_rechp

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_q'
        include 'dev7_m_inc_ser'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_ipcmd'
        include 'dev7_m_inc_assert'

        section ip_int

* Check out the IPC as one of the routines on the frame interrupt polling list.
* d0-d2/d4-d7/a0-a3 destroyed.
* d3 -ip - count of missed poll interrupts

ip_poll
        move    sr,-(sp)
        or.w    #$700,sr        disable interrupts
        bsr.s   ip_ipcr
        move    (sp)+,sr        n.b. rte is no good on a 68020
        rts

* This maintains the sound and wp flags, keyboard and serial port input.
* It is called on either frame or interface interrupts.
* d3 -ip - count of missed poll interrupts
* a0 -  o- pc_ipcrd
* a1 -  o- pc_ipcwr
* d0-d2/d4-d7/a2-a3 destroyed.
ip_ipcr
        moveq   #stat_cmd-32*3,d1 status command + read a byte (2 nibbles)
        bsr.s   ip_adcmd        set a0-a1, ask for status and receive status
                ;               1?w21??sk-------
        exg     d1,d7           save it
        assert  0,ipc..kb
        ; bit 7 is the last bit fetched, and the n flag will be set by it
* Also see if there is input pending on the keyboard
        bpl.s   nokbd           don't bother if not
        move.l  sv_keyq(a6),d0  fetch ptr to current keyboard queue
        beq.s   nokbd           no queue, don't bother reading the IPC

        move.l  d0,a2
        moveq   #rdkb_cmd-32*2,d1 read kbd command + read one nibble
        bsr.s   ip_cmd          give it
        ror.w   #7,d1
        move.b  d1,d5           save it for "held" flag in bit 4
        moveq   #7,d4
        and.b   d1,d4           extract number of keystrokes
        bra.s   char1           enter at bottom of loop

rdch
        moveq   #-2*3,d1        read 3 nibbles
        bsr.s   ip_rdwr         read the shift/ctrl/alt nibble and key number
        lsr.l   #7,d1           key number byte in d1
        move.w  d1,d2
        lsr.w   #8,d2           shift/ctrl/alt in d2
        jsr     ip_kbrd(pc)     go process it
char1
        dbra    d4,rdch         and again if there are more characters
        jsr     ip_kbend(pc)    go finish off autorepeat setting
nokbd

* update the sound process finished system variable
        rol.w   #9+ipc..kb-ipc..so,d7
                ;               1?w21??s carry=s
        scs     sv_sound(a6)    set to ones if running, else zero
                ;               1?w21??s
        rol.b   #8+ipc..so-ipc..wp,d7
                ;               21??s1?w carry=w, sign=ser2
        scc     sv_wp(a6)       set the write protect flag, IPC P26 input
        move.l  sv_chtop(a6),a3 get extension address
        move.b  d7,$4e(a3)      experimental 21??s1?w
* now see if there is input pending on the rs232 channels
        assert  ipc..s2,ipc..wp-1
        bpl.s   noser2
        moveq   #rds2_cmd-3*32,d5 read serial 2 + read a byte (2 nibbles)
        move.l  sv_ser2c(a6),d0 fetch queue pointer
        bsr.s   rdser           get the input (maybe)
noser2

        assert  ipc..s1,ipc..s2-1
                ;               21??01?w
        add.b   d7,d7           check for ser1 and state of wp
                ;               1??01?w0 sign=ser1
        bpl.s   noser1
        moveq   #rds1_cmd-3*32,d5 read serial 1 + read a byte (2 nibbles)
        move.l  sv_ser1c(a6),d0
        bsr.s   rdser           get the input (maybe)
noser1
        rts
* set up addresses for the IPC read and write routines

* a0 -  o- pc_ipcrd, IPC read address
* a1 -  o- pc_ipcwr, IPC write address

ip_setad
        lea     pc_ipcwr,a1     write address
        lea     pc_ipcrd-pc_ipcwr(a1),a0 read address
        rts

* IPC combined command and read routine

* The input value contains up to 6 command nibbles and a count.
* Three entries points are provided, the first of which (ip_adcmd) calls
* ip_setad to set up a0-a1 before dropping into the second (ip_cmd) which just
* rolls the 4 lsbs around to the top to provided the initial command nibble.
* The final entry (ip_rdwr) is then dropped into.
* Bits 31..8 are then the command/data nibbles, with all ones (15) used for
* pure reading, and they are sent starting with the nibble in bits 31..28.
* Bits 7..4 are ignored, but for convenience they will probably be set to ones.
* Bits 3..1 may be -1..-6(7..2), giving the negated total nibble count (1..6).
* Bit 0 is ignored.

* If the above seems complicated, it is simple to use, with typical calls:
* To send an initial command nibble: "moveq #xxx_cmd-32,d1;jsr ip_adcmd".
* Another command & read "n" nibbles "moveq #xxx_cmd-32*(1+n),d1;jsr ip_cmd"
* To just read "n" nibbles "moveq #-2*n,d1;jsr ip_rdwr".

* The returned value will provide up to six nibbles in bits 30..7, the one in
* bits 14..7 being the last, or only, such nibble. X and bits 31 down will in
* fact be the bits after the last bit that was sent, if that's of any use!
* The remaining bits 6..0 are as read from pc_ipcrd along with the final bit.
* The final bit will set the ccr n flag.

* The reasoning behind combining the read and write functions like this is that
* the IPC takes a little time to process each bit, enough to set up a new write
* value without impairing the overall speed. The code here is arranged to make
* the actual handshake with the IPC turn round bits as rapidly as they can be
* read, with just one instruction more than if they were merely being written.
* By allowing up to six nibbles to be involved in each transfer, we are able,
* for example, to read the serial input three bytes at at time.

* d1 -i o- nibble count and commands / read nibbles in 30..7 (ccr for 7..0)
* a0 -ip - pc_ipcrd
* a1 -ip - pc_ipcwr
* d0/d6 destroyed (d0.l=12+2*<last bit sent>, d6.l=$ffff0001)

ip_adcmd
        bsr.s   ip_setad        set up addresses
ip_cmd
        ror.l   #4,d1           roll command to top nibble
ip_rdwr
        add.l   d1,d1           note lsb now zero
        moveq   #%1100>>2,d0    forming write byte for first bit
        roxl.b  #2,d0
        move.b  d0,(a1)         send it now, to get the IPC under way
        moveq   #-2-7*4,d6      %1111ccc10, ccc = -ve total nibble count
        or.b    d1,d6           form -ve count now, before waiting for the IPC
iploop
        add.l   d1,d1           roll up the read bit
        moveq   #%1100>>2,d0    forming write byte for next bit
        roxl.b  #2,d0
ipwait1
        btst    #6,(a0)         has the previous bit been used by the IPC yet?
        bne.s   ipwait1         no, wait for it
        move.b  (a0),d1         get data bit in bit 7
        move.b  d0,(a1)         we are ready instantly to send next write byte
        addq.w  #1,d6           (pity, but 2 extra cycles for addq.l)
        ble.s   iploop          go start preparing next write byte
        add.l   d1,d1           roll up the penultimate bit
ipwait2
        btst    #6,(a0)         has final bit been processed by the IPC?
        bne.s   ipwait2         no - wait for it
        move.b  (a0),d1         get final data bit in bit 7, plus rest of stuff
        rts

* This routine gets a stream of bytes from the serial input channel of the IPC
* and shoves them into the appropriate queue.

* ccr-i  - z set if d0.l=0
* d0 -i  - serial channel queue address
* d5 -ip - IPC serial read command for this channel
* a0 -ip - pc_ipcrd
* a1 -ip - pc_ipcwr
* a2 -  o- serial channel queue address
* d1-d2/d4/d6/a3 destroyed

rdser
        beq.s   rts0            no queue, so leave data in IPC
        move.l  d0,a2           set up serial channel
        bsr.s   qtest           see how much room in queue
        cmp.w   #sbsize,d2      is it enough for a full IPC buffer?
        blt.s   rts0            can't guarantee we can read it all, so leave it
        move.l  d5,d1           restore the appropriate IPC command
        bsr.s   ip_cmd          send it, read number of bytes to be transferred
        ror.w   #7,d1
        lea     sv_timov-rds1_cmd+3*32(a6),a3 base serial control byte address
        assert  rds1_cmd,rds2_cmd-1
        add.w   d5,a3
        moveq   #-32,d4
        and.b   d1,d4
        or.b    d4,(a3)         accumulate lost data/frame error/?? flags
        eor.b   d1,d4           keep the byte count (0..31(23))
        bra.s   rsent           enter loop

rdsch
        moveq   #-2*6,d1        three bytes (6 nibbles)
        bsr.s   ip_rdwr         read them in
        add.l   d1,d1           put them in msbs
        bsr.s   qnext           stuff first
        bsr.s   qnext           stuff second
        bsr.s   qnext           stuff third
rsent
        subq.b  #3,d4
        bge.s   rdsch           loop around
        addq.b  #3,d4
        beq.s   rts0            finished if multiple of 3
rsone
        moveq   #-2*2,d1        one byte (2 nibbles)
        bsr.s   ip_rdwr
        ror.w   #7,d1
        bsr.s   qin
        subq.b  #1,d4
        bne.s   rsone
rts0
        rts

qnext
        rol.l   #8,d1
qin
        jmp     io_qin(pc)

* Scheduler list routine for handling serial output

* d3 -ip - count of missed poll interrupts
* d0-d2/d4-d6/a0-a5 destroyed.

ip_sched
        sf      d4              say this is from scheduler loop
        move    sr,-(sp)
        or.w    #$700,sr        disable interrupts
        bsr.s   ip_txqo         go send any rs232
        move    (sp)+,sr        n.b. rte is no good on a 68020
        rts                     back to calling code

qtest
        jmp     io_qtest(pc)

* This is called either via ip_sched, or on rs232 transmit interrupts.
* It will swap queues when nothing can be done on the one it is looking at,
* and, as a new enhancement, it will only change over if there is something to
* be sent by the other channel.
* It takes a byte out of the transmit queue (if there is one) and sends it
* over the serial channel.
* If this has been called from the scheduler, memory is released if the
* transmit queue is closed and both queues for a port are empty.

* d3 -ip - count of missed poll interrupts
* d4 -ip - lsb $ff = interrupt, 0 = scheduler
* d0-d2/d5-d6/a0-a5 destroyed.

ip_txqo
        lea     pc_mctrl,a1     set up control register address
        btst    #pc..txfl,(a1)  is transmit buffer full?
        bne.s   rts0            yes - don't bother even think about sending
        lea     sv_tmode(a6),a4 set address of transmit mode system variable
        moveq   #0,d5           set msb zero, so we know what we're doing
        move.b  (a4),d5         get transmit mode
        assert  pc..sern,pc..serb-1
        lsl.b   #8-pc..serb,d5  are we set to rs232 mode?
        bcs.s   rts0            no - don't try to transmit
        assert  pc..dtr1,pc..cts2-1
        spl     d5              find out which port is in use
other1
        move.b  d5,d6
        lea     sv_ser1c(a6),a5 address of ser1 receive queue
        bne.s   serset
        addq.l  #sv_ser2c-sv_ser1c,a5 ser2 queue
serset
        move.l  (a5),d1         is there a queue for this port?
        beq.s   q_change        there isn't one, try the other next time
        move.l  d1,a0           this is the receive queue
        lea     ser_txq-ser_rxq(a0),a2 this is the transmit queue
        bsr.s   qtest           have a look at the queue now, to delay h/s test
        beq.s   chk_hs          byte ready, so go start thinking
q_err
        addq.l  #-err.nc,d0
        bpl.s   q_change        if not eof, go try to change port
        tst.b   d4              check if this is a scheduler loop call
        bne.s   q_change        no - can't do eof as it releases memory
        move.l  a0,a2
        bsr.s   qtest           have a look at the receive queue
        beq.s   q_change        don't release if there's input data pending
        clr.l   (a5)            clear queue pointer
        sub.w   #ser_rxq,a0
        jmp     mm_rechp(pc)    get rid of the channel

chk_hs
        tst.b   ser_txhs+1-ser_txq(a2) are we checking handshakes?
        beq.s   txready         no - go straight for a byte
        addq.b  #pc..cts2,d6    get handshake bit number
        btst    d6,(a1)         how is the handshake line?
        beq.s   txready         ready - we'll go send this, or switch ports
q_change
        not.l   d5              have we looked at the other one yet?
        bmi.s   other1          no - so go see if that might be worth doing
* We drop out here when there was nothing we could do with either port.
rts1
        rts

* Everything ok, so let's send the byte qtest gave us, or switch channels
txready
        lea     sv_timov(a6),a3 set a convenient pointer
        tst.l   d5              are we looking at the current port?
        bpl.s   do_send         yes, so we really can send it
* Check for timeout before changing port
* ZX8302 should only be told change the port when all bytes sent to the current
* port must have certainly been transmitted, or they'll go to the wrong port!
        assert  sv_timo,sv_timov-2
        sub.w   d3,-(a3)        decrement timeout
        bge.s   rts1            still not down far enough
        clr.w   (a3)+           clear timeout, as top byte is set
        eor.b   #1<<pc..sern,(a4) change port in the system variable
do_send
        ext.w   d5
        moveq   #pc.bmask,d0    we want just the baud rate
        and.b   1(a3,d5.w),d0   we hold ser1/ser2 control bytes here now
        and.b   #-1-pc.bmask,(a4) lose baud rate in the system variable
        or.b    d0,(a4)         insert correct baud rate in the system variable
        move.b  (a4),pc_tctrl-pc_mctrl(a1) set the zx8302
        assert  sv_timo,sv_timov-2
        move.b  timov(pc,d0.w),-(a3) use table to set timeout
        move.b  d1,pc_tdata-pc_mctrl(a1) send byte now, as late at possible
        jmp     io_qout(pc)     discard the byte we have sent

* We know that we will not be here unless the transmit buffer was empty.
* We know this occurs 1/2 bit before the start, 8 data and 2 stop bits begin.
* Therefore we need only make sure that 11.5 bit times expire before we can
* change ports.
* We cannot count the first clock tick, because it may come instantly.
* At 60Hz tick rate, 11.5 bits at 75 baud require 60*11.5/75 = 9.2 ticks.
timov   dc.b    1,1,1,1,1,2,3,10

        end
