* Finds the largest contiguous space for the transient area
        xdef    mt_free

        xref    mm_scafr
        xref    ss_noer

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_assert'

        section mt_free

* This doesn't actually include the fact that a small spare slot at the front
* of the transient area could also be acquired when job 0 moves.

* d0 -  o- 0
* d1 -  o- maximum of d2 and a0 below
* d2 -  o- maximum free slot already in transient area
* a0 -  o- free space between common heap and job 0
* d3/a1-a2 destroyed

mt_free
        moveq   #0,d0           scan all free space
        moveq   #0,d1           for any space >= 0
        lea     sv_trnfr(a6),a0 in transient area
        jsr     mm_scafr(pc)    get d2 = largest free space in transient area

        move.l  sv_basic(a6),a0 get top of free area
        sub.w   #2*512,a0       take away enough space for two buffers (lwr)
        sub.l   sv_free(a6),a0  this is the amount we could move job 0 by

        move.l  a0,d1
        cmp.l   d1,d2
        ble.s   exit
        move.l  d2,d1           produce maximum of the two values
exit
        jmp     ss_noer(pc)

        end
