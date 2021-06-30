* Open a file on a microdrive (delete and truncate are here too)
        xdef    dd_mdvop,dd_mdvtr

        xref    md_slavn
        xref    ut_cstr
        xref    dd_mdvlu,dd_mdvrr

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bt'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_md'
        include 'dev7_m_inc_sv'

maxsec  equ     255
vacant  equ     $fd

blkbits equ     9
blklen  equ     1<<blkbits
entbits equ     6
        assert  1<<entbits,fs.hdlen

        section dd_mdvop

* d0 -  o- error code
* a0 -ip - base of channel definition block
* a1 -i  - base of physical definition block
* a2 -  o- base of physical definition block
* a3 -i  - base of driver definition block (not used)
* d1-d7/a4 destroyed

dd_mdvop
        move.l  a1,a2           slave uses a2

* First we set the drive id for this drive

        moveq   #0,d1           get drive number
        move.b  md_drivn(a2),d1
        moveq   #0,d6
        move.b  fs_drive(a0),d6 ... and drive id*4
        lsl.b   #2,d6
        lea     sv_mdrun(a6),a4 ... and put into table of ids
        move.b  d6,sv_mddid-sv_mdrun-1(a4,d1.w)
        lsl.b   #4-2,d6
        addq.b  #1<<bt..file,d6 ready for delete file blocks

* Now check for drive running or any pending operations

        cmp.b   (a4),d1         is this one running?
        beq.s   read_dir
        tst.b   sv_mdsta-sv_mdrun-1(a4,d1.w) is it waiting?
        bne.s   read_dir

* Now we get map if medium changed or first medium in drive

        move.b  #1,md_estat(a2) set error flag!!
        jsr     md_slavn(pc)
wait
        tst.b   md_estat(a2)    check status
        bgt.s   wait            not yet acted upon
        blt.s   err_nf          oops

read_dir
        lea     fs_spare(a0),a4 use spare bit of channel
        moveq   #fs.hdlen,d2    keep entry length in d2 (almost) permanently
        move.l  d2,fs_eblok(a0) minimum size directory can be
        bsr.s   read_ent        read an entry
        bne.s   rts0
        bsr.s   setsize         set up proper next/end positions, d4=end
        moveq   #0,d5           first vacant slot
        cmp.b   #io.dir,fs_acces(a0) was this open directory?
        bne.s   nxt_file
        clr.w   fs_fname(a0)    make name null for directory
        rts

empty
        tst.l   d5              is this the first vacant slot
        bne.s   nxt_file        no - leave it alone
        move.l  d7,d5           yes - save vacant slot
nxt_file
        move.l  fs_nblok(a0),d7 pick up current location
        cmp.l   d4,d7           are we at the end?
        beq.s   file_new        yes - must be a new file
        bsr.s   read_ent        read next directory entry
        bne.s   rts0
        assert  0,md_delen
        tst.l   (a4)            vacant?
        beq.s   empty
        move.l  a6,-(sp)
        lea     fs_fname,a6    base address for ut_cstr versus a0
        lea     md_denam-fs_fname(a4),a1 a1 relative to a6
        moveq   #1,d0
        jsr     ut_cstr(pc)     compare
        move.l  (sp)+,a6
        bne.s   nxt_file        are the names equal?

* File found... put back pointer, so we can update if needed

        bsr.s   setentry        reposition file and calculate file no, d0.l=0
        assert  0,io.old,io.share-1,io.new-2,io.overw-3
        move.b  fs_acces(a0),d0 get access mode
        subq.b  #io.new,d0
        beq.s   err_ex
        bpl.s   overw           n.b. d0.w = 1, for truncation in overwrite
        bcc.s   delete          delete was $ff-2 as opposed to old/share

* File found, all OK

        move.w  d5,fs_filnr(a0) set file number

setsize
        move.l  (a4),d4         get length
        lsl.l   #16-blkbits,d4  convert to block/byte format
        lsr.w   #16-blkbits,d4
        assert  fs_nblok,fs_nbyte-2
        move.l  d2,fs_nblok(a0) current file pointer
        assert  fs_eblok,fs_ebyte-2
        move.l  d4,fs_eblok(a0) set length
ok_rts
        moveq   #0,d0           no errors
rts0
        rts

err_nf
        moveq   #err.nf,d0
        rts

* Reposition directory and calculate file number

setentry
        move.l  d7,d5           make it the current entry
        move.l  d7,fs_nblok(a0) backspace the directory pointer
        lsl.w   #16-blkbits,d5  move byte up by block
        lsr.l   #16-blkbits,d5  move then both back down
        lsr.l   #entbits,d5     divide by entry size, to give file number
        bra.s   ok_rts          make sure d0 is zero

* Read a directory entry

read_ent
        moveq   #io.fstrg,d0    read string
rdwr_ent
        move.l  a4,a1
        jmp     dd_mdvrr(pc)

err_ex
        moveq   #err.ex,d0
        rts

* Delete an existing file

