* Allocate space in a heap
        xdef    mm_alloc,mm_alloi

        xref    mm_scafr

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_hp'

        section mm_alloc

* Space is taken from the first adequate available space and if it is not an
* exact fit, the early part is used and the later is left as free.
* If all is well, the first longword of the allocated area will be set to its
* overall length, and the second longword will be set to zero.

* d0 -  o- error code (ccr set)
* d1 -i o- space required, rounded up to allocation multiple
* a0 -i o- pointer to pointer to free space / pointer to space allocated
* d2-d3/a1-a2 destroyed

mm_alloc
        moveq   #8-1,d2         allocation multiple
        moveq   #8-1,d0         exit at first adequate space, scraps >= 8

* d0 -i    minimum size for left over bits of memory
*       o- error code (ccr set)
* d1 -i o- space required, rounded up to allocation multiple
* d2 -i  - allocation multiple less one.
* a0 -i o- pointer to pointer to free space / pointer to space allocated
* d3/a1-a2 destroyed

mm_alloi
        jsr     mm_scafr(pc)    scan for free space
        beq.s   err_om          didn't find an adequate space
        sub.l   d1,d3           find what's going spare
        beq.s   re_link         exact fit is perfect
        cmp.l   d0,d3           is what's left over big enough for us?
        bgt.s   split           yes, so we split it up
        add.l   d3,d1           not enough left over to make sense, so extend
        bra.s   re_link         go eat the whole thing

split
        add.l   d1,hp_next(a1)  move link
        move.l  a0,a1
        add.l   d1,a1           find address of new free space
        move.l  d3,hp_len(a1)   record its new length
re_link
        move.l  hp_next(a0),d2  find address of next free space
        beq.s   set_next        is it last link?
        add.l   a0,d2
        sub.l   a1,d2           no - make it relative
set_next
        move.l  d2,hp_next(a1)  reform free chain to skip allocated block
        clr.l   hp_next(a0)     being friendly, clear second word now
        move.l  d1,hp_len(a0)   put length allocated
        moveq   #0,d0
        rts

err_om
        moveq   #err.om,d0      not enough space found
        rts

        end
