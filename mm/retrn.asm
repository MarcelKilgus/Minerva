* Release transient program space
        xdef    mm_retrn

        xref    mm_mubas,mm_lnkf0

        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_sv'

        section mm_retrn

* a0 -i  - base address to be freed
* d0-d3/a1-a3 destroyed

mm_retrn
        bsr.s   freeit          go free the space

* Check if space is at bottom

        cmp.l   sv_trnsp(a6),a1 has freed space come out at bottom of area?
        bne.s   rts0            no - forget it

* Remove space from free chain

        tst.l   d2              was this the last in the chain?
        beq.s   mklnk
        add.l   a0,d2           no - add offsets
mklnk
        move.l  d2,hp_next(a2)  remove area from free list

* Move basic up

        move.l  d1,d2           remember how long it was
        jsr     mm_mubas(pc)    release space d1 (d2,a2 should remain)
        add.l   d1,sv_trnsp(a6) update transient program area

* Check out any leftovers

        sub.l   d1,d2           remove area released
        beq.s   rts0            if zero, it's all gone
        move.l  sv_trnsp(a6),a0 get address of odd bit
        move.l  d2,hp_len(a0)   show its length
freeit
        move.l  (a0),d1         get length of space
        lea     sv_trnfr(a6),a1 pointer to first link
        jmp     mm_lnkf0(pc)    link in

rts0
        rts

        end
