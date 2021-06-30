* Network physical layer
        xdef    nd_rpac,nd_spac

        xref    ss_rser,ss_wser

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_delay'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_net'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_sv'

        section nd_phys

* d0 -  o- error code, and sr set
* a0 -ip - channel definition block
* a2 -  o- pointer transmit control register
* a3 -  o- pointer to microdrive/link register
* d1-d3/a1 destroyed

reglist reg     d5-d7

* Calculate checksum

csumdata
        move.b  net_nbyt(a0),d1 get byte count
        lea     net_data(a0),a1 address of data
checksum
        moveq   #0,d7           initialise checksum
chks_byt
        add.b   (a1)+,d7        add byte to checksum
        subq.b  #1,d1
        bne.s   chks_byt        next byte
        rts

* Set up on entry

entry
        move.l  (sp)+,a1        get return address off stack
        lea     pc_mctrl,a3     set up pc register addresses
        lea     pc_tctrl-pc_mctrl(a3),a2
        moveq   #pc.netmd,d0    set up in network mode
        moveq   #1<<pc..serb,d3 internally, we want d3 permanently zero
        and.b   sv_tmode(a6),d3 is it in actually in rs232 mode
        bne.s   err_ne3         yes - leave this until serial o/p has cleared
        jsr     ss_wser(pc)     wait for serial to complete
        move    sr,-(sp)        save interrupt status
        or.w    #$0700,sr       disable interrupts
        movem.l reglist,-(sp)   save registers
        jsr     (a1)            call the return address
        movem.l (sp)+,reglist   reload registers
        jsr     ss_rser(pc)     return to serial mode
        move.w  (sp)+,sr        restore interrupt state
        tst.l   d0              set condition codes
        rts

* Send packet

nd_spac
        bsr.s   entry           set up
        bsr.s   csumdata        calculate data checksum
        move.b  d7,net_dchk(a0) save it
        moveq   #net_hchk-net_hedr,d1 sum bytes of header for checksum
        lea     net_hedr(a0),a1
        bsr.s   checksum        calculate header checksum
        move.b  d7,(a1)         and save it in the next location
        subq.l  #net_hchk-net_hedr,a1 restore a1 to point to header

* Send a scout
        assert  net_hedr,net_self-1
        move.w  (a1),d6         get station number in lsb
        not.b   d6              inverted
        move.b  sv_tmode(a6),d2 get basic byte to send to xmit reg
        moveq   #10-1,d1        send station number, 2*inactive: 10 bit
        moveq   #115,d0
        mulu    sv_rand(a6),d0
        move.w  d0,sv_rand(a6)  set up random wait >3ms=536 loops
        ext.w   d0              ... d0 becomes -128 to 127
        add.w   #536+128-1,d0   ... now 536-1 to 891-1, 3 to 5.7 ms
ss_wait
        btst    d3,(a3)         12 check if net is idle
        bne.s   err_ne3         12 ... no it's not
        dbra    d0,ss_wait   18/26 loop is 42-48 cycles 5.6 us min
ss_bit
        lsl.b   #1,d6           12 get next bit out of station number
        rol.b   #1,d2           12
        roxr.b  #1,d2           12 and put it in basic byte
        move.b  d2,(a2)         12 send next bit
        bmi.s   ss_activ     18/12 if output is active - cannot test
        moveq   #6-1,d0         08 test output 6 times
ss_test
        btst    d3,(a3)         12 check if network is active
        beq.s   ss_tdbra        18 funny test to make loop n*12
err_ne3
        bra.s   err_ne2         ... oops

ss_tdbra
        dbra    d0,ss_test   18/26 loop is 48 cycles long
        bra.s   ss_next         18

ss_activ
        moveq   #17-1,d0        08 wait a bit
        dbra    d0,*           314
ss_next
        dbra    d1,ss_bit    18/26 bit loop is 402 cycles (active) 412 (test)

* Scout sent ok
        moveq   #net_data-net_hedr,d1 send header first, bit 15 = header/data
        bsr.s   output          send header
        tst.b   net_dest(a0)    are we doing a broadcast?
        beq.s   sp_bcst         yes - we don't want an ack
