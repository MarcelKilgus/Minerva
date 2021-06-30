* Simplified window open
        xdef    ut_windw,ut_con,ut_scr,ut_wrdef

        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_io'

        section ut_windw

* N.B. ut_windw now correctly gets the top byte of d2.w zero before sd.bordr.
* Also, other than ut_wrdef, the rest now do close the channel they've opened
* if any subsequent part of the setup fails. They used to leave it open!

* a0 i o pointer to name / channel id
* a1 i p pointer to parameter block
* d0   o error code
* d1-d3 destroyed (ut_wrdef preserves d3)

ut_windw
        bsr.s   open
        addq.l  #4,a1
        bsr.s   set_attr
        bra.s   chk_ok

ut_con
        bsr.s   open_wnd
        dc.w    3,'con'

go_scr
        bsr.s   open_wnd
        dc.w    3,'scr'

* Oh bother! The latest TK2 wants to jump 6 on from the ut.scr vector to get
* this code that does the window redefinition. Naturally enough, it doesn't
* want to re-open the channels: they are the magic ones. Hence the following:
ut_scr
        bra.s   go_scr
open_wnd
        move.l  (sp)+,a0
        bsr.s   open
* TK2 comes in here
        bsr.s   ut_wrdef
chk_ok
        beq.s   ret
        moveq   #io.close,d0
        trap    #2
        move.l  d2,d0           copy of error went to d2
ret
        rts

ut_wrdef
        addq.l  #4,a1           move to window definition
        moveq   #sd.wdef,d0     set window size
        moveq   #0,d2           remove any existing border
        bsr.s   trap3

set_attr
        moveq   #sd.setin,d0    set ink
        bsr.s   trap3d

        moveq   #sd.setpa,d0    set paper
        bsr.s   trap3d

        moveq   #sd.setst,d0    set strip
        move.b  (a1),d1
        bsr.s   trap3

        moveq   #sd.bordr,d0    set border
        move.b  -(a1),d2        (if we get here, d2.l has been zeroed)
        bsr.s   trap3d

        moveq   #sd.clear,d0    clear screen without a border
        bsr.s   trap3

        rts     N.B. must keep bsr and rts, in case of error causing addq #4,sp

open
        move.l  a1,-(sp)        save parameter pointer
        moveq   #io.open,d0
        moveq   #-1,d1          for this job
        moveq   #0,d3           old/exclusive
        trap    #2              ... do it
        bra.s   trap_tst

trap3d
        move.b  -(a1),d1
trap3
        move.l  a1,-(sp)        save parameter pointer
        trap    #3
trap_tst
        move.l  (sp)+,a1        restore parameter pointer
        move.l  d0,d2           check error return + save it + ok d2 for bordr
        beq.s   trap_xit
        addq.l  #4,sp           remove return
trap_xit
        rts

        end
