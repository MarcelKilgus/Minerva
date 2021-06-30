* File system slave block management
        xdef    mm_altop,mm_albot,mm_retop,mm_rebot

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_bt'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_assert'

spare   equ     2       number of slave blocks that will be held onto

btbit   equ     3       bits per slave block table entry
sbbit   equ     9       bits per slave block
sblen   equ     1<<sbbit size of slave blocks
        assert  1<<btbit,bt_end

        section mm_fssb

* Workhorse for releasing slave blocks, most of this was in io_slave

reglist reg     d0-d1/d3/a0-a4
sb_slave
        movem.l reglist,-(sp)
        move.w  #sv_fsdef<<2&(-256)!$f0,d1 mask for drive id and part offset
        assert  0,bt_stat
        and.b   (a1),d1         pick out drive bits from status
        asr.w   #2,d1           shift id to make pointer to table
        move.l  sv_fsdef&63(a6,d1.w),a2 get physical definition block
        move.l  fs_drivr(a2),a4 driver linkage address
        lea     -sv_lio(a4),a3  base of driver definition block
        move.l  ch_slave(a4),a4 get entry point of slave
        jsr     (a4)
        movem.l (sp)+,reglist

sb_allop
        moveq   #bt.actn,d2     set up action (read or write) mask
        and.b   (a1),d2         is action pending
        bne.s   sb_slave        yes - go ensure slaving
        sf      (a1)            take this block
ea_top
        add.l   d3,a1           move pointer to next one
ea_bot
        subq.l  #bt_end,d0
        bge.s   sb_allop        any more blocks?
        bra.s   ok_rts

* Allocate space from slave blocks

* d0 -  o- 0 or err.om
* d1 -i o- space to be allocated (may be rounded up)
* a0 -  o- new top or bottom pointer
* d2-d3/a1-a2 destroyed

mm_altop
        add.l   #sblen-1,d1     rounding up
        bsr.s   sb_top          set up pointers to top
        sub.l   d1,a0
        lea     (1-spare)*sblen(a0),a2 allow spare space
        cmp.l   sv_free(a6),a2  check remaining space
        ble.s   err_om
        move.l  a0,sv_basic(a6) save top pointer
        bra.s   ea_top          allocate slave blocks

mm_albot
        add.l   #sblen-1,d1     rounding up
        bsr.s   sb_bot          set up pointers to bottom
        add.l   d1,a0
        lea     (spare-1)*sblen(a0),a2 allow spare space
        cmp.l   sv_basic(a6),a2 check remaining space
        bge.s   err_om
        move.l  a0,sv_free(a6)  save bottom pointer
        bra.s   ea_bot

err_om
        moveq   #err.om,d0      out of memory - set flag
        bra.s   rts0

* Find pointers to slave blocks
sb_top
        move.l  sv_basic(a6),a0 change the top end
        moveq   #-bt_end,d3     and scan down through the slave blocks
        bra.s   sb_addr

sb_bot
        move.l  sv_free(a6),a0  change the bottom end
        moveq   #bt_end,d3      and scan up through the slave blocks
sb_addr
        move.l  a0,d0           the slave block entries are at address
        sub.l   a6,d0           less base (system vars)
        lsr.l   #sbbit-btbit,d0 divided by sblen/bt_end
        move.l  sv_btbas(a6),a1 plus the base of the slave block table
        add.l   d0,a1
        and.w   #-sblen,d1      truncate to a multiple of sblen
        move.l  d1,d0
        asr.l   #sbbit-btbit,d0 slave blocks table area size (keep sign!)
        rts

* Release space to slave blocks

* d0 -  o- 0
* d1 -i o- space to be released (may be rounded down)
* a0 -  o- new top or bottom pointer
* d3/a1 destroyed

mm_retop
        bsr.s   sb_top          set up pointers to top
        add.l   d1,a0
        move.l  a0,sv_basic(a6)
        bra.s   er_top

mm_rebot
        bsr.s   sb_bot          set up pointers to bottom
        sub.l   d1,a0
        move.l  a0,sv_free(a6)
        bra.s   er_bot

sb_rel
        move.b  #bt.empty,(a1)  mark block as empty
er_bot
        sub.l   d3,a1           move to next block
er_top
        subq.l  #bt_end,d0
        bge.s   sb_rel          any more blocks?

ok_rts
        moveq   #0,d0           OK (even if a negative d1 was supplied)
rts0
        rts

        end