sp_block
        addq.b  #1,d1           read one byte response
        lea     net_data-1(a0),a1 stuff it in end of header block
        bsr.l   inpbyte         fetch byte (in both d2 and d7)
err_ne2
        bne.s   err_ne1
        subq.b  #1,d7           check if response was acknowledge
        bne.s   err_ne1
        not.w   d1              was that the data?
        bpl.s   inc_blk         yes - go update block count
        bsr.s   outpdata        send data
        bra.s   sp_block        go back to get acknowledge

* Send header/data/acknowledge

* d1 -i o- lsb only: byte count / 0
* d7 -  o- 0
* d6 -i o- byte to be sent, bits 15..14 one / $(ffff)ff00
* a1 -i o- data pointer / updated
* d3/a0/a2/a6 standard

outpdata
        move.b  net_nbyt(a0),d1 send all bytes of data block
output
        moveq   #-1,d6          08 preset top byte of word to ones
outb_byt
        move.b  (a1)+,d6        12+ get next byte
outpack
        lsl.w   #1,d6           12 clear lsb for start flag
        rol.w   #2,d6           14 set two lsbs for leader/stop
        moveq   #13,d7          08 13 bits - 2 leader, start, 8 data, 2 stop
        move.b  sv_tmode(a6),d0 20 set up basic byte to write to xmit reg
outb_bit
        asr.w   #1,d6           12 shift next bit out and bring a one in
        addx.b  d0,d0           08 roll it into basic byte lsb
        rol.b   #7,d0           24 roll back to bit 7
        move.b  d0,(a2)       12+1 send bit
        subq.w  #1,d7           08 decrement counter
        bne.s   outb_bit     18/12 loop is 83 cycles long
        subq.b  #1,d1           08
        bne.s   outb_byt     18/12 stop is 4 bits+ a bit
        move.b  sv_tmode(a6),(a2) 16 deactivate net
        rts

* Final bits

sp_bcst
        delay   500             ; give receiver time to get to reading data
        bsr.s   outpdata
        delay   2000            ; give other end a chance to use the data
inc_blk
        addq.b  #1,net_blkl(a0) increment block count
        bcc.s   okrts1
        addq.b  #1,net_blkh(a0) and upper byte
okrts1
        moveq   #0,d0
        rts

* Receive a packet from the net

nd_rpac
        bsr.s   rpac_nc         initially sets nothing read / not end of file
        bsr.l   entry

* Wait for a gap in transmission
rwait_gp
        move.w  #5859-1,d6      give up waiting after 5859*8.5=50ms of active!
rwait_2m
        move.w  #438-1,d0       16 wait for 438*6.4=2.8ms of solid no activity
rwait_lp
        btst    d3,(a3)         12 is net active
        beq.s   rwait_nx        18 no ... decrement gap time counter
        dbra    d6,rwait_2m  18/26 start waiting again, or timeout
err_ne1
        bra.s   err_nc0         exit if no suitable gap in transmission

rwait_nx
        dbra    d0,rwait_lp  18/26 48 cycles / 6.4 us loop

* Wait for a scout

        move.w  #3125-1,d0      timeout = 3125*6.4=20ms

rwait_sc
        btst    d3,(a3)         12 wait for beginning of scout
        bne.s   got_sc          18 drop out if beginning of scout
        dbra    d0,rwait_sc  18/26
        bra.s   err_nc0         no scout in 20ms, so return nc

* Got the scout - so wait until it has gone away
got_sc
        delay   530             ; wait for end of scout

        moveq   #net_data-net_hedr,d1 read 8 bytes
        bsr.s   inpdata         header to data, last byte (hchk) left in d2
        subq.l  #net_data-net_hedr,a1 backspace buffer pointer
        bne.s   rwait_gp        skip if it timed out
        assert  net_hchk,net_data-1
        sub.b   d2,d7           check checksum (checksum has been summed)
        cmp.b   d2,d7
        bne.s   rwait_gp
