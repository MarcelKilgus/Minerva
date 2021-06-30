* Microdrive io operations
        xdef    dd_mdvio,dd_mdvpd,dd_mdvrr

        xref    dd_mdvbu,dd_mdvlu,dd_mdvrn,dd_mdvsc,dd_mdvtr
        xref    md_slave

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bt'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_md'
        include 'dev7_m_inc_sv'

vacant  equ     $fd
maxsec  equ     255

        section dd_mdvio

* d0 -i o- operation / error return
* d1 -i o- i/o byte
* a0 -ip - channel definition
* a1 -i o- read/write buffer
* a2 -  o- physical definition
* d3/a3 destroyed

* A routine version of mdvio for mdvop and mdvcl

dd_mdvrr
        movem.l d0/d2/d4-d7/a4-a5,-(sp)
mdvrr
        movem.l (sp),d0/d2      restore call parameters
        moveq   #0,d3           treat all calls as initial entry
        bsr.s   dd_mdvio
        addq.l  #-err.nc,d0     if err.nc do again
        beq.s   mdvrr
        subq.l  #-err.nc,d0
        addq.l  #4,sp           discard saved op
        movem.l (sp)+,d2/d4-d7/a4-a5
        rts

fetch
        moveq   #0,d3           assume pending
        addq.b  #io.edlin,d0
        beq.s   byte
        move.w  #1<<8,d3        assume read (normal)
        subq.b  #io.fline,d0
        bne.s   byte_str
        moveq   #10,d3          read to newline

str
        add.l   a1,d7           find original start of buffer
        move.l  d7,-(sp)        and save it
        add.l   d2,d7           find original end of buffer
        jsr     dd_mdvbu(pc)
        move.l  a1,d1           end address of part done
        sub.l   (sp)+,d1        total bytes so far transfered
        rts

err_ro
        moveq   #err.ro,d0      write on read only device
        rts

go_ser
        moveq   #0,d7           initialise end pointer
        tst.l   d3              is it reentry?
        beq.s   ser_op
        sub.l   d1,d7           yes - some bytes have already been moved
ser_op
        addq.b  #io.sstrg-io.edlin,d0 check operation
        beq.s   err_bp
        bmi.s   fetch
        cmp.b   #io.share,fs_acces(a0) is write permitted?
        beq.s   err_ro

        moveq   #-1,d3          a write operation
        subq.b  #io.sbyte+1-io.edlin,d0 which type of write?
        beq.s   err_bp
byte_str
        bcc.s   str
byte
        move.l  sp,d7           pointer to end of buffer on stack
        move.l  d1,-(sp)        put whole of d1 onto stack
        lea     3(sp),a1        and point to the lsb
        jsr     dd_mdvbu(pc)
        move.l  (sp)+,d1        replace only lsb of d1 with result
        rts

* d6 -  o- drive id * 16 + 1<<bt.file, ready for slave block stuff
* a0 -ip - channel definition
* a2 -  o- physical definition

dd_mdvpd
        moveq   #0,d6           get drive id
        move.b  fs_drive(a0),d6
        lsl.b   #2,d6           make an address
        lea     sv_fsdef(a6),a2 get pointer to physical definition
        move.l  0(a2,d6.w),a2
        lsl.b   #4-2,d6         into bits 7-4 ready for slave blocks
        addq.l  #1<<bt..file,d6 and set file bit
        rts

* Driver entry point for input/output
 
* d0 -i o- operation / error return
* d1 -i o- bytes transferred so far or i/o byte
* d2 -i  - buffer maximum length
* a0 -ip - channel definition
* a1 -i o- read/write buffer
* a2 -  o- physical definition
* d4-d7/a3-a5 destroyed

dd_mdvio

        bsr.s   dd_mdvpd        get id and address of physical definition

* Sort out operation

        cmp.b   #fs.check,d0    check if it is a file operation
        bcc.s   fileio

        ext.l   d1              normal io calls use word counters only
        ext.l   d2
serio
        subq.b  #io.sstrg,d0    is operation in range?
        bls.s   go_ser          yes - putter on up above
err_bp
        moveq   #err.bp,d0
        rts

fileio
        cmp.b   #fs.check+fop_top-fop_tab-1,d0 is it out of range?
        bhi.s   err_bp

        move.b  fop_tab-fs.check(pc,d0.w),d0 branch to file operation
        add.w   d0,d0
        jmp     fop_jmp(pc,d0.w)
fop_jmp

load
* N.B. This is a bit wierd, to say the least!
* If the length requested is less than 4096, the current file position is used,
* d2 bytes are read from there and the buffer address can be odd.
* However, if the length is greater than or equal to 4096, the scatter load
* totally ignores the current file postion and d2 then reads the whole file.
* The latter even used to crash if the buffer address was odd.
        moveq   #io.fstrg,d0    load is fetch string
        cmp.l   #4096,d2        is file not very huge?
        blt.s   serio           ... yes - serial load
        move.w  a1,d4
        asr.b   #1,d4
        bcs.s   serio           serial if address is odd (lwr)
        bsr.s   flush           ensure all blocks are on medium
        bne.s   rts0
        jmp     dd_mdvsc(pc)    load is scatter

