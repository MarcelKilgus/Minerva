* Trap to set fill mode/vectors
        xdef    gw_flood,gw_floof

        xref    mm_alchp,mm_rechp

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_sd'

* The parameter in d0.l may be one of:
*             0 - switch fill off
*             1 - switch fill on and clear buffer
*  even (not 0) - address of fill vectors
*   odd (not 1) - (e.g. -1) to clear user fill vectors

* Note that d0-d1/a0 only are touched by alchp, with d1 maybe increased.
* Also rechp returns d0=0 and destroys a0.

        section gw_flood

* d0 -  o- error code
* d1 -i  - parameter
* a0 -ip - channel definition block
* a1 destroyed

gw_floof
        moveq   #0,d1           force flood to turn off
gw_flood
        move.l  d1,-(sp)
        lea     sd_fuse(a0),a1  set convenient pointer
        lsr.l   #1,d1           check parameter
        beq.s   flood           0/1, go do flood stuff
        bcc.s   vector
        clr.l   (sp)            an odd number restores default fill action
vector
        move.l  (sp)+,(a1)      update the user vector
        moveq   #0,d0           no error
        rts

flood
        move.b  sd_fmod-sd_fuse(a1),d0 check current fill mode, d0 zero if off
        assert  sd_fbuf,sd_fuse-4
        move.l  -(a1),a0        pick up any old buffer
        beq.s   wasnt           skip if current fill mode was zero
        jsr     mm_rechp(pc)    if it was on, release the buffer and say so
wasnt
        move.l  (sp)+,d1
        beq.s   clear           if new mode is zero then wipe it out
        assert  sd_ysize,sd_borwd-2
        movem.w sd_ysize-sd_fbuf(a1),d0-d1
        add.w   d1,d1           including borders (so only wdef needs care)
        add.w   d0,d1           get total count of rasters
        addq.w  #(hp_end+3)>>2,d1
        lsl.l   #2,d1           space required is header+4*rasters
        jsr     mm_alchp(pc)    allocate and clear a new buffer
        beq.s   setit
clear
        sub.l   a0,a0           turning mode off or any error, clear buffer
setit
        move.l  a0,(a1)+        update the buffer pointer
        sne     d1
        neg.b   d1
        move.b  d1,sd_fmod-sd_fuse(a1) finally, set fill mode zero/one
        lea     -sd_fuse(a1),a0 put back channel definition block pointer
        rts

        end
