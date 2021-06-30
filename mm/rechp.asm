* Release space back to common heap
        xdef    mm_rechp

        xref    mm_rebot,mm_lnkf0

        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_sv'

        section mm_rechp

* Changed to preserve registers, intead of all callers doing them

* d0 -  o- 0 (always succeed)
* a0 -i  - base address to be freed

reglist reg     d1-d3/a1-a2
mm_rechp
        movem.l reglist,-(sp)
        move.l  hp_len(a0),d1   get length of space
        lea     sv_chpfr(a6),a1 pointer to first link
        jsr     mm_lnkf0(pc)    link in

* Check if space is at end

        add.l   d1,a1           add length of last space to address
        cmp.l   sv_free(a6),a1  is it the same as bottom of free
        bne.s   exit

* Release space to slave blocks

        tst.l   d2              was this actually the final block?
        beq.s   goreb
        add.l   a0,d2           no! add prior offset
goreb
        move.l  d2,hp_next(a2)  take this block out of the free list
        move.l  d1,d2           remember what length it was
        jsr     mm_rebot(pc)    return space to free area

* Check for leftovers

        sub.l   d1,d2           was there any left over?
        beq.s   exit            no - ok, it's all gone
        sub.l   d2,a0           back to the one we were releasing
        move.l  d2,(a0)         put the odd bit as length (offset still ok)
        sub.l   a2,a0
        move.l  a0,hp_next(a2)  relink into free chain
exit
        moveq   #0,d0
        movem.l (sp)+,reglist
        rts

        end
