* Set flag to say next io call uses relative addressing
        xdef    io_trap4

        xref    ss_rte

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_jb'

        section io_trap4

io_trap4
        movem.l d7/a5-a6,-(sp)  save standard registers
        move.l  sp,d7
        and.w   #$8000,d7
        move.l  d7,a6           do not assume there is only one screen
        move.l  sv_jbpnt(a6),a5 get pointer to job
        move.l  (a5),a5
        tas     jb_rela6(a5)    set msb of flag
        jmp     ss_rte(pc)

        end
