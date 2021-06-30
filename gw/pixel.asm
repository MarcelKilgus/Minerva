* Draw in a pixel, filling a line if need be
        xdef    gw_pixel

        xref    cs_fill,cs_over

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_gw'
        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_sd'

* The fill buffer is arranged to have at least a pair of words for each row of
* a window. Redefinion of a window always clears them all.
* The first word is the minimum pixel so far seen on the line and the second is
* minimum pixel never seen so far.
* One special case is the initial zero longword, indicating that no pixel has
* yet been seen for this line.
* Another special case crops up if a pixel at 32767 (or even 32766 in mode 8)
* is requested, when the pixel is effectively treated as zero width in order to
* avoid any problems.
* There is a flaw in this code, in that a mode change from 4 to 8 can result in
* a bit of a mess if an existing filled area starts or finishes at an odd
* pixel, and is then extended. It is not clear exactly how to avoid this.

* Note that the cs routines require d0-d3 and a1 as parameters, but preserve
* all registers.

        section gw_pixel

* d0 -ip - x coordinate (lsw)
* d1 -ip - y coordinate (lsw)
* d2 -ip - mask within word fro pixel (lsw)
* d3 -ip - colour masks (msw/lsw)
* a5 -ip - screen word address for pixel
* a6 -ip - stack frame
* d4 destroyed

reglist reg     d0-d3/a0-a1

gw_pixel
        assert  xsize,ysize-2
        move.l  xsize(a6),d4
        cmp.w   d4,d1           if y outside window then do nothing
        bcc.s   rts0
        swap    d4
        tst.b   fmod(a6)
        bne.s   do_fill         if fill mode is on then go to it
dodot
        cmp.w   d4,d0           if x outside window then do nothing
        bcc.s   rts0
        move.w  d3,d4           set up colour mask
        and.w   d2,d4
        tst.b   over(a6)
        beq.s   setit
        eor.w   d4,(a5)         xor it in
rts0
        rts

setit
        move.w  d2,d5           write colour on top
        or.w    (a5),d5         fetch old stuff, but set our bit all ones
        sub.w   d2,d5           then knock them out
        add.w   d4,d5           and put in what we want
        move.w  d5,(a5)
        rts

first
        move.w  d2,-(a1)
        move.w  d0,-(a1)        store single pixel range
single
        movem.l (sp)+,reglist
        bge.s   dodot           now go back to put in this dot
        rts

do_fill
        movem.l reglist,-(sp)   ... save a few registers !

        move.l  chnp(a6),a0     retrieve the channel defn ptr

        move.w  d1,a1
        add.l   a1,a1
        lea     hp_end(a1,a1.l),a1
        add.l   sd_fbuf(a0),a1  256 word pairs, one pair for each line

        move.w  xinc(a6),d2     calculate right edge of pixel
        add.w   d0,d2
        bvc.s   nothuge
        move.w  d0,d2
nothuge

        tst.l   (a1)+
        beq.s   first
        cmp.w   -(a1),d0
        bge.s   right
        cmp.w   -(a1),d0
        bge.s   inside

        move.w  (a1),d2         get left edge of existing area
        move.w  d0,(a1)         replace with this pixel to extend it left
check
        bge.s   lowok           if low is negative we must bring it up to zero
        clr.w   d0
lowok
        cmp.w   d2,d4           if right edge escapes window, trim it down
        bge.s   highok
        move.w  d4,d2
highok
        sub.w   d0,d2           now establish exactly how much we're doing
        cmp.w   xinc(a6),d2
        ble.s   single          if single then do it quick

        swap    d3
        move.w  d3,-(sp)        msw
        move.l  d3,-(sp)        lsw,msw,msw
        move.w  (sp),-(sp)      lsw,lsw,msw,msw
        move.l  sp,a1

        add.w   xmin(a6),d0     add x origin
        add.w   ymin(a6),d1     add y origin
        moveq   #1,d3           just the one row high

        tst.b   over(a6)
        beq.s   fill_it
        jsr     cs_over(pc)
done
        addq.l  #8,sp
inside
        movem.l (sp)+,reglist
        rts

right
        move.w  (a1),d0         get old right edge as start of fill area
        move.w  d2,(a1)         extent right to new edge
        tst.w   d0
        bra.s   check

fill_it
        jsr     cs_fill(pc)
        bra.s   done

        end
