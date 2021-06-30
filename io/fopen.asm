* General file system open and delete
        xdef    io_fopen,io_relch

        xref    mm_alchp,mm_rechp
        xref    ut_unlnk,ut_cstr
        xref    io_fdriv

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_assert'

        section io_fopen

* General file system open routine. Access key in d3 is 0..4.
* Routine used by io.open trap (2) after non file devices have been checked.
* Also used for io.delet trap with special value ($ff) in d3.

* d0 -  o- error flag
* d3 -ip - access key, or $ff for delete
* a0 -i o- pointer to name / pointer to definition block
* a2 -  o- address of driver

reglist reg     d1-d6/a3-a6

io_fopen
        movem.l reglist,-(sp)

* First find the driver
* (This moved to start by lwr - why allocate the channel when you haven't even
* got a driver, or a physical definition block, yet! Saves chp fragments too!)

        move.l  a0,a5           save the name pointer for later on

        jsr     io_fdriv(pc)    get all lookup's over with
        bmi.s   exit            that device was not found
        beq.s   physok          zero means we already have physical defn ready

        move.l  d5,d0           fdriv left the free slot in d5... or err.no
        bmi.s   exit

        lsl.l   #2,d0
        add.l   d0,a4           ready to record new physdef
        move.b  d5,d4           note: new slot number moved to d4

        move.b  d1,d5
        move.l  ch_dflen(a2),d1 get length of physical definition block
        jsr     mm_alchp(pc)    allocate space, now preserves registers
        bne.s   exit
        move.l  a0,a1           set physdef address
        move.l  a2,fs_drivr(a1) set driver
        move.b  d5,fs_drivn(a1) ... and drive number
        move.l  a1,(a4)         put address in physdef list

physok

* Allocate file channel definition block

        moveq   #fs_end>>1,d1
        add.b   d1,d1
        jsr     mm_alchp(pc)
        bne.s   exit

* From now on, all pointers point to fs_next within the block

        add.w   #fs_next,a0

* Link this definition block into list

        lea     sv_fslst(a6),a3 (used to use ut_link, but we'd like to keep a1)
        move.l  (a3),(a0)       put pointer to next in this item
        move.l  a0,(a3)         and link it in

* Put drive id, access key and name into fs

        move.b  d4,fs_drive-fs_next(a0) drive id
        move.b  d3,fs_acces-fs_next(a0) access key

        lea     fs_fname-fs_next(a0),a4
        move.w  (a5)+,d0        get name length
        move.w  ch_drnam(a2),d2 ... and drive name length
        addq.w  #2,d2           ... skipping over n_
        add.w   d2,a5           move pointer on
        sub.w   d2,d0           ... and reduce length of name
        move.w  d0,(a4)+        put name length in block
        cmp.w   #fs.nmlen,d0
        bls.s   end_name        we allow 0..fs.name, anything else is trash

        moveq   #err.bn,d5      negative or too long is a bad name
err_d5
        bsr.s   relch           unlink and release definition block
        move.l  d5,d0           set error key
exit
        movem.l (sp)+,reglist
        rts

io_relch
        add.w   #fs_next,a0     point to link in block
relch
        lea     sv_fslst(a6),a1 unlink definition block from list
        jsr     ut_unlnk(pc)
        sub.w   #fs_next,a0     reset to base of block
        jmp     mm_rechp(pc)    free definition block

mov_name
        move.b  (a5)+,(a4)+     copy the file name part into the channel
end_name
        dbra    d0,mov_name

* Now we check if there is already a file open with the same name

        move.l  a1,a5           save pointer to definition block
        move.l  a0,a1           start at next block in list

next_dup
        move.l  (a1),a1         next block
        move.l  a1,d0
        beq.s   end_dup         end of list

        cmp.b   fs_drive-fs_next(a1),d4 is this same drive
        bne.s   next_dup

        moveq   #1,d0           comparison type 1
        moveq   #fs_fname-fs_next,d5
        exg     d5,a6           offset of name in block
        jsr     ut_cstr(pc)     compare names
        exg     d5,a6           restore system variables base
        bne.s   next_dup        no match - try next

* A matching file name has been found - check for access conflict

        moveq   #err.ex,d5
        moveq   #io.new,d0
        sub.b   fs_acces-fs_next(a0),d0 is open 'new'?
        beq.s   err_d5          ... yes and so error - exists
        moveq   #err.iu,d5
        subq.b  #io.new-io.share,d0 is open 'share'?
        bne.s   err_d5          ... no and so error - in use
        cmp.b   #io.share,fs_acces-fs_next(a1) is other channel 'share'?
err_d5n
        bne.s   err_d5          ... no and so error - in use

* file is already open - so we can copy block to save directory seach

        move.w  fs_filnr-fs_next(a1),fs_filnr-fs_next(a0)
        assert  fs_eblok,fs_ebyte-2
        move.l  fs_eblok-fs_next(a1),fs_eblok-fs_next(a0)
        move.w  #fs.hdlen,fs_nbyte-fs_next(a0) set initial byte pointer

end_dup
        move.l  a5,a1           restore pointer to definition block
        tst.w   fs_filnr-fs_next(a0) has a duplicate file been found
        bne.s   exit_ok         yes - all done

* Device dependent open

        movem.l a0-a2,-(sp)     save pointers
        sub.w   #fs_next,a0     reset a0 so driver will understand it
        lea     -sv_lio(a2),a3  get base of driver definition
        move.l  ch_open(a2),a4  ... and open entry address
        jsr     (a4)            ... go
        movem.l (sp)+,a0-a2     (driver can even scrud a0 now...)

        move.l  d0,d5           was there an error?
        bne.s   err_d5n         yes - free block, report error
        tst.b   fs_acces-fs_next(a0) was this delete?
        blt.s   err_d5n         yes - free block, no error

* In this version we do not release space taken by physical definition

* Update count of files open on drive

exit_ok
        sub.w   #fs_next,a0     restore a0
        addq.b  #1,fs_files(a1) ... one more file is open
        moveq   #0,d0
        bra.l   exit

        end