save
        moveq   #io.sstrg,d0    save is send string
        bra.s   serio

* Read and set header calls are assumed to complete in one operation
* as the header is all in one block

heads
        moveq   #io.sstrg,d0 to set header - send string
        moveq   #md_denam,d2    of 14 bytes (up to, not including, name length)
head
        assert  fs_nblok,fs_nbyte-2
        clr.l   fs_nblok(a0)    read from / write to 0
        bsr.s   serio           serially
        moveq   #fs.hdlen,d4
        move.w  d4,fs_nbyte(a0) reset pointer to start of file
rts0
        rts

headr
        moveq   #io.fstrg,d0    to read header - read string (no length limit!)
        move.l  a1,-(sp)        save header pointer
        bsr.s   head
        move.l  (sp)+,a2
        sub.l   d4,(a2)         (N.B. caller buffer must be even addr!!!)
        rts

test_bof
        sub.l   d2,d1           take away header length
        bge.s   set_nblk
set_bof
        moveq   #0,d1           show caller new position
        move.l  d2,d0           reset to beginning of file
set_nblk
        move.l  d0,fs_nblok(a0)
set_iop
        moveq   #io.pend,d0
        bra.s   serio

posab
        moveq   #fs.hdlen,d2    get length of header
        add.l   d2,d1           set actual file pointer
test_ovf
        bvc.s   test_eof        ok if it didn't overflow
        roxr.l  #1,d1           otherwise this'll set an extreme value
test_eof
        move.l  d1,d0           preserve address
        bmi.s   set_bof         negative then force to bottom
        asl.l   #6,d0           and put new byte address in appropriate form
        bvs.s   set_eof         if huge, set eof
        add.l   d0,d0
        lsr.w   #7,d0
        cmp.l   fs_eblok(a0),d0 is it beyond end of file?
        bls.s   test_bof
set_eof
        assert  fs_eblok,fs_ebyte-2
        move.l  fs_eblok(a0),d0 yes - set pointer to end of file
        moveq   #0,d1
        bra.s   con_byte

posre
        tst.l   d3              do not move pointer if it is re-entry
        bne.s   set_iop

        moveq   #fs.hdlen,d2    get length of header
        assert  fs_nblok,fs_nbyte-2
        move.l  fs_nblok(a0),d0 get current pointer
con_byte
        lsl.w   #7,d0           ... in byte address form
        lsr.l   #7,d0
        add.l   d0,d1           add it to adjustment
        bra.s   test_ovf

fop_tab
        dc.b    (check-fop_jmp)/2
        dc.b    (flush-fop_jmp)/2
        dc.b    (posab-fop_jmp)/2
        dc.b    (posre-fop_jmp)/2
        dc.b    (err_bp-fop_jmp)/2
        dc.b    (mdinf-fop_jmp)/2
        dc.b    (heads-fop_jmp)/2
        dc.b    (headr-fop_jmp)/2
        dc.b    (load-fop_jmp)/2
        dc.b    (save-fop_jmp)/2
        dc.b    (renam-fop_jmp)/2
        dc.b    (trunc-fop_jmp)/2
fop_top
        ds.w    0

check
        moveq   #bt.true,d4     check all blocks are true copies
        moveq   #-1,d5          nc if not true
        bra.s   cf_com

flush
        moveq   #bt.actn,d4     check if any action pending
        moveq   #0,d5           nc if true
cf_com
        jsr     dd_mdvlu(pc)    make sure length and update are set
        bne.s   rts1            ouch - it didn't work

        move.w  fs_filnr(a0),d2 get file number
        move.l  sv_bttop(a6),a4 scan through slave blocks
cf_loop
        cmp.l   sv_btbas(a6),a4 done bottom yet?
        beq.s   rts1
        subq.l  #bt_end,a4      next block
        moveq   #-16+1<<bt..file,d3 check drive number, file block bit
        assert  0,bt_stat
        and.b   (a4),d3
        cmp.b   d6,d3
        bne.s   cf_loop         not the right drive
        cmp.w   bt_filnr(a4),d2
        bne.s   cf_loop         not the right file
        move.b  (a4),d0         check the status bits (the right way round)
        eor.b   d5,d0
        and.b   d4,d0
        beq.s   cf_loop
        jmp     md_slave(pc)    sets d0=err.nc for us

renam
        jmp     dd_mdvrn(pc)

trunc
        jmp     dd_mdvtr(pc)

mdinf
        lea     md_mname(a2),a3 copy name (nb user buffer may now be odd! lwr)
        moveq   #10,d1
copyinf
        move.b  (a3)+,(a1)+
        subq.b  #1,d1
        bne.s   copyinf
        move.w  #maxsec*2-2,d0  search for good (and vacant sectors)
        moveq   #1,d2           include sector 0 in good count
inf_loop
        cmp.b   #vacant,md_map(a2,d0.w) is it vacant?
        bhi.s   inf_next        bad
        bne.s   inf_good        in use
        addq.w  #1,d1           vacant
inf_good
        addq.w  #1,d2           good
inf_next
        subq.w  #2,d0           take next sector
        bne.s   inf_loop        (N.B. d0.l = 0 at end)
        swap    d1              put both the return args in d1
        move.w  d2,d1
rts1
        rts

        end
