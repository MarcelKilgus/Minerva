* Allocate space in common heap
        xdef    mm_alchp

        xref    mm_alloi,mm_albot,mm_clear,mm_lnkf0

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_hp'

        section mm_alchp

* A version of alchp that preserves much more context.
* This saves doing it all the places it gets called from. (lwr)

* d0 -  o- return error (ok or "out of memory", ccr set)
* d1 -i o- space required (may be modified to be slightly increased)
* a0 -  o- pointer to space allocated (if found)

reglist reg     d1-d3/a1-a2     (d1 modded if allocation succeeds)

* Come here when the heap needs more space
new_free
        add.l   (a0),a1         add length of last block to address
        cmp.l   sv_free(a6),a1  is this equal to top of area
        bne.s   lenok
        sub.l   (a0),d1         reduce length required to be allocated
lenok

        jsr     mm_albot(pc)    allocate from bottom of free area
        bne.s   exit            if out of memory, get out

        sub.l   d1,a0           set base of area allocated
        lea     sv_chpfr(a6),a1
        jsr     mm_lnkf0(pc)    link in new space

        movem.l (sp)+,reglist   restore length, rest so we can drop back in

mm_alchp
        movem.l reglist,-(sp)

        lea     sv_chpfr(a6),a0 get first link pointer
        moveq   #16-1,d2        allocation multiple
        moveq   #16,d0          don't leave scraps of 16, as they're useless
        jsr     mm_alloi(pc)    allocate some free space
        bne.s   new_free        check if adequate space found

        lea     sv_chpfr-hp_next(a6),a2 a1 might point to a new free space
        cmp.l   a1,a2           or it might point to the free space pointer
        beq.s   ownok
        clr.l   hp_owner(a1)    it's a free space - owned by 0
ownok

        move.l  d1,(sp)         tell caller what they actually got
        addq.l  #8,a0           skip the length, and 2nd already cleared
        subq.l  #8,d1
        jsr     mm_clear(pc)    clear the area
        subq.l  #8,a0
exit
        movem.l (sp)+,reglist
        rts                     (status set)

        end
