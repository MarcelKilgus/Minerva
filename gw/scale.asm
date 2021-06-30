* Sets graphics scale factor
        xdef    gw_scale

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_sd'

        section gw_scale

gw_scale
        assert  sd_yorg,sd_xorg-6,sd_scal-12
        lea     sd_yorg(a0),a2
        moveq   #3*6,d0
loop
        move.b  (a1)+,(a2)+
        subq.b  #1,d0
        bne.s   loop

        rts

        end
