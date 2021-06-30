* Change octants
        xdef    gw_choct

        include 'dev7_m_inc_gw'

        section gw_choct

* d6 -i o- a
* d7 -i o- b
* a0 -i o- d
* a1 -i o- k1
* a2 -i o- k2
* a3 -i o- k3
* a6 -ip - stack frame

* d4-d5 destroyed

gw_choct
        not.b   octch(a6)       which one are we expecting?
        bne.s   diag            if diagonal, go do it

* Do a square octant change, to get b positive

        tst.w   sdx(a6)
        bne.s   ddxok
        neg.w   ddx(a6)
ddxok

* if sdy=0:ddy=-ddy
        tst.w   sdy(a6)
        bne.s   ddyok
        neg.w   ddy(a6)
ddyok

* Calculate new variable values for d,b,a,k1,k2,k3

        move.l  a1,d4
        neg.l   d4
        move.l  d4,a1           k1' = -k1
        add.l   a2,d4           w = k2 + k1'
        move.l  d4,a2
        add.l   a1,a2           k2' = w + k1'
        neg.l   d7
        add.l   d4,d7           b' = w - b
        move.l  d7,d5
        sub.l   d6,d5
        sub.l   a0,d5
        move.l  d5,a0           d' = b' - a - d
        sub.l   d7,d6
        sub.l   d7,d6
        add.l   d4,d6           a' = a - 2*b' + w
        lsl.l   #2,d4
        sub.l   a3,d4
        move.l  d4,a3           k3' = 4*w - k3

        rts

* Change the movement data across a diagonal boundary

diag
        tst.w   sdy(a6)
        bne.s   sdyok           if sdy is zero
        clr.w   sdx(a6)         sdx = 0
        move.w  ddy(a6),sdy(a6) sdy = ddy
        bra.s   sdxok

sdyok
        tst.w   sdx(a6)
        bne.s   sdxok           else if sdx is zero
        clr.w   sdy(a6)         sdy = 0
        move.w  ddx(a6),sdx(a6) sdx = ddx
sdxok

* Calculate new d,b,a,k1,k2 and k3

        move.l  a3,d4
        neg.l   d4
        move.l  d4,a3           k3' = -k3
        add.l   a2,d4
        add.l   a2,d4           w = 2*k2 + k3'
        add.l   a3,a2           k2' = k2 + k3'
        move.l  d4,d5
        sub.l   a1,d5
        move.l  d5,a1           k1' = w - k1
        move.l  a2,d5
        asr.l   #1,d5
        add.l   d6,d5
        add.l   d5,d7           b' = b + a + k2'/2
        asr.l   #1,d5
        add.l   a0,d5
        neg.l   d5
        add.l   d7,d5
        move.l  d5,a0           d' = b' - d - a/2 - k2'/4
        asr.l   #1,d4
        add.l   d4,d6
        neg.l   d6              a' = - w/2 - a

        rts

        end
