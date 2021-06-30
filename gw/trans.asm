* Transform conic section coefficients
        xdef    gw_trans

        xref    gw_choct,gw_pixad

        include 'dev7_m_inc_gw'
        include 'dev7_m_inc_assert'

* The equation which we have been told to work with is:

* f(x,y) = v * x - u * y + alpha/2 * y^2 + beta/2 * x^2 - gamma * x*y

* We are to draw f(x,y) = 0. We are to set off towards x=x0+u, y=y0+v, with
* the second order terms.
* If either alpha or beta is zero, both should be (our forte is ellipses, not
* paraboli).
* Finally, we should have gamma^2 <= alpha * beta, (as we're not too hot on
* drawing hyperboli!) with equality only when they are all zero (not too good
* at drawing pairs of intersecting, or parallel, lines!). Unfortuanately, it's
* all too late now to check this without great hassle, so it's possible we
* may draw just half of one side of a very narrow ellipse.

* Octants:                            v
*                                     ^
*             y             *-*-*- -+- -*- -+- -*   choice of initial octant
*             ^             | 3 * 2 | 2 * 1 | 1 *   such that anticlockwise
*       \  2  |  1  /       +- -*-*-*- -*- -*-*-*   rotation works properly
*         \   |   /         | 3 | 3 * 2 * 1 * 0 |   across each boundary
*       3   \ | /   0       *-*-*-*-*-*-*-*-*- -+
*       ------o------>x     | 4 | 4 * o * 0 | 0 |-->u
*       4   / | \   7       +- -*-*-*-*-*-*-*-*-*
*         /   |   \         | 4 * 5 * 6 * 7 | 7 |   what happens at u=0, v=0
*       /  5  |  6  \       *-*-*- -*- -*-*-*- -+   is pretty irrelevent!
*                           * 5 | 5 * 6 | 6 * 7 |
*                           *- -+- -*- -+- -*-*-*

        section gw_trans

* d0 -ip - start point x coordinate (lsw)
* d1 -ip - start point y coordinate (lsw)
* d2 -i o- alpha / pixel word mask
* d3 -i o- beta / colour masks
* d4 -i  - gamma
* d6 -i o- u / a0
* d7 -i o- v / b0
* a0 -i o- channel definition / d0
* a1 -  o- k1
* a2 -  o- k2
* a3 -  o- k3
* a5 -  o- pixel word address
* a6 -ip - stack frame
* d5 destroyed

gw_trans

* Clean up which way we're being told to curve. If it's not anticlockwise,
* we effectively mirror across the y-axis.

        clr.w   -(sp)           set square y increment in lsw to zero
        move.w  xinc(a6),-(sp)  get basic x increment into msw
        move.l  d2,d5
        or.l    d3,d5           are alpha and beta non-negative?
        bpl.s   clock           yes - going anticlockwise already
        neg.l   d2              negate alpha
        neg.l   d3              negate beta
        neg.l   d6              negate u
        neg.w   (sp)            negate dx
clock

* Next we can simplify our initial octant decisions by a 180 degree rotation

        moveq   #1,d5           diagonal y-increment
        tst.l   d6
        bpl.s   rotok           if u > 0, leave it alone
        bne.s   rotgo           if u < 0, rotate
        tst.l   d7
        ble.s   rotok           if u = 0 and u <= 0, leave it alone
rotgo
        neg.l   d6              negate u
        neg.l   d7              negate v
        neg.w   d5              change y increment to minus one
        neg.w   (sp)            negate dx
rotok

        move.w  (sp),ddx(a6)    store octant zero diagonal move dx
        move.w  d5,ddy(a6)      store octant zero diagonal move dy
        assert  sdx,sdy-2
        move.l  (sp)+,sdx(a6)   store octant zero square move dx,dy

* Now set up for how many octant changes remain to be done.
* We will only need to do at most one clockwise or one or two anti-clockwise.
* The reason this has had to be very finicky is because we must ensure that
* the octant we start in always curls clockwise properly.

        move.l  d7,-(sp)
        smi     octch(a6)       if v >= 0, clockwise is diagonal first
        bmi.s   oct67           if v < 0, we need at least one anticlockwise
        not.l   (sp)            if v >= 0, we may need one clockwise
oct67
        add.l   d6,(sp)         if 0 <= u < -v or 0 < u <= v ... see later

* Now set up all the algorithm's registers

        move.l  d3,a1           k1 = beta
        sub.l   d4,d3
        move.l  d3,a2           k2 = beta - gamma
        move.l  d2,a3
        sub.l   d4,a3
        add.l   a2,a3           k3 = alpha - 2*gamma + beta
        asr.l   #1,d3
        add.l   d3,d7           b0 = v + k2/2
        asr.l   #1,d2
        sub.l   d6,d2
        asr.l   #1,d2
        add.l   d7,d2           d0 = b0 - u/2 + alpha/4
        sub.l   d7,d6           a0 = u - b0

        move.l  d2,-(sp)        save d0
        jsr     gw_pixad(pc)    find pixel address and masks
        move.l  (sp)+,a0        put d0 where it belongs

* Finally, we set which octant we are starting in

        move.b  octch(a6),3(sp) did we select anticlockwise? (and save it)
        bsr.s   choct           always one octant change if going anticlockwise
        tst.b   (sp)+           did we want one clockwise or two anticlockwise?
        bsr.s   choct           one more possible octant change
        move.w  (sp)+,d5        get back which way we were spinning
        eor.b   d5,octch(a6)    from here on in on we go clockwise
rts0
        rts

choct
        bpl.s   rts0
        jmp     gw_choct(pc)    we only do this if -ve flag was set

        end
