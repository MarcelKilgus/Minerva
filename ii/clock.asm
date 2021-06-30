* Copy clock to internal from I2C, if it's there
        xdef    ii_clock

        xref    bf_datez

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'
        include 'dev7_m_inc_vect'

* I2C RAM layout:
* 0-7 clock
* 8-15 alarm (not used)
* 16-19 QDOS version number (must match for 28+ to be used)
* 20-23 auto boot d1 value (lsw reset to 8 when it is used)
* 24-25 year*2+month/10
* 26-27 replacement for auto boot lsw
* 28-29 selective ROM disable (msb disables first ROM, and so on)
* 30 network number (sv_netnr)
* 31 turn off enhancements in QDOS (sx_toe)
* 32 turn off enhancements in basic job 0 (bv_toe)
* 33-34 spare
* 35 keyboard stuff count (1-128)
* 36-163 up to 128 char type in at boot
* 164-255 spare

* Offsets on sp which are used:
        offset  0
        ds.l    1       return address
        ds.w    1       nl, nl,
sp_flag ds.b    1       space, changed to cursor left if I2C is present
        ds.b    1       space
sp_id   ds.l    1       expected to have the QDOS version
        ds.l    1       higher return address
        ds.l    2       two copies of RAM top
sp_rom  ds.w    1       .w where the ROM disable word is sent
        ds.w    1       restart flags

        section ii_clock

* d0 -  o- 0
* d1 -  o- seconds since dot
* a0 -i  - system variables base
* a6 -ip - basic variables base
* d2-d4/d6/a1-a4 destroyed

ii_clock
        move.l  sv_free(a0),a1  set buffer pointer
        move.l  a1,a4           duplicate start of transfer
        lea     cmd,a3          point to command sequence and masks
        bsr.s   ii_drive        try to get the I2C clock stuff
        move.l  a1,a2           top of clock data
        beq.s   more            if it works, great (1st byte is junk)
        moveq   #mt.rclck,d0    fall back to internal clock read
        trap    #1
        rts

ii_drive
        move.w  ii.drive,a2
        jmp     $4000(a2)

more
        and.b   -(a2),d0        use mask byte to junk msd flags bits
        moveq   #15,d1          mask for lsd and msbs all zero
        and.b   (a2),d1         get lsd
        lsr.b   #1,d0
        add.b   d0,d1           lsd + msd/2
        lsr.b   #2,d0
        add.b   d0,d1           lsd + msd*16/2 + msd*16/8 = lsd + 10*msd
        move.l  d1,(a1)+        push onto stack
        move.b  (a3)+,d0        get next mask byte
        bne.s   more            if not ending zero, keep on going

* This bit copes with 12/24 hour + am/pm
        move.l  (a2)+,d3        ss:mm:hh dd, just want 2 lsbs of hh
        add.w   d3,d3           check them
        bcc.s   notpm           skip if 24hr
        bpl.s   notpm           skip if 12hr and am
        add.b   #12,-9(a1)      add 12 to hours for 12hr and pm
notpm

* This bit clicks the year by using a copy of the tens of month at the year lsb
        movem.l (a4)+,d3-d4/d6  take up id, junk and year+flag+rebooter
        swap    d6              swap to rebooter and year+flag
        move.b  (a2),d1         get bcd month again
        lsr.b   #4,d1           move ten months to lsb
        eor.b   d6,d1           flip with ten month flag after lsb of year
        asr.b   #1,d1           move to x reg
        addx.w  d0,d6           if they differed, increment year+flag

        move.l  d6,(a1)         put them in the buffer
        move.l  a1,d4           save stack top for later
        lsr.w   #1,d6           lose the 10 month flag now
        bsr.s   ii_drive        slot back in the lsw of boot and the year+flag

        cmp.l   sp_id(sp),d3    check QDOS id
        bne.s   clock           no match, so don't trust the ram layout
        moveq   #$c0-256,d3     left arrow key
        move.b  d3,sp_flag(sp)  show them I2C is around
        move.l  sv_keyq(a0),a2  get #0's key queue
        move.w  io.qtest,a3
        jsr     (a3)            see what character is present
        cmp.b   d1,d3
        beq.s   clock           if left arrow, they are avoiding I2C
        move.w  (a4)+,sp_rom(sp) set ROM inhibit word
        move.b  (a4)+,sv_netnr(a0) set network address
        move.l  sv_chtop(a0),a0 get system extension address
        move.b  (a4)+,sx_toe(a0) set turn off enhancements flag
        move.b  (a4),bv_toe(a6) set basic tokenisation flag
* Two spare bytes
        move.l  (a4)+,d3        get stuffer length
        move.w  io.qin,a1
        bra.s   stent

stuff
        move.b  (a4)+,d1
        jsr     (a1)            put byte into keyboard queue
stent
        subq.b  #1,d3
        bpl.s   stuff           allow max 128 stuffer chars

clock
        move.w  d6,d1           we kept the year and msw d1 is zero
        move.l  d4,a1           reload clock data stack pointer
        sub.l   a6,a1           set rel a6 pointer to 5 longs
        jsr     bf_datez(pc)    go convert year and the rest to seconds-dot
        moveq   #mt.sclck,d0    now set the internal clock with it all
        trap    #1              read or set clock
        rts

* Command sequences: i/o 10srbpa0, special 11gvdc1q
cmd
        dc.b    0,$a0/2,%11011110       set device
        dc.b    1,%10100000,16          start, write address of id word
        dc.b    1,128-16+8-1,%10111100  start, read most of ram, stop
        dc.b    $ff                     finish
        dc.b    $10,$30,$30,$70,$70,0   masks for mm/dd hh:mm:ss & stop
        dc.b    1,%10100000,22          start, write address of lsw of boot
        dc.b    4,%10001100             write boot/year+flag from buffer, stop
        dc.b    $ff                     finish

        end
