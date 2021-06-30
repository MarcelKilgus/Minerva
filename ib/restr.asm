* RESTORE sets data line number
        xdef    ib_restr

        xref    ca_evali

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'

        section ib_restr

ib_restr
        move.l  a4,a0
        jsr     ca_evali(pc)
        move.l  a0,a4
        blt.s   rts0
        beq.s   set_stm
        addq.l  #2,bv_rip(a6)
        move.w  0(a6,a1.l),d0   pick up actual line number
set_stm
        move.w  d0,bv_dalno(a6) set new data linumber
        assert  1,1&bv_daitm,bv_daitm-bv_dastm
        move.w  #1<<8!1,bv_dastm(a6) 1st statement/item
        moveq   #0,d0
rts0
        rts

        end
