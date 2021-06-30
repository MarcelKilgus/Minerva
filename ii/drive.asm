* Inter-integrated circuit (IIC or I squared C) bus driver
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_vect4000'

* Timing requirements for the I2C bus:

* f SCL (100khz = 75 cycles) must not be exceeded.
* t buf (4.7us + max 1us < 43 cycles) is fine, as we'll be between controls.
* t hd;sta (4.0us + max 300ns < 33 cycles) is similar.
* t low (SCL) (4.7us + max 300ns < 38 cycles) is one main constraint.
* t high (SCL) (4.0us + max 1us < 38 cycles) is the other main constraint.
* t su;sta (4.7us + max 1us < 43 cycles) is "between controls", so it's easy.
* t hd;dat we will assume zero, as we're not into cbus compatibility (yet?).
* t su;dat (250ns < 2 cycles) means we can use ".w" instructions!
* t su;sto (4.7us + max 1us < 43 cycles) we can cope with.

* Our waveform for SCL should come out as 38/38 cycles, to get it all right.

* We will work on the basis of using no write accesses to RAM, so we can use
* this code during boot up.

* While addressing a device, we will check that we are seeing on SDAin what we
* are sending on SDAout, and return err.ff if there is a mismatch, i.e. the
* board isn't an I2C Minerva.

* If the acknowledge for a device fails we report err.nf which on boot up will
* just mean the battery backed up RAM and clock is not fitted.

* The first thing on boot up will be to waggle SDA and SCL about with an
* "initialise" sequence, just in case the machine has been rebooted in the
* midst of a read sequence.

* The RAM/clock chip is device $a0 giving a good chance of recognising old
* Minerva boards, as we will be expecting to see a mix of ones and zeros on
* SDAin as we address it.

* We will try to make the interface pretty clever, but not too clever.
* Wequencing will be done by bytes from a read only "control" buffer.

* The device address will be held in a register, but a control will enable
* this to be replaced from the control buffer.

* The crux of the matter comes when we are asked to do multi-byte transfers to
* or from a RAM buffer. This part of the code is the only part that must be
* able to run as close to the maximum clock rate as we can manage. All other
* actions can limp along as slow as is convenient.

* It will be possible to carry out a sequence containing multiple reads and/or
* writes in an uninterruptable fashion. The prime one needed at present being
* to suspend the clock by writing to location 0, reading back locations and
* then releasing the clock to count again. Although this could be done by
* several calls, we will allow for it to be done in a single call, saving us
* some time when time is in fact a little important: we would like to be able
* to use the 1/100th second timing information with some accuracy.

* Write sequences will have the option of sending data bytes from either the
* data buffer or the control buffer. When reading, the bytes will go to either
* the data buffer or be rolled into a register.

* The control buffer will be organised as a series of individual bytes:

* Parameter build byte:
*
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*       |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  | 
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*       |  0  |        seven parameter data bits        |
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*
* The contents of the parameter byte are shifted left seven bits, and this byte
* is "or"'ed into it. A contiguous sequence of five of these can be used to set
* up a full 32 bits of parameter. Only two uses of this are currently made.
* A single byte is used before a special command which is to copy it to the
* device group register, So we can change devices during a sequence. The other
* usage is to set up the byte count for a normal i/o command. This will only
* make use of a 16-bit count, and may need anything from zero to three of these
* parameter build bytes. The parameter register is always cleared to zero after
* each of the normal I/O and special byte types has been processed.

* Normal input/output byte:
*
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*       |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  | 
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*       |  1  |  0  |  s  |  r  |  b  |  p  |  a  |  0  |
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*
* The bits of this byte are essentially handled from left to right, to allow
* the most typical i/o sequence to be handled in its entirety.
*
* s = 0: no START required
* s = 1: send START and device
* r = 0: write mode, or r = 1: read mode
* b = 0: if r=0, write from control, or r=1 read to register
* b = 1: write/read uses data buffer
* p = 1: send STOP sequence
* a = 1: send acknowledge on last read (r=1) byte
*
* r=0 and a=1 is invalid, as is r=1, p=1 and a=1. Also bit 0 must be clear. If
* these conditions are not met, an err.bp is reported after processing all but
* the p bit.
*
* The parameter value specifies the exact byte count for a write sequence, but
* on a read (r=1) sequence, it counts only those bytes to be acknowledged. If
* r=1 and a=0, the final byte with standard non-acknowledge is extra.

