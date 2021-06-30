* Maintain the system task lists
        xdef    mt_lxint,mt_lpoll,mt_lschd,mt_liod,mt_ldd
        xdef    mt_rxint,mt_rpoll,mt_rschd,mt_riod,mt_rdd

        xref    ut_unlnk
        xref    ss_noer

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_mt'

        section mt_lxint

* d0 -i o- trap code / 0
* a0 -ip - absolute pointer to item
* a1 -  o- pointer to start of linked list

mt_lxint
mt_lpoll
mt_lschd
mt_liod
mt_ldd
        add.w   d0,d0
        lea     sv_i2lst-2*mt.lxint(a6,d0.w),a1
        move.l  (a1),(a0)       put pointer to next in this item
        move.l  a0,(a1)         and link it in (used to use ut_link)
        bra.s   exit

* d0 -i o- trap code / 0
* a0 -ip - absolute pointer to item
* a1 -  o- pointer to prior entry or zero if the item was not on the list!

mt_rxint
mt_rpoll
mt_rschd
mt_riod
mt_rdd
        add.w   d0,d0
        lea     sv_i2lst-2*mt.rxint(a6,d0.w),a1
        jsr     ut_unlnk(pc)
exit
        jmp     ss_noer(pc)

        end
