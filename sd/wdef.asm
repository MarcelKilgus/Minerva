* Redefines the window area
        xdef    sd_bordn,sd_bordr,sd_wdef

        xref    cs_color,cs_fill
        xref    gw_floof
        xref    sd_home

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sd'

        section sd_wdef

* d0 -  o- error code
* d1 -i  - border colour
* d2 -i  - border width (we now use only the lsb, to avoid bug in TK2!)
* a0 -ip - window channel definition block
* a1 -i  - pointer to width, height, x and y (wdef only)
* d3-d4 destroyed

reglist reg     d1-d2/a2

sd_wdef
        movem.l reglist,-(sp)   save registers, all but a2 get scrapped really
        move.l  a1,a2           save param pointer
        jsr     gw_floof(pc)    force flood off, in case window height changes
        jsr     sd_home(pc)     home the cursor
        movem.w (a2),d0-d3      load up window definition

        exg     d0,d2           put xmin
        exg     d1,d3           and ymin in the right place

        move.w  #256,d4         bit number 0 and ready to check y
        bclr    d4,d0           ensure both xwidth and xmin are even
        bclr    d4,d2
        bsr.s   xycheck         check that ymin/ywidth are sensible
        add.w   d4,d4           = 512, ready to check x
        bsr.s   xycheck         check that xmin/xwidth are sensible
        clr.w   sd_borwd(a0)    reset border width (lwr: why?)
        bra.s   border

xycheck
        tst.w   d3
        ble.s   pop_err         width/height must be strict positive
        add.w   d3,d1           get rhs/bot
        cmp.w   d4,d1           compare to max
        bhi.s   pop_err         must be at most that
        sub.w   d3,d1           go back to lhs/top
        bmi.s   pop_err         that must be positive
        exg     d0,d1           swap lhs/top for next call
        exg     d3,d2           swap width/height for next call
        rts

* A little piece of code to adjust a window for a border
rst_wind
        neg.w   d4              remove border
adj_wind
        add.w   d4,d1           add border to ymin
        add.w   d4,d4           double the border
        sub.w   d4,d3           and take it away from ysize
        ble.s   pop_err

        add.w   d4,d0           add border to xmin
        add.w   d4,d4           double it again
        sub.w   d4,d2           and take it away from xsize
        ble.s   pop_err

        asr.w   #2,d4           restore border width and set z if it is zero
        rts

pop_err
        addq.l  #4,sp           remove return address
error
        moveq   #err.or,d0      out of range
        bra.s   exit

fill
        jmp     cs_fill(pc)

* Entry point to just redefine a border

sd_bordr
        move.b  d1,sd_bcolr(a0) save border colour
sd_bordn
        movem.l reglist,-(sp)   save registers, all but a2 get scrapped really
        cmp.w   sd_borwd(a0),d2 has border width changed?
        beq.s   rem_bord
        jsr     sd_home(pc)     home cursor
rem_bord
        movem.w sd_xmin(a0),d0-d4 get old window definition
        bsr.s   rst_wind        and remove the border
border
        move.b  7(sp),d4        get new border width
        ext.w   d4              check border width, ignoring msb (tk2 bug!!!)
        bmi.s   error           get out if it's silly

        bsr.s   adj_wind        adjust the window and set status on d4
        movem.w d0-d4,sd_xmin(a0) put in definition block
        beq.s   exit_ok         if there is no border - give up now

        move.l  (sp),d1         get new border colour
        cmp.b   #128,d1         check if it is transparent
        beq.s   exit_ok

        move.l  sp,a1           put mask on stack
        jsr     cs_color(pc)    convert to colour mask
        move.w  sd_ymin(a0),d1  restore the ymin

* Now to draw the border
* For convenience we reset the window to full size

        bsr.s   rst_wind
        neg.w   d4

        exg     d4,d3           set ysize to border width
        bsr.s   fill            fill 1

        add.w   d4,d1           set ymin to bottom
        sub.w   d3,d1           less border width
        bsr.s   fill            fill 2

        exg     d4,d3           restore ysize
        sub.w   d3,d1           ymin less a border
        add.w   d4,d4           double the border
        sub.w   d4,d3           ysize less two borders
        add.w   d4,d1           ymin plus border

        exg     d4,d2           set xsize to border width
        bsr.s   fill            fill 3

        add.w   d4,d0           set xmin to rhs
        sub.w   d2,d0           less border width
        bsr.s   fill            fill 4

*       1111111111111111111     This is the pattern of filling that went on
*       1111111111111111111     above. Note that (unlike older versions) the
*       3333           4444     corners are not filled in twice.
*       3333           4444
*       3333           4444
*       2222222222222222222
*       2222222222222222222

exit_ok
        moveq   #0,d0           no error
exit
        movem.l (sp)+,reglist
        rts

        end
