* Microdrive slave block buffering operations
        xdef    dd_mdvbu,dd_mdvnb

        xref    md_slave

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bt'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_md'
        include 'dev7_m_inc_sv'

vacant  equ     $fd
badsec  equ     $ff
maxsec  equ     255

blkbits equ     9
btbits  equ     3
        assert  1<<btbits,bt_end

        section dd_mdvbu

* d0 -  o- error return
* d3 -ip - action -ve send, 0 check, +ve fetch (10 = fetch line)
* d6 -ip - drive id * 16 + 1<<bt..file
* d7 -i o- end of buffer (reduced by fline when terminator found)
* a0 -ip - pointer to channel definition
* a1 -i  - pointer to read/write buffer
* a2 -ip - pointer to physical definition
* d1-d2/d4-d5/a3-a5 destroyed

* Byte buffer/unbuffer code

dd_mdvbu
        tst.b   md_estat(a2)    is it ok?
        bmi     err_fe
        assert  fs_filnr,fs_nblok-2
        move.l  fs_filnr(a0),d5 fetch file number/block number reqd
        assert  fs_nblok,fs_nbyte-2
        move.l  fs_nblok(a0),d4 fetch block number/byte number
        assert  fs_eblok,fs_ebyte-2
        cmp.l   fs_eblok(a0),d4 compare against end of file
        bcs.s   set_bk          not there yet, so all is ok
        bne.s   err_ef          grim if the pointer is beyond end
        tst.b   d3              is operation a write?
        bpl.s   err_ef          no - can't extend the file with a test/read!
        tst.w   d4              is this new byte in a new block
        bne.s   set_bk          no - just go pick up the block
        cmp.l   a1,d7           is there actually anything to go in block?
        ble     ok_rts          no so exit
        bsr     dd_mdvnb        find space for a new block
        bsr     new_sect        find new sector
        move.w  d0,bt_sectr(a4) set sector number
        addq.b  #1<<bt..accs,(a4) and say it is a true buffer
        bra.s   bk_found

err_ef
        moveq   #err.ef,d0      end of file
rts0
        rts

set_bk
        bsr     bk_find         get the block for this sector
        bne.s   rts0            ... if block not there - give up
        tst.w   d4              is it the first byte in a block?
        bne.s   bk_found        no - do not go through all that prefetch
        addq.w  #1,d5           find the block for the next
        moveq   #0,d2           and set up the block/byte address of next
        move.w  d5,d2
        swap    d2
        move.l  a4,-(sp)        save the block pointer
        cmp.l   fs_eblok(a0),d2 at end of file?
        bcc.s   rst_pref        yes - do not prefetch
        bsr     bk_find1
rst_pref
        move.l  (sp)+,a4        restore the block pointer
        subq.w  #1,d5           restore the block number

bk_found
        move.l  a4,fs_cblok(a0) save pointer to this slave block
        btst    #bt..accs,(a4)  check contents of slave block
        beq     err_ncs         not accessable, so slave to make it proper
        move.l  a4,d0           calculate address of next byte
        sub.l   sv_btbas(a6),d0 table pointer - base address of table
        lsl.l   #blkbits-btbits,d0
        move.l  d0,a5
        add.l   a6,a5           plus base of memory
        add.w   d4,a5           plus byte pointer

        tst.w   d3              what operation are we doing
        beq.s   ok_rts          just a check, so we're done
        bmi.s   put_byts        negative is a send

        moveq   #0,d0           clear top byte of d0.w for fetch terminator
get_loop
        cmp.l   a1,d7           end of string?
        ble.s   com_exit        yes - go finish off
        cmp.l   fs_eblok(a0),d4 are we now at end of file?
        beq.s   exit_eof
        move.b  (a5)+,d0        get a byte from the buffer
        move.b  d0,(a1)+        and save it
        cmp.w   d0,d3           is it the terminating character?
        beq.s   termin          yes - go sort it
        bsr.s   move_ptr        update the pointers
        bne.s   get_loop        if buffer not emptied - carry on
        bra.s   com_exit        otherwise, go finish up this transfer

exit_eof
        moveq   #err.ef,d0      end of file
set_ptr
        move.l  d4,fs_nblok(a0) set current block / byte pointer
        tst.l   d0
        rts

