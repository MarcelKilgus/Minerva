* Pitteway's algorithm for conic sections
        xdef    gw_pitt

        xref    gw_choct,gw_pixel

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_gw'
        include 'dev7_m_inc_sv'

* The original algorithm was based on the function value at the mid-point
* of the line between the square or diagonal move's finish points.
* I have changed this to be the average of the function values at those two
* points, which ensures that the algorithm tracks its way along using points
* whose functional values are the closest to zero of those available.
* The original algorithm failed to do this, and as a result was liable to go
* astray when presented with nearly equal values, as the mid point value was
* not giving the correct idea of which point was nearest the curve. This would
* become somewhat unpredictable for small ellipses, whereas my method is at
* least predictable. lwr.

* The algorithm now goes like this:

* 1) If the start and end points are the same, lines and arcs of less than five
*       octants stop without drawing anything.

* 2) Draw the first point.

* 4) If the octant count is greater than four, draw the next point, unless it
*       repeats the start or actually is the finish. This helps with small arcs
*       and ellipses.

* 5) Thereafter, when we get the octant count down less than three, if we're
*       about to draw a point adjacent to the finish point, do so and stop in
*       all cases except degenerate ellipses of more than one pixel.

* This is still not perfect, as silly little arcs may overshoot by one pixel.

* Also, this now checks for octant changing at the right time, i.e. just when
* "d" is about to be updated. If the selected move takes "d" further away from
* zero, that's the time to do an octant change (if there are any left!).

        section gw_pitt

* d0 -i  - x coordinate (lsw)
* d1 -i  - y coordinate (lsw)
* d2 -ip - pixel word mask (lsw)
* d3 -i  - colour masks
* d6 -i  - a
* d7 -i  - b
* a0 -i  - d
* a1 -i  - k1
* a2 -i  - k2
* a3 -i  - k3
* a5 -i  - pixel word address
* a6 -ip - stack frame

* d4-d5 destroyed

gw_pitt
        moveq   #4,d4
        assert  x0,y0-2
        move.l  x0(a6),d5
        assert  x1,y1-2
        cmp.l   x1(a6),d5
        bne.s   xyok            if start and end coincide
        addq.b  #1,type(a6)     cancel degenerate ellipse flag
        bpl.s   xyok            and most things carry on, but
        cmp.b   octs(a6),d4     an arc of less than 5 octants
        ble.s   xyok            or a line stops here
        rts

squbad
        tst.b   octch(a6)       are we expecting a square change?
        beq.s   squgo           no - leave well enough alone
        sub.l   a1,d7           put b back as it was
        bra.s   doch            go try next octant

diabad
        tst.b   octch(a6)       are we expecting a diagonal change?
        bne.s   diago           no - leave well enough alone
        add.l   a3,d6           put a back as it was
doch
        jsr     gw_choct(pc)    go change octant
        subq.b  #1,octs(a6)     have we actually used up all our octants?
        bge.s   whatmove        no - try out our new position
        addq.b  #3,octs(a6)     just maybe...
        bclr    #4,type(a6)     is it an arc, and is this our first time here?
        bne.s   whatmove        yes - we'll let it carry on looking for end pt.
        bra     allover         no - then pack it in now

xyok
        move.w  #$7ffc,-(sp)    set up our counter for the second point
        cmp.b   octs(a6),d4     have we got more than four octants going?
        bgt.s   nospec
        addq.w  #8,(sp)         yes - give it a chance to get away
nospec

* Execution routes here are optimised for line drawing

* Plot a point and move on to next
mainloop
        jsr     gw_pixel(pc)    plot the point

whatmove
        move.l  a0,d4           which move is best?
        bge.s   diamov

* Square move

        add.l   a1,d7           b += k1
        bmi.s   squbad          ahah! this won't help, go see what to do!
squgo
        sub.l   a2,d6           a -= k2
        add.l   d7,a0           d += b
        assert  sdx,sdy-2
        move.l  sdx(a6),d4      square move dx and dy
        bra.s   doy

* Diagonal move

diamov
        sub.l   a3,d6           a -= k3
        bmi.s   diabad          ahah! this won't help, go see what to do!
diago
        add.l   a2,d7           b += k2
        sub.l   d6,a0           d -= a
        assert  ddx,ddy-2
        move.l  ddx(a6),d4      diagonal move dx and dy

* Now adjust the screen address, and masks

doy
        tst.w   d4
        beq.s   dox
        add.w   d4,d1           y += dy
        add.w   linem+1(a6,d4.w),a5 move scr ptr by a line (words -linel,linel)
        swap    d3              swap colour mask

dox
        swap    d4
        tst.w   d4
        beq.s   countit
        bmi.s   xless
        add.w   d4,d0           x += dx
        ror.w   d4,d2           if dx > 0 rotate pixel mask right by it
        bcc.s   countit
        addq.l  #2,a5           if wrapped then move screen ptr forward a word
        bra.s   countit

xless
        add.w   d4,d0           x += dx
        neg.w   d4
        rol.w   d4,d2           if dx < 0 rotate pixel mask left by it negated
        bcc.s   countit
        subq.l  #2,a5           if wrapped then move screen ptr back a word

countit
        subq.w  #4,(sp)         count down our special flag + count
        ble.s   special         if greater than zero, we're happy in main pass

chkend
        cmp.b   #2,octs(a6)     are we into the last couple of octants?
        bgt.s   mainloop        not even on last one or two

        move.w  d1,d5           check if within one pixel in y
        sub.w   y1(a6),d5
        addq.w  #1,d5
        subq.w  #3,d5
        bcc.s   mainloop        not within one, so carry on
        move.w  d0,d4           check if within one pixel in x
        sub.w   x1(a6),d4
        bpl.s   dxispos
        neg.w   d4
dxispos
        cmp.w   xinc(a6),d4     within 1 for 512, or 2 for 256 mode?
        bhi.s   mainloop        no - carry on
lastone
        move.w  #4,(sp)         set counter so it'll drop out after this one
                ;               but make certain this isn't the first or last!

special
        beq.s   allover         pixel count hit zero on main pass
        move.w  d0,d5
        swap    d5
        move.w  d1,d5
        cmp.l   x0(a6),d5       is this an attempt to redraw the first point?
        beq.s   killit          yes - stop now
        cmp.l   x1(a6),d5       is this an attempt to draw the end point?
        bne     mainloop        no - carry on
allover
;       move.w  #4,(sp)         one last thing ...
;       subq.b  #8,type(a6)     ... is the degenerate ellipse flag still set?
;       bne.s   mainloop        yes - then we want to draw the last point
; The above is not currently in use. If it seems a good idea, the ellipse
; calculation should change its type flag from $3d to $08 when it decides that
; an ellipse is degenerate, and changes it to a line.
killit
        addq.l  #2,sp           lose counter
        rts

        end
