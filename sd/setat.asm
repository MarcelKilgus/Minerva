* Set attributes of character
        xdef    sd_setfl,sd_setmd,sd_setsz,sd_setul

        xref    sd_donl,sd_newl,sd_scrol

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_mc'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_sv'

        section sd_setat

* d1 c   attribute on or off / xsize
* d2 c   ysize
* a0 c   pointer to window block

sd_setfl
        btst    #mc..m256,sv_mcsta(a6) give up if 256 mode
        beq.s   ok_rts
        moveq   #1<<sd..flsh,d0 mask of flash bit
        bra.s   check_d1

sd_setmd
        moveq   #1<<sd..xor!1<<sd..trns,d0 set both trans and xor bits
        lsl.b   #2,d1           move mode bits to the right place
        bra.s   set_bit

sd_setul
        moveq   #1<<sd..ulin,d0 set underline bit
check_d1
        tst.b   d1              see if parameter is zero
        sne     d1              set whole byte
        bra.s   set_bit

sd_setsz
        jsr     sd_donl(pc)     ensure pending newline is done
        moveq   #1,d3
        moveq   #err.bp,d0
        cmp.w   #3,d1           ensure character sizes are in range
        bhi.s   rts0
        cmp.w   d3,d2
        bhi.s   rts0
        btst    #mc..m256,sv_mcsta(a6) check for 256 mode
        beq.s   set_inc
        bset    d3,d1           force width to double
set_inc
        move.b  xtab(pc,d1.w),sd_xinc+1(a0) ... & reset lsb of increments
;       if ntsc
;       move.b  sv_tvmod(a6),d0  pick up television mode (0,1 or 2)
;       and.w   #2,d0            mask down to the 525-line bit
;       add.w   d0,d2            pick up second index if 525 lines
;       endif
        move.b  ytab(pc,d2.w),sd_yinc+1(a0)
;       if ntsc
;       sub.w   d0,d2            set d2 to rights
;       endif   ; ntsc
        assert  sd..dbwd-1,sd..exwd,sd..dbht+1
        asr.b   #1,d2
        roxl.b  #sd..exwd,d1    combine the sizes and shift to the right place
        moveq   #7<<sd..dbht,d0 set all size bits
        bsr.s   set_bit
        move.w  sd_xpos(a0),d0  check if new character size is off side
        add.w   sd_xinc(a0),d0
        cmp.w   sd_xsize(a0),d0
        bls.s   chk_botm
        jsr     sd_newl(pc)     force newline
chk_botm
        move.w  sd_ysize(a0),d1
        sub.w   sd_yinc(a0),d1
        blo.s   ok_rts          hmmm... can't fit a char in, so give up?
        lea     sd_ypos(a0),a1
        sub.w   (a1),d1         check if new character size is off bottom
        bhs.s   ok_rts          ok, it fits
        add.w   d1,(a1)         otherwise, scroll up by minimum possible
        moveq   #sd.scrol,d0
        jsr     sd_scrol(pc)
ok_rts
        moveq   #0,d0           no error
rts0
        rts

set_bit
        and.b   d0,d1           set bits required
        not.b   d0              invert the mask
        and.b   d0,sd_cattr(a0) mask out the bits required
        or.b    d1,sd_cattr(a0) and reset them
        bra.s   ok_rts

xtab    dc.b    6,8,12,16
ytab    dc.b    10,20
;       if ntsc
;ytab2
;        assert  ytab+2,ytab2
;        dc.b    8,16            vertical spacings for ntsc
;        endif
        end