put_byts
        cmp.l   a1,d7           end of string?
        ble.s   put_exit
        move.b  (a1)+,(a5)+     put a byte in the buffer
        bsr.s   move_ptr        ... and update the pointers
        bne.s   put_byts        if buffer not full - continue

        jsr     md_slave(pc)    buffer full - slave it

put_exit
        st      fs_updt(a0)     mark file updated
        move.b  d6,(a4)         set drive id and file bit
        addq.b  #bt.updt-1<<bt..file,(a4) and mark record updated
        bsr.s   set_pend        set pending op to write
        cmp.l   fs_eblok(a0),d4 is this a new end of file?
        bcs.s   com_exit
        move.l  d4,fs_eblok(a0) ... yes - update eof

com_exit
        bsr.s   set_ptr         store current position
        cmp.l   a1,d7           are there any more bytes to transfer?
        bne     dd_mdvbu        ... yes - go back to the start

        cmp.w   #256,d3         were we looking for a terminator?
        bcc.s   ok_rts          no - fine
        moveq   #err.bo,d0      at end of caller's buffer with no terminator
        rts

termin
        bsr.s   move_ptr        update the pointers for terminator
        bsr.s   set_ptr         store current position
        move.l  a1,d7           set end pointer
ok_rts
        moveq   #0,d0
        rts

move_ptr
        addq.w  #1,d4           add 1 to byte pointer
        btst    #blkbits,d4     is it off end of block
        beq.s   exit_ptr        ... no
        addq.w  #1,d5           add 1 to block
        add.l   #1<<16-1<<blkbits,d4 add 1 to block, take block size off byte
exit_ptr
        tst.w   d4              set status to z if new block required
        rts

* Routine to initiate slaving

set_pend
        move.l  a4,d1           set slave block number
        sub.l   sv_btbas(a6),d1
        lsr.l   #btbits,d1
        add.w   bt_sectr(a4),a2 set up pending operation
        move.w  d1,md_pendg(a2)
        sub.w   bt_sectr(a4),a2 restore physical address
        sf      md_fail(a2)     clear fail flag
        rts

* Routine to find the slave block for a sector

* d0 -  o- err.nc if not found (block fetching may have been started) 
* d5 -ip - file (msw) and block (lsw)
* d6 -ip - physdef drive id * 16 + 1<<bt..file (lsb)
* a4 -  o- bt pointer
* a3/a5 destroyed, also d1/d2 if err return

bk_find
        move.l  fs_cblok(a0),a4 get pointer to current block
        move.l  a4,d0           is it set?
        bne.s   bk_find1        yes - start here
        move.l  sv_btbas(a6),a4 start at base of tables
bk_find1
        move.l  sv_bttop(a6),a5 first marker is top of table
bk_markr
        move.l  a4,a3           keep copy of start
bk_check
        cmp.l   bt_filnr(a4),d5 is it the right file/block
        bne.s   bk_next         ... no
        moveq   #-16+1<<bt..file,d0 set mask of drive id and file bit
        and.b   (a4),d0         get drive id and file bit
        cmp.b   d0,d6           is it the right drive
        bne.s   bk_next         ... no
        cmp.b   (a4),d6         check if this block is in use
        bne.s   ok_rts          yes - this is what we want
bk_next
        addq.l  #bt_end,a4      move to next entry in slave block tables
        cmp.l   a5,a4           have we hit a marker?
        bne.s   bk_check        no - look at next entry
        move.l  a3,a5           set the marker to where started this pass
        move.l  sv_btbas(a6),a4 restart at bottom of table
        cmp.l   a3,a4           is that where we started?
        bne.s   bk_markr        no, so carry on with bottom section of table

* Sector is not in slave blocks

        bsr     fnd_sect        ... find the sector + allocate a new block
        move.w  d0,bt_sectr(a4) ... set the sector number
        addq.b  #1<<bt..rdvr,(a4) tell md to read it
        bsr.s   set_pend        set pending
err_ncs
        jmp     md_slave(pc)    sets d0=err.nc

* Routine to allocate a new sector

intrlace equ    12
run_down equ    8
new_sect
        bsr.s   ini_fsec        get file nr/block nr in d2.w
        subq.b  #1,d2           find previous block
        bcc.s   look_fil        was it allocate first block?

        moveq   #-2*(intrlace+run_down),d0 set start position for search
        add.w   md_lsect(a2),d0 last sector allocated - interlace etc.
        bra.s   look_nsec

