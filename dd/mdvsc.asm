* Microdrive scatter load
        xdef   dd_mdvsc

        xref   dd_mdvnb
        xref   md_read,md_sectr,md_slave

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bt'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_md'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_sv'

maxfail equ     7               maximum full rotations before giving up

maplen  equ     256             one bit for every possible block number

bitmap  equ     fs_spare        b*32 spare for bitmap
remain  equ     bitmap+maplen/8 b one less than blocks still needing read
lstblok equ     remain+1        b last occupied block number (0..255)
lstbyte equ     lstblok+1       w size (1..512) of last block
hdrbuf  equ     lstbyte+2       b*14 buffer for sector header

blkbits equ     9
blksize equ     1<<blkbits
btbits  equ     3
        assert  1<<btbits,bt_end

        section dd_mdvsc

* lwr's notes:

* This scatter load always reads the whole file, ignoring any current position
* and requested length, plus it crashes if the buffer address supplied is odd.

* Also, the caller has probably just read the header and therefore the first
* two blocks will usually already be available in slave blocks. It seems stupid
* that a load reads them twice!

* A better system all round would be for the normal serial io.fstrg to do any
* slave blocks that are already available, then using this to load the rest,
* the bulk of which would be direct reads to the user's buffer area, exceptions
* being any odd bytes in the first and last blocks.

* Finally, I wonder if anyone would notice if the supplied start/length were
* used, particularly as they are already used if the requested length is less
* than the magic number 4096 (actually, the size that requires about one
* revolution of the tape, given the standard interleave), when the i/o routine
* doesn't even come here!

* P.S. Wouldn't it be even nicer if the mdv stuff kept track of roughly which
* sector on the tape it was at?

* d0 -  o- error code
* d2 -i  - requested length (not used!)
* d6 -i  - drive id * 16 + 1<<bt..file
* a0 -ip - channel definition
* a1 -i o- user buffer
* a2 -ip - physical definition
* d1-d7/a3-a5 destroyed

* Locally:
* d0-d4/d6 used by md routines
* d5 pointer to bit in file map
* d7 current block number / address rel to a1
* a3 microdrive control register
* a4 slave block (set by dd_mdvnb)
* a5 file map etc.

reglist reg     a0-a2/a4

dd_mdvsc
        jsr     dd_mdvnb(pc)    find a slave block
        subq.l  #bt_end,sv_btpnt(a6) and free it straight after use
* Note. The above causes scans for free blocks to find this block straight off.
* As memory allocation is not allowed when interrupted code in in supervisor
* mode, we'll not lose it.

        move.l  a4,d5           calculate address of slave block
        sub.l   sv_btbas(a6),d5 ... take away base of tables
        lsl.l   #blkbits-btbits,d5 divided by bt_end, multiplied by block size
        move.l  d5,a4
        add.l   a6,a4           plus base of memory

        jsr     md_slave(pc)    start drive and d0 = err.nc
        lea     pc_mctrl,a3
        and.b   #$ff-pc.maskg,sv_pcint(a6) stop server killing drive
        move.b  sv_pcint(a6),pc_intr-pc_mctrl(a3)

* We'll get on with sommat else for a moment ...

        assert  fs_eblok,fs_ebyte-2
        move.l  fs_eblok(a0),d2 get last block/byte
        assert  fs_nblok,fs_nbyte-2
        move.l  d2,fs_nblok(a0) set current block/byte (always to eof)
        subq.l  #1,d2
        and.w   #blksize-1,d2
        addq.w  #1,d2           convert to: last active block / byte 1-blksize

        assert  bitmap+maplen/8,remain,lstblok-1,lstbyte-2
        lea     remain(a0),a5
        move.l  d2,(a5) save it
        swap    d2              get last active block number
        move.b  d2,(a5)         put extra block counter

        moveq   #maplen/8/4-1,d5
lop_fmap
        clr.l   -(a5)           clear bitmap of file map
        dbra    d5,lop_fmap

        moveq   #7,d5
        and.b   d2,d5           remember odd bits
        lsr.w   #3,d2           for every complete 8 blocks
        bra.s   smap_dbr

smap_lop
        st      (a5)+           set bitmap bits for those blocks not yet read
