* Set font addresses
        xdef    sd_setfo

        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'

        section sd_setfo

* a0 -i p- pointer to window block
* a1 -i o- address of new primary fount (<= 0 sets as default)
* a2 -i o- address of new secondary fount (<= 0 sets as default)

sd_setfo
        move.l  a3,-(sp)
        move.l  sv_chtop(a6),a3
        move.l  a1,d0           check address of primary font
        bgt.s   prim_ok
        move.l  sx_f0(a3),a1    use default fount
prim_ok
        move.l  a2,d0           check address of alternative fount
        bgt.s   secd_ok
        move.l  sx_f1(a3),a2    use default fount
secd_ok
        move.l  (sp)+,a3
        movem.l a1-a2,sd_font(a0) set it
        moveq   #0,d0           never any error
        rts

        end
