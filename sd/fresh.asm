* Refresh a screen by clearing it, then redrawing all con channels
        xdef    sd_fresh,sd_modes

        xref    sd_bordn,sd_bordr,sd_clear
        xref    cs_color

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_mc'
        include 'dev7_m_inc_ra'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'

        section sd_fresh

* a5 -i p- base address of screen to be refreshed
* d0-d3/a0-a1/a3-a4 destroyed

sd_fresh
        move.l  a5,a1
        move.w  #ra_ssize/4-1,d0 ... long words
cls
        clr.l   (a1)+
        dbra    d0,cls

* Now go through all windows open, resetting and clearing them

        move.l  sv_chbas(a6),a4 start address of channel tables
chn_loop
        move.l  (a4)+,d0        next channel
        blt.s   next_chn        ... does it exist?
        move.l  d0,a0           set address of channel definition block
        move.l  sv_chtop(a6),a3 sysvar extension
        lea     sx_con(a3),a3   linkage area for con driver
        cmp.l   ch_drivr(a0),a3 is it a window?
        bne.s   next_chn        ... no
;       cmp.l   sd_scrb(a0),a5  is this the screen we are doing?
; above is proper, but pander to qptr on it's dummy window... next 4 instrns
        moveq   #ra_bot>>16,d0  treat zero screen base in qptr dummy as scr0
        swap    d0
        or.l    sd_scrb(a0),d0  get this channel's screen base
        cmp.l   d0,a5           is this the screen we are doing?
        bne.s   next_chn        ... no

        bsr.s   sd_modes        set up info for this mode

        tst.b   (a1)            if cursor is not suppressed ...
        sne     (a1)            ... make it invisible

        move.w  sd_borwd(a0),-(sp) save border as we have to re-make it
        clr.w   d2              in case it is transparent
        jsr     sd_bordn(pc)    and remove old border

        jsr     sd_clear(pc)    clear all of window

        move.b  (a3),d1         set border colour
        move.w  (sp)+,d2        ... and width
        jsr     sd_bordr(pc)

next_chn
        cmp.l   sv_chtop(a6),a4 end of channel list?
        blt.s   chn_loop
        rts

* Routine for setting mode dependent info

* d0 -  o- ms3b -1, lsb = 0 for mode 4, 1<<sd..dbwd ($40) for mode 8, ccr set
* a0 -ip - channel definition
* a1 -  o- sd_curf(a0)
* a3 -  o- sd_bcolr(a0)
* d1 destroyed

sd_modes
        lea     sd_pmask(a0),a1 set up addresses of colour masks and bytes
        assert  sd_pmask,sd_smask-4,sd_imask-8,sd_cattr-12,sd_curf-13
        lea     sd_pcolr(a0),a3
        assert  sd_pcolr,sd_scolr-1,sd_icolr-2,sd_bcolr-3
        moveq   #3-1,d0         recreate three of them
col_loop
        move.b  (a3)+,d1        get colour byte
        jsr     cs_color(pc)    set colour mask
        addq.l  #4,a1           next mask
        dbra    d0,col_loop

        assert  sd_xinc,sd_yinc-2
        move.l  #6<<16!10,sd_xinc(a0) default x/y increments
        moveq   #1<<mc..m256,d0
        and.b   sv_mcsta(a6),d0
        lsl.b   #sd..dbwd-mc..m256,d0
        move.b  d0,(a1)+        set sd_cattr, point to sd_curf
        beq.s   rts0            512 - all done
        lsl     sd_xinc(a0)     256 - double the x increment
rts0
        rts

        end
