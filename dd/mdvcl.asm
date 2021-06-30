* close microdrive channel (also write updated bits in dir/header)
        xdef    dd_mdvcd,dd_mdvcl,dd_mdvlu

        xref    dd_mdvpd,dd_mdvrr
        xref    io_relch
        xref    md_slave

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_md'
        include 'dev7_m_inc_mt'

blkbits equ     9
*blksize equ    1<<blkbits
entbits equ     6
        assert  1<<entbits,fs.hdlen

        section dd_mdvcl

* d0 -  o- 0
* d6 -  o- drive id * 16 + 1<<bt..file
* a0 -i  - channel definition
* a2 -  o- physical definition
* a3 -ip - directory driver linkage block (not used)

dd_mdvcl
        jsr     dd_mdvpd(pc)    sort out physdef stuff
        bsr.s   dd_mdvlu        update length/date
        subq.b  #1,md_files(a2) one fewer files
        jmp     io_relch(pc)    unlink and remove channel definition block

* Update file header with data length and update date and copy it to directory.

* d0 -  o- error code
* a0 -ip - channel definition
* a2 -ip - physical definition

dd_mdvlu
        tst.b   fs_updt(a0)     was file updated?
        bne.s   dd_mdvcd        yes - go update length and update date
        moveq   #0,d0           just to be consistent
        rts

reglist reg     d1-d3/a1/a3-a4
dd_mdvcd
        movem.l reglist,-(sp)
        assert  fs_filnr,fs_nblok-2,fs_nbyte-4,fs_eblok-6,fs_ebyte-8
        lea     fs_filnr(a0),a4
        move.w  (a4)+,-(sp)     save file no
        move.l  (a4)+,-(sp)     save current
        move.l  (a4),-(sp)      save end
        clr.l   -(a4)           set current to zero to address header
        moveq   #io.fstrg,d0
        bsr.s   rd_ent          get current image of file header
        bne.s   getout          couldn't read it!

        tst.b   fs_updt(a0)     was file really updated? (rename skips here)
        beq.s   headok          no - don't actually change header

        move.l  (sp),d0
        lsl.w   #16-blkbits,d0  get file length
        lsr.l   #16-blkbits,d0  in true form
        move.l  d0,md_delen+fs_spare(a0) set file length

        exg     a0,a1
        moveq   #mt.rclck,d0    get a reading from the clock
        trap    #1
        exg     a0,a1
        move.l  d1,md_deupd+fs_spare(a0) set update date

        clr.l   (a4)            reset position to header
        bsr.s   wr_ent          write length and update date to file header
        bne.s   getout          yeuch! we're in trouble
headok

        move.w  -(a4),d0        get file number
        clr.w   (a4)+           directory is file 0
        lsl.l   #entbits,d0     and convert to directory position
        lsl.l   #16-blkbits,d0
        lsr.w   #16-blkbits,d0
        move.l  d0,(a4)         set current to directory
        st      fs_eblok+1(a0)  of great length!!!
        bsr.s   wr_ent          write whole header to directory entry
        bne.s   getout
        jsr     md_slave(pc)
        moveq   #0,d0
getout
        sf      fs_updt(a0)     we can clear the flag, i hope! (lwr)
        lea     fs_eblok(a0),a4
        move.l  (sp)+,(a4)      restore end
        move.l  (sp)+,-(a4)     restore current
        move.w  (sp)+,-(a4)     restore file no
        movem.l (sp)+,reglist
        tst.l   d0
        rts

* Write the length and update date

wr_ent
        moveq   #io.sstrg,d0    send header or directory entry
rd_ent
        lea     fs_spare(a0),a1 use spare in block
        moveq   #fs.hdlen,d2
        jmp     dd_mdvrr(pc)    direct entry

        end
