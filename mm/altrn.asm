* Allocate space in transient program area
        xdef    mm_altrn,mm_gotrn,mm_whtrn

        xref    mm_lnkf0,mm_mdbas,mm_scafr

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_sv'

* Memory is allocated from the last adequate space in the transient area and,
* if this is not an exact fit, the early part is left free and the later part
* is allocated.
* If at first try not enough memory can be found, job 0 is asked to move down.

* As a temporary measure, this has been split up so that multibasics can see if
* they can shuffle to a new area when they release space. This supports a very
* simple algorithm for reallocation of their sizes.

        section mm_altrn

* Find an adequate transient area space

* ccr-  o- z if no adequate space was found (a2 destroyed)
* d0 -  o- 0
* d1 -i o- space required, rounded up to a multiple of sixteen
* a2 -  o- pointer to pointer to adequate space found
* d3 -  o- 0
* d0/d2-d3/a0-a1 destroyed

mm_whtrn
        lea     sv_trnfr(a6),a0 get first link pointer
        moveq   #16-1,d2        allocate in multiples of sixteen
        moveq   #0,d0           scan all of free space
        jsr     mm_scafr(pc)
        tst.l   d2              check if adequate space found
        rts

pop_rts
        addq.l  #4,sp
        rts

* Not enough space found
no_room
        move.l  d1,-(sp)        save required length
        assert  sv_trnsp,sv_trnfr-4
        assert  4,hp_next
        lea     sv_trnfr-hp_next(a6),a1
        add.l   hp_next(a1),a1  first free in transient prog area
        cmp.l   sv_trnsp(a6),a1 is this equal to bottom of area?
        bne.s   lenok
        sub.l   hp_len(a1),d1   yes - reduce length required to be allocated
lenok

        jsr     mm_mdbas(pc)    ask job 0 to move down
        bne.s   pop_rts         out of memory?
        lea     sv_trnsp(a6),a1
        sub.l   d1,(a1)         update bottom of transient prog area
        move.l  (a1)+,a0        this is the freed up area now
        assert  sv_trnsp,sv_trnfr-4
        jsr     mm_lnkf0(pc)    link in new space
        move.l  (sp)+,d1        restore length required

* Allocate a new transient space

* d0 -  o- error code (set to out of memory)
* d1 -i o- space required, rounded up to a multiple of sixteen
* a0 -  o- pointer to space allocated
* d2-d3/a1-a2 destroyed

mm_altrn
        bsr.s   mm_whtrn
        beq.s   no_room

* Allocate whole or part of a trn space

* d0 -  o- 0
* d1 -ip - space required, a multiple of sixteen
* a0 -  o- pointer to space allocated
* a2 -ip - pointer to pointer to area to be used

mm_gotrn
        move.l  a2,a0           get pointer to space
        add.l   hp_next(a2),a0  absolute
        move.l  hp_len(a0),d0   and length of this
        sub.l   d1,d0           check whether space is exact fit
        bgt.s   enough
        move.l  hp_next(a0),d0  get next link pointer
        beq.s   set_next        is it last?
        add.l   a0,d0           no - adjust it
        sub.l   a2,d0
set_next
        move.l  d0,hp_next(a2)  link past
        bra.s   ok_rts

* We don't bother extending over odd scraps here, because the transient area
* is never going to have a vast number of fragments.
enough
        move.l  d0,(a0)         shorten free block
        add.l   d0,a0           move pointer to new area
        move.l  d1,(a0)         set new length
ok_rts
        moveq   #0,d0
        rts

        end
