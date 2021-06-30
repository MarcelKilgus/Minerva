* Microdrive block slaving control
        xdef   md_slave,md_slavn

        xref   md_selec
        xref   ss_wser

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_md'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_sv'

        section md_slave

* d0 -  o- err.nc, as it's typical for callers to be about to wait
* a2 -ip - pointer to physical definition
* a3 -  o- pointer to microdrive control register
* d1-d2 destroyed

md_slave
        sf      md_estat(a2)    clear error status
md_slavn
        moveq   #0,d1
        move.b  md_drivn(a2),d1 get drive number
        lea     sv_mdrun(a6),a3 get pointer to status
        st      sv_mdsta-sv_mdrun-1(a3,d1.w) set status
        tst.b   (a3)            is a drive running?
        bne.s   exit

        moveq   #pc.mdvmd,d0    select microdrive
        jsr     ss_wser(pc)     and wait for serial port to finish
        move.b  d1,(a3)         start up this drive
        move.b  #-6,sv_mdcnt(a6) set run-up
        lea     pc_mctrl,a3     set up a3
        jsr     md_selec(pc)    select drive
        or.b    #pc.maskg,sv_pcint(a6) enable gap interrupts
        move.b  sv_pcint(a6),pc_intr-pc_mctrl(a3) (not strictly necessary)

exit
        moveq   #err.nc,d0      implication is we're going to wait for sommat
        rts

        end