delete
        clr.w   md_denam(a4)    name is null
        clr.l   (a4)            clear length
        bsr.s   wr_ent
        bne.s   rts0

* Overwrite an existing file (and truncate for delete)

overw
        ; d0.w = 0 for truncation to nothing for a delete
        ; d0.w = 1 to leave header alone, for now, when overwriting
        bsr.s   dotrunc         perform the truncation
        moveq   #fs.hdlen,d7    overwrite is starting with 1st block retained
        bra.s   initit          go fill it in, if it's ovewrite

* File not found (or delete/overwrite has been done)

file_new
        move.l  d5,d7           have we got a spare entry?
        bne.s   entryset        yes - use it
        move.l  d4,d7           no - put it at eof
entryset
        bsr.s   setentry        reposition file and calculate file number
        moveq   #0,d7           starting without any blocks in file
initit
        cmp.b   #io.new,fs_acces(a0) check access mode
        bcs.s   err_nf          old/share is no good
        blt.s   ok_rts          delete is finished (or wasn't even found)

* Set up file header and directory entry

        lea     0(a4,d2.w),a1
clearit
        clr.l   -(a1)           clear out whole entry
        cmp.l   a1,a4
        bne.s   clearit
        move.l  d2,(a4)         set length of file
        lea     md_denam(a4),a1
        lea     fs_fname(a0),a3
        move.w  (a3),d0
        addq.w  #2-1,d0         move name and length thereof
move_nam
        move.b  (a3)+,(a1)+
        dbra    d0,move_nam
        bsr.s   wr_ent          write directory entry
        bne.s   rts0

* Update length of directory, maybe

        move.l  fs_eblok(a0),d0 get end of directory
        cmp.l   d4,d0           has this extended the directory
        beq.s   dlen_ok         no - that's ok
        lsl.w   #16-blkbits,d0
        lsr.l   #16-blkbits,d0  calculate new length
        move.l  d0,(a4)
        moveq   #4,d2
        bsr.s   wr_nb0          write 4 byte length to start of the directory
        bne.s   rts0
        moveq   #fs.hdlen,d2    put back normal entry length
        move.l  d2,(a4)         set file length to header length again
dlen_ok
        move.w  d5,fs_filnr(a0) finally get to writing the file itself
        move.l  d7,fs_eblok(a0) overwrite held a block, rest didn't have any
wr_nb0
        clr.l   fs_nblok(a0)    start at beginning of file
wr_ent
        moveq   #io.sstrg,d0    send string
        bra.s   rdwr_ent

* d0 -ip - .w lowest block number to be discarded (i.e. 0 = whole file)
* d5 -ip - file number to truncate
* d6 -ip - drive id * 16 + 1<<bt..file
* d3/a3 destroyed

dotrunc
        moveq   #256-maxsec,d3  scan through all sectors in map
        lea     md_map+2*maxsec(a2),a3
del_loop
        cmp.b   (a3),d5         is this the file to be truncated?
        bne.s   del_next
        cmp.b   1(a3),d0        is it a block to be discarded?
        bhi.s   del_next        no - leave it
        move.w  #vacant<<8,(a3) set vacant
        clr.w   md_pendg-md_map(a3) clear any pending operations
del_next
        subq.l  #2,a3
        addq.b  #1,d3           next sector
        bne.s   del_loop

* Now get rid of any slave blocks for this

        move.l  sv_btbas(a6),a3 get address of base of tables
rem_loop
        cmp.w   bt_filnr(a3),d5 the file number must match (1st, as it's quick)
        bne.s   rem_next
        moveq   #-16+1<<bt..file,d3 mask out all but drive id and file flag
        assert  0,bt_stat
        and.b   (a3),d3
        cmp.b   d3,d6           the drive, of course, must match
        bne.s   rem_next
        cmp.w   bt_block(a3),d0 finally, the block must be one being discarded
        bhi.s   rem_next
        move.b  #bt.empty,(a3)  kill it
rem_next
        addq.l  #bt_end,a3      next slave block
        cmp.l   sv_bttop(a6),a3 last ?
        bne.s   rem_loop

        move.w  #-1,md_pendg(a2) set write map key
        rts

* d0 -  o- error code
* d6 -i  - drive id * 16 + 1<<bt..file
* a0 -ip - channel definition
* a2 -ip - physical definition
* d1-d3/a1/a3-a4 destroyed

dd_mdvtr
        cmp.b   #io.share,fs_acces(a0) is the file opened for writing?
        beq.s   err_ro
        move.w  fs_filnr(a0),d5 pick up file number
        move.l  fs_nblok(a0),d0 + nbyte get current position
        move.l  d0,fs_eblok(a0) + ebyte stuff it into the end position
        subq.l  #1,d0           if byte number is zero, decrement block number
        swap    d0
        addq.w  #2,d0           discard all blocks >= d0.w
        st      fs_updt(a0)     show file updated
        bsr.s   dotrunc         get rid of map entries and slave blocks
        jmp     dd_mdvlu(pc)    will set d0=0 for us

err_ro
        moveq   #err.ro,d0
        rts

        end
