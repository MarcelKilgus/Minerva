* Enquire size / position
        xdef    sd_pxenq,sd_chenq

        xref    sd_donl

        include 'dev7_m_inc_sd'

        section sd_enq

* a0 c p base of definition block
* a1 c p base of enquiry block

sd_pxenq
        jsr     sd_donl(pc)     do newline if pending
get_size
        move.l  sd_xsize(a0),(a1) get size
        move.l  sd_xpos(a0),4(a1) get position
        bra.s   okrts

sd_chenq
        bsr.s   sd_pxenq        fetch pixel size / position

        addq.l  #4,a0           temporarily adjust window block pointer
        addq.l  #6,a1           point to y position
        bsr.s   chr_calc        recalculate y size and position
        addq.l  #2,a1           point to x position
chr_calc
        subq.l  #2,a0           move window pointer back
        bsr.s   chr_posn        first do position
        subq.l  #4,a1           then move back to size
chr_posn
        move.w  (a1),d0         get pixel size / position (msw is already zero)
        divu    sd_xinc(a0),d0  divide by character increment
        move.w  d0,(a1)         put it back
okrts
        moveq   #0,d0
        rts

        end