look_fil
        bsr.s   look_sec        look for sector

* Now look for next suitable blank hole

look_nsec
        sub.w   #2*intrlace,d0  leave some blank sectors
        bge.s   look_fd         if a sector in file look for fd

* The we have got to the lowest sector - so find the highest

        move.w  #maxsec*2,d1    look from top but one sector
look_top
        subq.w  #2,d1
        cmp.b   #badsec,md_map(a2,d1.w) is this totally bad?
        beq.s   look_top
        add.w   d1,d0           set next sector to search

* Look for empty sector

look_fd
        move.w  d0,-(sp)        save sector
loop_fd
        subq.w  #2,d0           on one
        bpl.s   chk_fd          beyond 0?
        move.w  #maxsec*2-2,d0
chk_fd
        cmp.b   #vacant,md_map(a2,d0.w) vacant?
        beq.s   set_sect
        cmp.w   (sp),d0         checked all?
        bne.s   loop_fd
        addq.l  #2+4,sp         remove sector and return address
        moveq   #err.df,d0      drive full
        rts

set_sect
        addq.b  #1,d2           restore block number
        move.w  d2,md_map(a2,d0.w) set file/block number
        move.w  d0,md_lsect(a2) and save last sector allocated
        move.w  #-1,md_pendg(a2) set map modified
        addq.l  #2,sp           remove sector from stack
        rts

* Set up top of map in d0, file/block in microdrive map form in d2

ini_fsec
        move.w  #maxsec*2,d0    start looking one down from top
        move.l  d5,d2           00ff00bb d5.l = file/block
        lsr.l   #8,d2           0000ff00
        move.b  d5,d2           0000ffbb d2.w = file/block
        rts

* General look for sector

isit_sec
        cmp.w   md_map(a2,d0.w),d2 the right one?
        beq.s   rts1
look_sec
        subq.w  #2,d0           move down a sector
        bpl.s   isit_sec
        addq.l  #4+4,sp         drop 2 levels of call!
err_fe
        moveq   #err.fe,d0      file system error
rts1
        rts

* Find a sector for existing block

fnd_sect
        bsr.s   ini_fsec        initialise
        bsr.s   look_sec        ... and look (nb. failure drops 2 levels!)
* Drop into mdvnb

* The algorithm to allocate a new slave block (first version - very simple)
* the BT table is scanned, starting from btpnt (the latest allocated entry),
* looking for 4 lsb's of status showing empty or true copy. The first such is
* set as the latest allocated and generally marked up as empty.
* The entry that btpnt initially pointed to is never considered as available.
* A normal return is only made if a block has been acquired.
* If no block is found, the return address is discarded, d0 is set to err.nc,
* d1 is destroyed, a4=btbas and a5=btpnt.

* d1 -  o- 0
* d5 -ip - file (msw) and block (lsw)
* d6 -ip - physdef drive id * 16 + 1<<bt..file (lsb)
* a4 -  o- pointer to acquired slave block table entry
* a5 destroyed (may be old btpnt or bttop)

dd_mdvnb
        move.l  sv_btpnt(a6),a4 start looking 1 after last block allocated
        move.l  sv_bttop(a6),a5 set marker = top
        bra.s   new_next

new_stat
        moveq   #15,d1
        and.b   (a4),d1         look at status
        subq.b  #bt.empty,d1    is it empty?
        beq.s   new_fnd         ... yes
        subq.b  #bt.true-bt.empty,d1 is it true copy
        beq.s   new_fnd         ... yes
new_next
        addq.l  #bt_end,a4      look at next slave block
newbtbas
        cmp.l   a5,a4           has this hit out marker?
        bne.s   new_stat        no - keep going
        move.l  sv_btpnt(a6),a5 make the marker into last block allocated
        cmp.l   a4,a5           was that where we were anyway?
        move.l  sv_btbas(a6),a4 no - start again at bottom of table
        bne.s   newbtbas        no - we can carry on, if bas<>pnt that is
nonewbt
        addq.l  #4,sp           remove return address
        moveq   #err.nc,d0      not complete
        rts

new_fnd
        move.l  a4,sv_btpnt(a6) reset pointer to last block allocated
        move.l  a4,fs_cblok(a0) and set pointer to current block
        move.b  d6,(a4)         mark new block with drive number, empty
        move.l  d5,bt_filnr(a4) set file and block number
        rts

        end
