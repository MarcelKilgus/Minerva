* Select and deselect a microdrive
        xdef    md_desel,md_selec

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_delay'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_vect4000'

        section md_sedes

* d1 -i  - drive to select (call for select only)
* a3 -ip - address of microdrive control register
* d0/d2 destroyed

        assert  pc.selec,1<<pc..sclk+1<<pc..sel
        assert  pc.desel,1<<pc..sclk

md_selec
        moveq   #pc.selec,d2    clock in select bit first
        subq.w  #1,d1           and clock it through n times
        bra.s   clk_1st

md_desel
        moveq   #8-1,d1         deselect all
clk_loop
        moveq   #pc.desel,d2    clock in deselect bit
clk_1st
        move.b  d2,(a3)         clock high
        delay   18              wait
        bclr    #pc..sclk,d2    clock low
        move.b  d2,(a3)         clocks into first drive
        delay   18              wait
        dbra    d1,clk_loop

        rts

        vect4000 md_desel,md_selec

        end
