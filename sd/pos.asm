* Cursor control routines
        xdef    sd_chchk,sd_donl,sd_home,sd_ncol,sd_newl,sd_nl,sd_nrow,sd_pcol
        xdef    sd_pixp,sd_pos,sd_prow,sd_setc,sd_tab

        xref    sd_scrol

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_mc'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_sv'

        section sd_pos

sd_pcol ; move to previous column
        move.w  sd_xpos(a0),d1  decrement x cursor
        sub.w   sd_xinc(a0),d1
        bra.s   same_row

sd_ncol ; move to next column
        move.w  sd_xinc(a0),d1  increment x cursor
        add.w   sd_xpos(a0),d1
same_row
        clr.w   d2              same y cursor
        bra.s   addypos

sd_prow ; move to previous row
        move.w  sd_yinc(a0),d2  decrement y cursor
        neg.w   d2
        move.w  sd_xpos(a0),d1  same x cursor
        bra.s   addypos

sd_nrow ; move to next row
        move.w  sd_xpos(a0),d1  same x cursor
incrow
        move.w  sd_yinc(a0),d2  increment y cursor
addypos
        add.w   sd_ypos(a0),d2
        bra.s   sd_pixp

sd_home ; home
        clr.l   sd_xpos(a0)     home cursor (n.b. this doesn't check space!)
        bra.s   exit

sd_tab ; absolute column
        move.w  sd_ypos(a0),d2  old y cursor
        bra.s   pos_x

sd_pos ; absolute position
        mulu    sd_yinc(a0),d2  new y cursor
        move.l  d2,d0
        swap    d0
        tst.w   d0
        bne.s   err_or
pos_x
        mulu    sd_xinc(a0),d1  new x cursor
        move.l  d1,d0
        swap    d0
        tst.w   d0
        bne.s   err_or

sd_pixp ; absolute pixel position
        move.w  d1,d0
        bmi.s   err_or
        swap    d0
        move.w  d2,d0
        bsr.s   check           check cursor + increment against size
        bmi.s   err_or

sd_setc ; set cursor position with no checks
        btst    #mc..m256,sv_mcsta(a6) is it low res?
        beq.s   set_it
        bclr    #0,d1           x coordinate on 2 pixel boundry
set_it
        movem.w d1-d2,sd_xpos(a0); save new cursor position
exit
        bsr.s   clr_nl          clear newline pending flag
ok
        moveq   #0,d0           clear error flag
        rts

sd_nl ; newline, if no scroll needed
        moveq   #0,d1           set x cursor to lhs
        bra.s   incrow

sd_chchk ; check room for a character at current position
        move.l  sd_xpos(a0),d0  get position
        bmi.s   err_or          x is off lhs
        tst.w   d0
check
        bmi.s   err_or          y is off top
        add.l   sd_xinc(a0),d0  add increment
        cmp.w   sd_ysize(a0),d0 y coordinates in lsw
        bhi.s   err_or
        swap    d0
        cmp.w   sd_xsize(a0),d0 x coordinates in lsw
        bls.s   ok
err_or
        moveq   #err.or,d0
        rts

reglist reg     d0-d2/a1

sd_donl ; do any pending newline
        tst.b   sd_nlsta(a0)    exit if no newline pending
        beq.s   rts0
sd_newl ; send a newline, scrolling if need be
        movem.l reglist,-(sp)   save crashable registers
        bsr.s   sd_nl           send newline
        beq.s   clear
        moveq   #sd.scrol,d0    scroll up
        move.w  sd_yinc(a0),d1
        neg.w   d1
        jsr     sd_scrol(pc)
        clr.w   sd_xpos(a0)     cursor left
clear
;$$        moveq   #0001100b,d0    check for both xor and over
;$$        and.b   sd_cattr(a0),d0
;$$        bne.s   end_newl
;$$        moveq   #sd.clrln,d0    erase line
;$$        jsr     sd_clrxx(pc)
;$$
;$$end_newl
        movem.l (sp)+,reglist
clr_nl
        sf      sd_nlsta(a0)    clear newline pending flag
rts0
        rts

        end