* Write sequence data byte:
*
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*       |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  | 
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*       |                   data byte                   |
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*
* If a normal I/O byte requests writes from this control buffer, it will be
* immediately followed by the appropriate number of data bytes to be written.

* Special I/O and control byte:
*
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*       |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  | 
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*       |  1  |  1  |  g  |  v  |  d  |  c  |  1  |  q  |
*       +-----+-----+-----+-----+-----+-----+-----+-----+
*
* Once again, the bits are handled from left to right, and these control all
* the exceptional cases we wish to cope with. Note that the SDA and SCL setting
* will occur simultaneously, hence to be valid, only one should differ from its
* currently known state. If v=0, the state will always be both ones before they
* are applied, so the combination of v, d and s all zero is always invalid.
*
* g = 0: set device group addresses as 2 * current parameter value
* g = 1: assume device group is already in its register
* v = 0: kill bus (assume nothing about bus, ensure in standard free state)
* v = 1: assume the bus is valid, whatever state it is in
* d = d: set SDA 
* c = c: set SCL
* q = quit
*
* Note that bit 1 is reserved and must be set, or an err.bp is reported after
* precessing the g and v bits, but before setting the d/c combination
*
* The control buffer must finish up with a special command that has its quit
* (lsb) set. Normally this will be all ones, but where the bus is not being
* released between calls a value of $fb, keeping SDA high and SCL low, will be
* typical.

* The general rules for the bus go as follows:
* Before a START+device, SDA should be high.
* After a START+device, SDA will be high and SCL will be low.
* For a read/write, SDA high and SCL low are required and are left the same.
* Before a STOP, SCL low is expected and both SDA and SCL will be left high.
* Before an initialise, SDA and SCL are irrelevant, after, they are high.
* When using the "special" command, only one of SDA and SCL should be changed
* at one time. When it includes an initialise, both should not be sent low.

* When errors are returned, the rules are modified.
* An err.ff means that the bus did not seem to be responding to the device
* address correctly. This should mean it's an old Minerva board.
* An err.nf just means that the addressed I2C device is not present. A STOP
* sequence will have been sent to leave SDA and SCL high.
* An err.te means a write sequence failed to get its acknowledge on a byte,
* and a STOP will have been issued to leave SDA and SCL high.
* An err.bp means the control buffer had a duff command in it. A normal I/O
* sequence will not have had any STOP sent and a special will have left SDA and
* SCL unchanged unless an initialise was done, when both will be high.

* The call sequence for this code should be in supervisor mode with interrupts
* turned off for maximum speed. If speed is not a constraint, it may not only
* be called with interrpts on, and even in user mode, but, as it preserves a6,
* it may then even be called direct from superbasic.

* The "front end" entry saves more registers, on the assumption that there is
* a valid stack available. Eight bytes further in is the entry point that zaps
* loads more registers, and so on, but requires no stack.

* Registers are expected as follows:

