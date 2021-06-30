* Process an area of the screen (clear, scroll and pan)
        xdef    sd_clear,sd_clrxx,sd_pan,sd_recol,sd_scrol

        xref    sd_home
        xref    cs_fill,cs_pan,cs_recol,cs_scrol

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_mc'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_sv'

        section sd_area

* d0 -i o- area key / 0(no error)
* d1 -i  - distance to pan/scroll (sd.panxx, sd.scroll and sd.scrxx only)
* a0 -ip - channel definition block
* a1 -i  - recolour map address (sd.recol only)
* d1-d3/a1-a2 destroyed

regon   reg     d0-d1/d5-d7/a0-a1
regoff  reg     d4-d7/a0-a1

sd_recol
        moveq   #0,d0           recolour whole window only
        lea     cs_recol(pc),a2 set cs entry point for recolour
        bra.s   go_coset        a1 has recolour table already

sd_clear
        jsr     sd_home(pc)     reset cursor for full clear, d0.l = 0 on return
sd_clrxx
        assert  0,sd.clrtp&7-1,sd.clrbt&7-2,sd.clrln&7-3,sd.clrrt&7-4
        lea     cs_fill(pc),a2  set cs entry point for area fill
        bra.s   go_area

sd_scrol
        assert  0,sd.scrol&7,sd.scrtp&7-1,sd.scrbt&7-2
        lea     cs_scrol(pc),a2 set cs entry point for scroll
        bra.s   go_area

sd_pan
        assert  3,sd.pan&7,sd.panln&7-3,sd.panrt&7-4
        subq.b  #3,d0
        lea     cs_pan(pc),a2   set cs entry point for pan
        btst    #mc..m256,sv_mcsta(a6) is it low res mode
        beq.s   go_area         pan even distances only
        bclr    #0,d1           pan even distances only

* Now set up the parameters for different types of area ops

* 0 full area
* 1 top of window
* 2 bottom of window
* 3 cursor line
* 4 right of cursor line
* 5 cursor only (for prettier io.edlin - new call!)

go_area
        lea     sd_pmask(a0),a1 fill with paper colour
go_coset
        move.l  d4,-(sp)        save d4
        movem.l regon,-(sp)     save distance and temp registers
        ;       d0         d1         d2         d3
        assert  sd_xmin    sd_ymin-2  sd_xsize-4 sd_ysize-6 \
                sd_xpos-10 sd_ypos-12 sd_xinc-14 sd_yinc-16
        ;       d6         d7         a0         a1
        movem.w sd_xmin(a0),d0-d4/d6-d7/a0-a1 get all window parameters
        moveq   #7,d4           extract key ...
        and.l   (sp)+,d4        ... out of the way
        beq.s   end_all         key 0 - we've done it
        subq.b  #2,d4
        beq.s   set_2
        bpl.s   set_345
        cmp.w   d7,d3           check ypos against ysize
        ble.s   end_all         if cursor position is below screen, do whole
        move.w  d7,d3           key 1 - only operate down to cursor
        bmi.s   end_zap         if cursor is above screen, do nothing
        bra.s   end_all

set_2
        add.w   a1,d7           calculate incremented ypos
        bmi.s   end_all         if negative, do whole window
        sub.l   d7,d3           key 2 - go down to bottom
        bls.s   end_zap         if below window, do nothing
        bra.s   end_ypos

* Check that bottom of area is not below bottom of window
* OK if ypos + yinc <= ysize, i.e. ysize - ypos - yinc <= 0
set_345
        sub.l   a1,d3
        blo.s   end_zap         do nothing if yinc > ysize
        cmp.l   d7,d3
        blo.s   end_zap         do nothing if cursor start off screen
        move.w  a1,d3           we do yinc for key > 2, if all ok
        subq.b  #2,d4
        bmi.s   end_ypos        key 3 - we've done it
        sub.w   d6,d2           do xsize - xpos
        bls.s   end_zap         do nothing if cursor off left/right of screen
        add.w   d6,d0           start at xmin+xpos
        tst.b   d4
        beq.s   end_ypos        key 4 - we're ready
        exg     a0,d2           key 5 - only operate on cursor
        cmp.w   a0,d2
        bls.s   end_ypos
end_zap
        lea     rts0,a2         lose routine, we're skipping any action
end_ypos
        add.w   d7,d1           start at ymin+ypos
end_all
        movem.l (sp)+,regoff    restore distance and temp registers
        jsr     (a2)            do it
exit
        move.l  (sp)+,d4        reload d4
        moveq   #0,d0           register no error, ever
rts0
        rts

        end
