* Sets up pixel address and masks
        xdef    gw_pixad

        include 'dev7_m_inc_gw'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_sv'

        section gw_pixad

* d0 -ip - x coordinate (lsw)
* d1 -ip - y coordinate (lsw)
* d2 -  o- pixel mask within word (msw preserved)
* d3 -  o- colour masks (lsw for line at y coordinate)
* a0 -ip - channel definition block
* a5 -  o- screen address of word containing pixel
* a6 -ip - graphics stack frame

gw_pixad
        move.w  d0,-(sp)        save x coordinate
        move.w  d1,d2           copy y coordinate
        add.w   sd_xmin(a0),d0  adjust for window position
        add.w   sd_ymin(a0),d2

        move.l  sd_scrb(a0),a5  get screen base address
        move.w  sd_linel(a0),d3
        move.w  d3,linel(a6)    set line length
        neg.w   d3
        move.w  d3,linem(a6)    and its negation
        muls    d2,d3           multiply line length by line number (nb signed)
        sub.l   d3,a5           pixel line address (note d3 was negated)

        move.l  sd_imask(a0),d3 basic colour mask
        lsr.b   #1,d2
        bcs.s   noswap
        swap    d3              if line number is even then swap colour masks
noswap

        move.w  #$8080,d2       basic pixel mask for 4 colour
        btst    d2,xinc+1(a6)
        bne.s   rotate
        move.w  #$c0c0,d2       basic pixel mask for 8 colour
rotate
        ror.w   d0,d2           rotate pixel mask over pixel position in word

        asr.w   #3,d0           word number in line
        add.w   d0,d0           byte offset in line
        add.w   d0,a5           finally, pixel word address

        move.w  (sp)+,d0        reload original x coordinate
        rts

        end