* d0 returns (with ccr) any error code, zero for success.
* d1 if read to register, bytes roll in here, lsb is last. otherwise untouched.
* d2 0 or maybe device and/or maybe (msb's) of first parameter (see below)
* d3 on exit, the control buffer address, updated to wherever we got to.
* d4 destroyed.
* d5 lsb only destroyed.
* d6 lsb only destroyed.
* d7 untouched.
* a0 the return address.
* a1 data buffer address. if used, it will be updated, otherwise untouched.
* a3 on entry, the control buffer address
* a2-a5 these are set here to the four byte addresses of the interface.
* a6 untouched.
* a7 untouched.

* The device and/or part or all of the initial parameter may be passed in d2.
* An initial device should be in bits 22-16, and the initial parameter may be
* in bits 15-0, or partially in bits 8-0 or bits 1-0.
* If the command byte sequence sets the device, bits 31-16 will be copied from
* the current value of the parameter (bits 15-0), then it will be zeroed, as it
* will be after any normal I/O sequence.
* The parameter value (bits 15-0) is rolled left 7 bits as each new parameter
* setting byte (positive) is encountered, to include it.
* On exit, bits 31-16 will be as one might expect, containing whatever was
* there to start with, or the copied parameter value if the device was set.
* Bits 15-0 will be the final value of the parameter, at whatever point the
* sequence was terminated. Typically, after a succesful transfer of data, it
* will be zero.

* The instructions marked with (***) bolow are slightly suspect. They squeeze
* out an extra 2 cycles by needing a compare long, but this may well come
* after the read of the second byte, as it is involved with extending word to
* long for address register comparisons. It's only 1.5 cycles (4%) out so we
* will see if we can get away with it. The alternative is to make it read the
* two bytes in separate instructions which will put us 6.5 cycles over, and
* break up the, so far, pure uniformity of bit access rate.

        section ii_drive

* Front end for somewhat less destructive access. Preserves d3-d6, a0/a2/a4-a5.
drv_end
        move.l  d3,a3
        movem.l (sp)+,d3-d6/a0/a2/a4-a5
        rts

ii_drive
        movem.l d3-d6/a0/a2/a4-a5,-(sp)
        lea     drv_end,a0

* Entry point needing no RAM at all
ii_raw
        move.l  a3,d3
        lea     $bfdc,a4
        lea     1(a4),a5
        lea     2(a4),a2
        lea     3(a4),a3
        cmp.l   #'gold',$4000a  hopefully, a magic test for the gold card
        bne.s   new_cmd         if not a gc, we're operating ok
err_ff
        moveq   #err.ff,d0      say that the I2C is not working
        jmp     (a0)            go home

parm
        lsl.w   #7,d2           shift any existing parameter data up
        or.b    d5,d2           put in next seven bits
new_cmd
        exg     a1,d3
        move.b  (a1)+,d5        get next command byte
        exg     a1,d3
        bpl.s   parm            if msb is clear, rest is 7 bits of parameter
        asl.b   #2,d5           check next two bits, 6=special, 5=normal
        bcs.l   special         11xxxxxx - go do special command sequence
        bpl.s   started         100xxxxx - no START sequence wanted

* 101xxxxx - send START sequence plus device
        tst.b   (a3)         12 SDA high, assure that SCL is high
        rol.b   #3,d5        16 waste time
        ror.b   #3,d5        16 waste time
        tst.b   (a5)         12 SCL high, set SDA low for START
        move.b  d5,d6         8 take a copy of command to get w/r bit
        asl.b   #2,d6        14 put w/r = 0/1 into x
        move.l  d2,d0         8 copy device
        swap    d0            8 get device number bits 7-1
        tst.b   (a4)         12 SDA low, set SCL low
        tas     d0            8 set top bit for clever code
        addx.b  d0,d0         8 roll r/w into register, one to x
        addx.b  d0,d0         8 roll first bit (bit 7) to x as d, one to lsb
devlp
        clr.w   d4            8 clear our data offset register
        roxl.b  #2,d4        14 set 0 for SDA low, 2 for SDA high
        tst.w   0(a4,d4.w)   22 SCL low, set SDA data, then SCL high
        move.b  1(a4,d4.w),d6 22 SDA data, SCL high, verify data
        tst.b   0(a4,d4.w)   22 SDA data, set SCL low
        bchg    d4,d6        12 toggle lsb if we were try to send a zero bit
        asr.b   #1,d6        12 peel out that bit
        bcc.s   err_ff   12 b18 if it's not set now, we have a problem! 
        add.b   d0,d0         8 fetch out next data bit
        bne.s   devlp    12 b18 if this isn't our marker one going out, loop
        tst.w   (a2)         20 SCL low, set SDA high, then SCL high
        moveq   #1,d0         8 mask for lsb
        and.b   (a3),d0      12 sample SDAin
        beq.s   devok    12 b18 if we have an acknowledge, all is ok
        moveq   #err.nf,d0      say we didn't find the device
stopit
        tst.b   (a2)         12 SDA high, set SCL low
        tst.b   (a4)         12 SCL low, set SDA low
        rol.b   #8,d0        26 waste some time
        tst.b   (a5)         12 SDA low, set SCL high
        rol.b   #8,d0        26 waste some time
        nop                   8 waste even more time (3 cycles to many)
        tst.b   (a3)         12 SCL high, set SDA high: STOP
        tst.l   d0              make sure ccr is set
        jmp     (a0)            go home

devok
        tst.b   (a2)         12 SDA is high, set SCL low
started
        asl.b   #2,d5        14 roll out r/w and buffer to msb
        bcs.l   reader   12 b18 go do read sequence
        bmi.s   writer   12 b18 if write from control buffer, we're ready
        exg     a1,d3         8 use data buffer instead of command buffer
        bra.s   writer      b18 go start writing

noack
        moveq   #err.te,d0      transmission error
        add.b   d5,d5           did we swap control/data buffers
        bcs.s   stopit          no, go set the ack error
        exg     a1,d3           put back control and data pointers
        bra.s   stopit          go send a STOP

wbllp
        nop                   8 waste cycles to get timing right
        tst.b   (a4)         12 SDA is low, put SCL low
        add.b   d6,d6         8 check next bit
        bpl.s   wblow    12 b18 if writing zero, we're ready
        cmp.w   (a2),a2      18 SCL is low, set SDA high, set SCL high (***)
        dbra    d4,wbhlp 26 b18 if more bits, go see about them
        tst.b   (a2)         12 SDA is high, put SCL low
        nop                   8 waste cycles to get timing right
        bra.s   chkack      b18 go check acknowledge

wbhigh
        tst.b   (a3)         12 SDA is high, set SCL high
        dbra    d4,wbhlp 26 b18 if more bits, go see about them
        tst.b   (a2)         12 SDA is high, put SCL low
        nop                   8 waste cycles to get timing right
        bra.s   chkack      b18 go check acknowledge

wbhlp
        nop                   8 waste cycles to get timing right
        tst.b   (a2)         12 SDA is high, put SCL low
        add.b   d6,d6         8 check next bit
        bmi.s   wbhigh   12 b18 if writing one, we're ready
        cmp.w   (a4),a4      18 SCL is low, set SDA low, set SCL high (***)
        tst.b   (a5)         12 SDA is low, set SCL high
        dbra    d4,wbllp 26 b18 if more bits, go see about them
        tst.b   (a4)         12 SDA is low, set SCL low
        tst.b   (a2)         12 SCL is low, set SDA high
        asl.l   #1,d0        14 waste cycles to get timing right
chkack
        move.b  (a3),d0      12 set SCL high and sample at the same time
        asr.l   #1,d0        14 check if the ack was there (squeeze 2 cycles)
        bcs.s   noack    12 b18 argh! go zap this transfer
        tst.b   (a2)         12 so, all is ok, drop SCL
writer
        dbra    d2,wbyte 26 b18 see if we've got any more to do
        bra.s   wrdone

wbyte
        moveq   #8-1,d4       8 set for another 8 bits
        move.b  (a1)+,d6     12 get the next byte
        bmi.s   wbhigh      b18 if it has msb set, we're ready
        tst.b   (a4)         12 SCL is low, set SDA low
wblow
        tst.b   (a5)         12 SDA is low, set SCL high
        dbra    d4,wbllp 26 b18 if more bits, go see about them
        tst.b   (a4)         12 SDA is low, set SCL low
        tst.b   (a2)         12 SCL is low, set SDA high
        asl.l   #1,d0        14 waste cycles to get timing right
        move.b  (a3),d0      12 set SCL high and sample at the same time
        asr.l   #1,d0        14 check if the ack was there (squeeze 2 cycles)
        bcs.s   noack    12 b18 argh! go zap this transfer
        tst.b   (a2)         12 so, all is ok, drop SCL
        dbra    d2,wbyte 26 b18 see if we've got any more to do
wrdone
        add.b   d5,d5           did we swap control/data buffers
        bcs.s   chkstop         no, skip swap
        exg     a1,d3           put back control and data pointers
chkstop
        add.b   d5,d5         8 do we want to send a STOP
        bne.s   err_bp   12 b18 object to spare bit(s) set
        bcc.s   clrparm  12 b18 nope, leave SDA high and get next command
        tst.b   (a4)         12 send SDA low
        rol.b   #8,d0        26 waste some time
        tst.b   (a5)         12 send SCL high
        moveq   #7,d0         8
        lsr.b   d0,d0        24 waste some time (about 1 cycle too much)
        tst.b   (a3)         12 send SDA high for STOP
clrparm
        clr.w   d2              reset parameter
        bra.l   new_cmd         go get next command

* Read sequence

rdlp
        move.b  (a3),d6      12 SDA high, set SCL high and sample SDAin
        asl.b   #1,d6        12 juggle to get timing right
        asr.b   #2,d6        14 get SDAin to x
        tst.b   (a2)         12 SDA high, set SCL low
        addx.b  d0,d0         8 roll SDAin into register
        bcc.s   rdlp     12 b18 if not at marker yet, loop
        cmp.w   (a4),a4      18 SCL low, set SDA low, set SCL high (***)
        tst.b   d5            8 check if we are reading to register
        bpl.s   rreg     12 b18 if so, we can afford to be slower, max 4 byte!
        move.b  d0,(a1)+    >12 store this byte (6+ cycles slow)
rrent
        tst.b   (a4)         12 SDA low, set SCL low
        tst.b   (a2)         12 SCL low, set SDA high
reader
        moveq   #1,d0         8 set marker bit
        dbra    d2,rdlp  26 b18
        bclr    #5,d5        22 check acknowledge bit
        bne.s   acklast  12 b18 final byte acknowledged, STOP not permitted
rnlp
        move.b  (a3),d6      12 SDA high, set SCL high and sample SDAin
        asl.b   #1,d6        12 juggle to get timing right
        asr.b   #2,d6        14 get SDAin to x
        tst.b   (a2)         12 SDA high, set SCL low
        addx.b  d0,d0         8 roll SDAin into register
        bcc.s   rnlp     12 b18 if not at marker yet, loop
        nop                   8 lose 2 too many cycles
        tst.b   (a3)         12 SDA high, set SCL high for no ack
        add.b   d5,d5         8 check if we are reading to register
        bcc.s   rnreg    12 b18 if so, go roll it in
        move.b  d0,(a1)+    >12 store this byte
rnrent
        tst.b   (a2)         12 SDA high, set SCL low
        bra.s   chkstop     b18 go check for STOP required

acklast
        add.b   d5,d5           clear off the buffer bit when last byte ack'ed
        beq.s   clrparm         should be all zero now
err_bp
        moveq   #err.bp,d0
        jmp     (a0)

rreg
        rol.l   #8,d1
        move.b  d0,d1
        bra.s   rrent

rnreg
        rol.l   #8,d1
        move.b  d0,d1
        bra.s   rnrent

*       |  1  |  1  |  g  |  v  |  d  |  c  |  1  |  q  |
special
        bmi.s   grpok           skip if g (group) bit is already set
        swap    d2              set device group data
        clr.w   d2              zero the parameter value
grpok
        moveq   #11,d0          clear msb's and shift count
        asl.b   #2,d5           check v bit
        bcs.s   verok           skip if v (validate) bit is set
        st      d6              we have all ones, and x=0
verlp
        tst.b   (a2)         12 SDA high after 1st, set SCL low
        ror.b   #8,d6        26
        tst.b   (a3)         12 SDA high, set SCL high = nak
        rol.b   d0,d6        32
        tst.b   (a5)         12 SCL high, set SDA low = START
        ror.b   d0,d6        32
        tst.b   (a3)         12 SCL high, set SDA high = STOP
        roxl.b  #2,d6        14
        bcs.s   verlp    12 b18 wait for x back at start (exec code 9 times)
verok
        move.b  d5,d0
        lsr.b   #6,d0           put d/c bits into register
        bcc.s   err_bp          object to spare bit zero
        tst.b   0(a4,d0.w)      set SDA/SCL as requested
        lsl.b   #4,d5
        bcc.l   new_cmd
        moveq   #0,d0
        jmp     (a0)            return ok

        vect4000 ii_drive,ii_raw

        end