* We have seen a valid header, so we don't go back looking for a scout anymore
* since, if the packet isn't for us, we don't want to waste time here with the
* following data block.

* Now check if this packet is for me
        assert  net_hedr,net_dest,net_self-1
        move.w  net_dest(a0),d7 fetch my own station numbers
        ror.w   #8,d7           swap them over
        cmp.w   (a1),d7         do source and dest cross match?
        beq.s   chk_blk         yes - that's great
        tst.b   d7              if destination (self) is zero - broadcast
        beq.s   chk_dest        yes - check if just destinations match
        cmp.b   net_self(a0),d7 is it the 'receive from any' code?
        bne.s   err_nc0         no - return nc and ioss will try again later
chk_dest
        cmp.b   (a1),d7         do destinations match?
        bne.s   err_nc0         no - return nc and ioss will try again later

* Properly addressed to us, so check if this data block is the one required
chk_blk
        bsr.s   goodhdr         go sort out valid header
        bne.s   rpac_nc
        cmp.b   net_dchk(a0),d7 check checksum
        bne.s   rpac_nc
        bsr.s   acknwldg        all ok - acknowledge
        tst.w   d5              check this was the right block
        beq.s   inc_blk
rpac_nc
        assert  net_type,net_nbyt-1
        clr.w   net_type(a0)    nothing read / not end of file
err_nc0
        moveq   #err.nc,d0      not complete
        rts

* Send acknowledgement

acknwldg
        moveq   #1,d1           write one byte
        move.w  #$ff01,d6       the acknowledge byte is a one
        tst.b   net_dest(a0)    are we receiving a broadcast?
        bne.l   outpack         no - go do it
rts9
        rts                     yes - don't bother acknowledging

goodhdr
        assert  net_hedr,net_blkl-2,net_blkh-3
        move.l  (a1),d5         fetch incoming block number to lsw
        sub.w   net_blkl(a0),d5 and compare against required
        bne.s   rblock          if not correct skip it (other missed ack)
        assert  net_type,net_nbyt-1,net_dchk-2,net_hchk-3,net_data-4
        move.l  net_type-net_hedr(a1),-(a1) copy flag, nbytes etc
* If the acknowledges fail, or the data's bad, we'll have to clear this again
rblock
        bsr.s   acknwldg        acknowledge header
        move.b  net_nbyt(a0),d1 set up number of bytes to read
* Drop through to read the data bytes

* Read a block from the net and accumulate checksum
inpdata
        lea     net_data(a0),a1 put it in data block
inpbyte
        moveq   #0,d7           clear checksum
        move.w  #400,d0         wait for active up to 400*48 cycles 2.56 ms
i_wnext
        dbra    d0,i_wait    18/26 loop 48 cycles
        bra.s   err_nc0            exit if timed out

i_bytwt
        btst    d3,(a3)         12 wait for start bit
        dbeq    d6,i_bytwt   18/26/20 loop is 30 cycles
        bne.s   err_nc0         12 not complete if no start bit found
        moveq   #8-1,d6         08 read 8 bits
        moveq   #0,d0           08 one shot at validating stop bit / ok exit
        ror.b   #4,d3           18 delay
i_bit
        ror.l   #8,d2           28 save bits so far at msb, and delay
        move.b  (a3),d2         12 read bit (106..117 cycles since start bit)
        rol.l   #7,d2           26 construct byte
        dbra    d6,i_bit     18/26 loop is 84 cycles
        move.b  d2,(a1)+        12+ store byte
        add.b   d2,d7           08 accumulate checksum
        subq.b  #1,d1           08
        beq.s   rts9            12 exit ok, all done
* Now validate 1st (or 2nd) stop bit, 104 cycles after last test
i_wait
        btst    d3,(a3)         12 is net active yet
        beq.s   i_wnext      18/12 funny test to make wait loop n*48
        moveq   #71-1,d6        08 give up after about 30*71 cycles (2 bytes)
        bra.s   i_bytwt         18

        end
