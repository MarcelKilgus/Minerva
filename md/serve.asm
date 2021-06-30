* Microdrive gap interrupt server
        xdef    md_serve

        xref    md_desel,md_read,md_sectr,md_selec,md_verin,md_write
        xref    ss_rser
        xref    ut_err,ut_write

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bt'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_md'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_sv'

blkbits equ     9
btbits  equ     3
        assert  1<<btbits,bt_end

med.len equ     10      bytes in medium name

maxfail equ     7
maxdriv equ     8
maxsec  equ     256

runup   equ     6
rundown equ     7

mapfile equ     $80     (hm... documentation suggests this is $f8!)

* Stack layout:

        offset  4
* Buffer for sector header
        ds.b    2       flag and sector number
hdr_mnm ds.b    med.len medium name
        ds.b    2       random number
mr.len  equ     *-hdr_mnm
* End of sector header 
        ds.b    1       one byte of wasted space (junk)
sav_drv ds.b    1       saved drive id * 16 + 1<<bt.file
sav_btp ds.l    1       saved slave block table entry address
sav_pdf ds.l    1       saved physical definition address

        section md_serve

* Report on bad on changed medium

err_fe
        lea     md_mname(a5),a1
        tst.b   (a1)            is there a name to write
        beq.s   err_exit
        sub.l   a0,a0           write message to channel 0
        moveq   #med.len,d2
        jsr     ut_write(pc)    medium name
        moveq   #err.fe,d0
        jsr     ut_err(pc)      error message
err_exit
        bsr.s   clear           clear out all existing slave blocks
        st      md_estat(a5)    set error flag
        bra.l   desel

* Clear out the slave blocks and pending operations for a drive

* d1/a1 destroyed

clear
        move.l  sv_btbas(a6),a1 start at base of slave block tables
bt_clear
        moveq   #-16+1<<bt..file,d1 set up mask for drive id
        assert  0,bt_stat
        and.b   (a1),d1         get drive id*16 and file flag bit
        cmp.b   sav_drv+4(sp),d1 is it this drive?
        bne.s   bt_next
        move.b  #bt.empty,(a1)  .. yes clear it
bt_next
        addq.l  #bt_end,a1      next slave block
        cmp.l   sv_bttop(a6),a1 ... is the last ?
        bne.s   bt_clear

        lea     md_pendg(a5),a1 now clear out all pending operations
        moveq   #maxsec*2/4-1,d1
pend_clr
        clr.l   (a1)+
        dbra    d1,pend_clr
        rts

* Serve a microdrive gap interrupt
* Stack frame data has been set up for us.

* d0-d7/a0-a5 destroyed

md_serve
        move.b  sv_mdcnt(a6),d2 get run-up / run-down count
        bge.s   ok_up
        addq.b  #1,d2           run up a bit
ok_up

        jsr     md_sectr(pc)    get sector header
err_msg
        bra.s   err_fe          ret+0 unreadable
        rts                     ret+2 not a sector header
                        ;       ret+4 ok

        assert  0,mr.len&3
        moveq   #mr.len/4-1,d0 check the last bytes of the sector
        lea     md_mname+mr.len(a5),a2 against the stored name
chk_med
        move.l  -(a2),d1
        cmp.l   -(a1),d1
        dbne    d0,chk_med
        beq.s   same_med

* New medium in drive

        tst.b   md_estat(a5)    a new medium is in - am I expecting it
        ble.s   err_msg         no - a problem
        tst.b   md_files(a5)    are there any files open?
        bne.s   err_msg         yes - a disaster!
        tst.b   d7              is it sector 0 ?
        bne.s   anrts
        lea     md_map(a5),a1   yes, read it in
        bsr.s   go_read         doesn't return if no good
        bsr.s   clear           clear out all existing slave blocks
        movem.l hdr_mnm(sp),d0-d2 pick up medium name and random number
        movem.l d0-d2,md_mname(a5) put it all into physdef block
set_fnd
        sf      md_estat(a5)    set medium name and map found
        rts

same_med
        tst.b   md_estat(a5)    medium is the same, was server checking it?
        bgt.s   set_fnd         yes, set medium found

        add.w   d7,d7           set pointer to pending list
        bne.s   not_map
        addq.b  #1,md_fail(a5)  this is the map - update fail count
        cmp.b   #1+maxfail,md_fail(a5)
        bgt.s   err_msg
