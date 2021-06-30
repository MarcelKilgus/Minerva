* Read/set translation and/or message table addresses.
        xdef    mt_cntry

        xref    ss_rte

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'
        include 'dev7_m_inc_assert'

        section mt_cntry

* d0.l -  o- 0 for ok or err.bp for bad parameter
* d1.l -i o- translation table <-1 on, -1 no change, 0 off or 1 local default.
* d2.l -i o- message table address, <=0 no change or 1 local default.

* d1-d2 are undefined on error and nothing will have been altered.
* Values of 1 in either/both of d1/d2 will be changed to their default address.

reglist reg     d4/a0-a2
mt_cntry
        assert  0,mt.cntry>>6 ; and we hope(?) >>3 is non-zero
        movem.l reglist,-(sp)
        move.l  sv_chtop(a6),a0 basic pointer for default settings
        assert  sv_trtab,sv_mgtab-4
        movem.l sv_trtab(a6),a1-a2 pick up current settings
get_it
        exg     d1,d2
        exg     a1,a2           if all ok, these swap twice
        move.l  d1,d4           check param
        ble.s   skip2           <=0 doesn't alter addresses
        asr.l   #1,d4           check out parameter ...
        beq.s   setdef          ... one, leave with default
        bcc.s   chk_head        ... even, that's needs header checked
err_bp
        moveq   #err.bp,d0      say bad parameter
        bra.s   to_rte

setdef
        move.l  sx_msg(a0),d1   pick up default address
chk_head
        move.l  d1,a1           use the address
        cmp.w   #$4afb,(a1)     correct table start value?
        bne.s   err_bp          no... that's an error
skip2
        subq.l  #sx_msg-sx_trn,a0 point to tranlate default second time round
        lsr.b   #3,d0           have we done both yet?
        bne.s   get_it          no - do the second parameter

        movem.l a1-a2,sv_trtab(a6) store possibly modified values

        move.l  d1,d4
        not.l   d4              was translate table parameter exactly -1
        beq.s   to_rte          yes - don't touch sv_tran
        not.l   d4              only precise zero turns off flag
        sne     sv_tran(a6)     set flag for translate

to_rte
        movem.l (sp)+,reglist
        jmp     ss_rte(pc)

        end