smap_dbr
        dbra    d2,smap_lop

        addq.b  #2,d2           make d2 = $ff01
        rol.w   d5,d2
        move.b  d2,(a5)         set bitmap bits for last 1..8 blocks of file

* Is the right drive running now?

        cmp.b   sv_mdrun(a6),d1 is the right drive running?
        bne     ena_gap         no - we'll have to wait

* Now start reading all the blocks of the file

        movem.l reglist,-(sp)

* We have seen sector zero - see if we have a failure to read file

inc_fail
        addq.b  #1,md_fail(a2)
        cmp.b   #2+maxfail,md_fail(a2) full rotations to give up after
        bge.s   err_fe
rep_enab
        and.w   #$f8ff,sr       enable interrupts to allow in ext or poll
        or.w    #$0700,sr       disable them again so i can have the whole ql
rep_noen ; come here after actually reading a sector - no time for interrupts!

        move.l  (sp),a0         restore a0
        lea     hdrbuf(a0),a1   put the sector header somewhere safe
        jsr     md_sectr(pc)    get sector header
        bra.s   err_fe          ... oops                ret+0
        bra.s   rep_enab        ... not a header        ret+2
                                ; good return           ret+4

        movem.l (sp),reglist    restore the addresses
        move.w  d7,d5
        beq.s   inc_fail        ok if not the sector 0 map
        add.w   d5,d5
        move.b  md_map(a2,d5.w),d0 get file number from sector map
        cmp.b   fs_filnr+1(a0),d0 check it's the one we want
        bne.s   rep_enab
        move.b  md_map+1(a2,d5.w),d7 replace sector with the block number
        moveq   #7,d5           convert it to point to the file map
        and.b   d7,d5
        ror.l   #3,d7
        btst    d5,bitmap(a0,d7.w) do we need this block?
        beq.s   rep_enab

        move.l  a4,a1           put sector read into slave block
        jsr     md_read(pc)     read it (a5 preserved, as it happens)
go_noen
        bra.s   rep_noen        get next sector quick!  ret+0
                                ; good return           ret+2

        movem.l (sp),reglist    restore addresses

* Maybe we should make a final check that d1=file/d2=block here?
* That would be just in case we had managed to hiccup past the record, or
* more importantly, the record had been erroneously recorded! E.g. the map was
* not the right one! (lwr)

        bclr    d5,bitmap(a0,d7.w) mark sector found
        rol.l   #3,d7           restore block number

        move.w  #blksize,d0     full block normally
        cmp.b   lstblok(a0),d7  is it the last file block?
        bne.s   not_last        no - copy to end of it
        move.w  lstbyte(a0),d0  get the number of bytes in last block
not_last
        lsl.w   #blkbits-1,d7
        add.l   d7,d7           is it the first file block?
        lea     -md_deend(a1,d7.l),a5 where to put data normally
        bne.s   not_frst
        moveq   #md_deend,d1    yes - move on past the file header
        add.l   d1,a4
        add.l   d1,a5
        sub.w   d1,d0           copy fewer bytes
not_frst

        ror.l   #2,d0           long words, and save odd byte count
        bcc.s   unbf_dbr        carry means there is an odd word to do
        move.w  (a4)+,(a5)+     if so, do it
        bra.s   unbf_dbr

err_fe
        moveq   #err.fe,d0      ... we've bombed out
        bra.s   done

unbf_lop
        move.l  (a4)+,(a5)+     move a long word
unbf_dbr
        dbra    d0,unbf_lop

        add.l   d0,d0           see if there's an odd byte to go
        bpl.s   notabyte
        move.b  (a4)+,(a5)+     if so, do it
notabyte

        subq.b  #1,remain(a0)   are there any more to do?
        bcc.s   go_noen         not finished yet
        moveq   #0,d0

done
        movem.l (sp)+,reglist   remove addresses from stack
        sf      md_fail(a2)     clear failure flag
        move.l  fs_eblok(a0),d7 get pointer to end
        move.l  d7,fs_nblok(a0) make it the current postion
        lsl.w   #16-blkbits,d7
        lsr.l   #16-blkbits,d7
        lea     -md_deend(a1,d7.l),a1 adjust caller's register properly

ena_gap
        or.b    #pc.maskg,sv_pcint(a6) re-enable gaps to let server run down
        and.w   #$f8ff,sr       re-enable interrupts
        rts

        end
