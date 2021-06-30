* Allocate/free a suitable space in vv table
        xdef    bv_alvv,bv_alvvz,bv_frvv

        xref    bv_chvvx
        xref    mm_clrr

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_mt'

        section bv_alvv

* d0 -  o- 0
* d1 -ip - how much needed
* a0 -  o- address of piece of vv to use relative to a6
* ccr-  o- z
* a1 -  o- ri pointer from bv_rip(a6), useful at times

allist  reg     d1-d3/a2-a3
bv_alvv
        movem.l allist,-(sp)
        bsr.s   alvv
        bra.s   pop

* As above, but fast clear to zero of allocated area follows
bv_alvvz
        movem.l allist,-(sp)
        bsr.s   alvv
        subq.l  #8,0(a6,a0.l)   was this just an eight byte allocation?
        beq.s   pop             yes, alloc has cleared 2nd word for us
        jsr     mm_clrr(pc)     use fast clear for longer areas
pop
        movem.l (sp)+,allist
        move.l  bv_rip(a6),a1   quite useful to set a1 for some callers
        rts

fail
        move.l  d1,a3           save space we're asking for
        jsr     bv_chvvx(pc)    no space within table, add to top
        move.l  a3,d1           restore what we asked for
        move.l  bv_vvp(a6),a0   get current top of vv area
        add.l   d1,bv_vvp(a6)   expand the area by the amount asked for
        bsr.s   lnkfr           link in added amount
        move.l  a3,d1           restore what we asked for again
alvv
        moveq   #mt.alloc,d0    look for a free space (rounded to * 8 by this)
        move.w  #bv_vvfre,a0    pointer to pointer to first free space
        trap    #1
        move.l  d0,d2           found one?
        bne.s   fail
        rts

* d0 -ip - possible error code
* d1 -i  - length of space to free
* a0 -i  - start of space to free
* ccr-  o- result of testing d0.l

frlist  reg     d0/d2-d3/a1-a3
bv_frvv
        addq.l  #7,d1
        asr.l   #3,d1
        asl.l   #3,d1           round up to nearest multiple of 8
        ble.s   end_0           just in case there's nothing to free
lnkfr
        movem.l frlist,-(sp)
        moveq   #mt.lnkfr,d0
        move.w  #bv_vvfre,a1
        trap    #1
        movem.l (sp)+,frlist
end_0
        tst.l   d0              let caller know the state of their error flag
        rts

        end