not_map

        add.w   d7,a5
        moveq   #0,d1
        move.w  md_pendg(a5),d1 get pending op
        beq.l   run_down

        tst.b   d2              was drive running down?
        ble.s   ok_cnt
        sf      d2              yes, clear it
ok_cnt

        move.b  d2,sv_mdcnt(a6) reset run_up run_down
* bug! patched by super GC - was addq.b
        addq.w  #2,d1           check for the two special cases (-1/-2)
        bcc.s   normal          it's not a special operation

        lea     md_map(a5),a1   set base address of map
        beq.s   ver_map         was -2 for verify, so go do it
        tst.b   d2              is it still running up?
        bmi.s   anrts
        move.w  #mapfile<<8+0,-(sp) map file, block 0
        jsr     md_write(pc)
        addq.l  #2,sp
        moveq   #-2,d1          now verify
        bra.s   set_spc

go_read
        jsr     md_read(pc)
        addq.l  #4,sp           ret+0, bad, and drop return address
anrts
        rts                     ret+2, ok

ver_map
        jsr     md_verin(pc)    verify
        bra.s   bad_map         ret+0 bad
                        ;       ret+2 ok

        moveq   #0,d1           ok no more special ops
        bra.s   set_spc

bad_map
        moveq   #-1,d1          write it again
set_spc
        move.w  d1,md_pendg(a5) set special op
        rts

normal
        subq.w  #2,d1
        lsl.l   #btbits,d1      convert to slave block pointer
        move.l  sv_btbas(a6),a4
* bug corected by super GC - was add.w!
        add.l   d1,a4
        move.l  a4,sav_btp(sp)  and save it
        lsl.l   #blkbits-btbits,d1 set address of buffer
        lea     0(a6,d1.l),a1   now we have buffer pointer

        move.b  (a4),d1
        assert  bt..accs,bt..wreq-1
        lsl.b   #8-bt..wreq,d1
        bcs.s   write           write required
        bmi.s   verify          verify required
        bsr.s   go_read         doesn't return if no good
        bra.s   read_ok

verify
        jsr     md_verin(pc)
        bra.s   bad_veri        ret+0 bad
                        ;       ret+2 ok
read_ok
        clr.w   md_pendg(a5)    clear pending op
        move.l  sav_pdf(sp),a1
        sf      md_fail(a1)     successful - clear fail flag
        moveq   #bt.true,d0     true copy
        bra.s   set_stat

bad_veri
        moveq   #bt.updt,d0     verify failed - write again
        bra.s   set_stat

write
        tst.b   d2              is drive still running up
        bmi.s   anrts
        move.w  md_map(a5),-(sp) put file / block on stack
        jsr     md_write(pc)
        addq.l  #2,sp
        moveq   #bt.aver,d0     now verify
set_stat
        movem.l sav_drv-3(sp),d6/a4 restore drive*16+1 and slave block pointer
        or.b    d0,d6           add the status
        move.b  d6,(a4)
        moveq   #rundown-2,d2   check for run_down after one sector

* Not a pending operation - check whether to run down

run_down
        tst.b   d2
        bmi.s   set_cnt         still running up
        addq.b  #1,d2
        cmp.b   #1+rundown,d2   do not check every time
        blt.s   set_cnt
        moveq   #0,d2

        moveq   #256-maxsec,d0  check all sectors
        move.l  sav_pdf(sp),a5
        lea     md_pendg(a5),a5
chk_pend
        tst.w   (a5)+           pending op here?
        bne.s   set_cnt         yes, go do it
        addq.b  #1,d0
        bne.s   chk_pend

desel
        jsr     md_desel(pc)    deselect this drive

        lea     sv_mdsta(a6),a5
        moveq   #maxdriv+1,d1   look to see if another drive is waiting
look_next
        subq.b  #1,d1
        move.b  d1,sv_mdrun(a6) say which drive is running
        beq.s   quiet
        tst.b   -1(a5,d1.w)
        beq.s   look_next

        jsr     md_selec(pc)    select it
        moveq   #-runup,d2      run up
set_cnt
        move.b  d2,sv_mdcnt(a6) reset run_up run_down
        rts

quiet
        and.b   #$ff-pc.maskg,sv_pcint(a6) mask the gap interrupt
        jmp     ss_rser(pc)     and re-enable serial output

        end
