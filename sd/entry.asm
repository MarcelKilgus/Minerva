* Screen driver general entry point
        xdef    sd_entry

        xref    sd_chchk,sd_curt
        xref    cs_char
* + lots of other "xref"'s from the macro below

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_sd'

        section sd_entry

* d0 cr  control parameter / error flag
* a3   s scratch (except for sbyte and extop keys)
* ...... any others used by called routines

reglist reg     d0-d2   need to save when adjusting the cursor

sd_entry
        pea     exit            normally we just test d0 on return
        tst.b   sd_curf(a0)     check if cursor is visible
        ble.s   branch          no - then that's it
        addq.l  #rest-exit,(sp) we want to check the cursor on return
        movem.l reglist,-(sp)   save call parameters
        jsr     sd_curt(pc)     hide cursor
        movem.l (sp)+,reglist

branch
        subq.b  #io.sbyte,d0    check if write a character
        bne.s   range           no - go do all the others

* This used to be the sd_wchar routine.
* Having it in here makes it a little quicker, as we cut out the long jumping,
* we know no one else uses it and we can see it doesn't care about d0 on entry.

* d0   s                    x position
* d1 c s character          y position
* d2   s                    character
* d3   s                    attributes
* a0 c   address of control block
* a1   s                    colour masks
* a2   s                    pointer to fount
* a3   s                    pointer to fount

        jsr     sd_chchk(pc)    check if room for character
        bne.s   anrts
        move.b  d1,d2           put character in position required
        move.l  sd_xmin(a0),d0  get position of top lhs
        add.l   sd_xpos(a0),d0  ... then cursor position
        move.w  d0,d1           ... and put them in the right position
        swap    d0
        move.b  sd_cattr(a0),d3 set attributes
        lea     sd_smask(a0),a1 ... colours
        movem.l sd_font(a0),a2/a3 ... and font
        pea     sd_ncol(pc)     move to next column on return
        jmp     cs_char(pc)     go do the character

* Rest of the code for other sd entries

range
        subq.b  #sd.extop-io.sbyte,d0 is it an extended operation?
        beq.s   extop           yes - go do it
        cmp.b   #(top-bot)/2,d0 is it in our table?
        bhi.s   error           no - that's bad
        add.b   d0,d0           d0 addresses words
        move.w  bot-2(pc,d0.w),a3 load entry offset
        lsr.b   #1,d0           restore d0
        add.b   #sd.extop,d0    ...
        jmp     bot(pc,a3.w)    call appropriate subroutine

extop
        moveq   #sd.extop,d0    put d0 back, just in case it's wanted
        jmp     (a2)            extended operation

cure
        movem.l reglist,-(sp)   save ds
        jsr     sd_cure(pc)     make cursor visible
        movem.l (sp)+,reglist   restore ds
exit
        tst.l   d0
anrts
        rts

rest
        tst.b   sd_curf(a0)     has cursor been made invisible now?
        bge.s   exit            yes - leave it off
        tst.l   d0              was there an error?
        beq.s   cure            no - go enable the cursor
        rts                     yes - leave the cursor as is

error
        addq.l  #4,sp           forget the call ...
        moveq   #err.bp,d0      ... as we're setting an error code
        rts

* Set up the vector table for the sd/gw routines

t       macro
        local   i,p
i       setnum  0
loop    maclab
i       setnum  [i]+1
p       setstr  [.parm([i])]
        ifstr   {[p]} = {error} goto dcit
        xref    [p]
dcit    maclab
        dc.w    [p]-bot
        ifnum   [i] < [.nparms] goto loop
        endm

bot
 t                   sd_pxenq sd_chenq sd_bordr sd_wdef  sd_cure  sd_curs  ;0f
 t sd_pos   sd_tab   sd_nl    sd_pcol  sd_ncol  sd_prow  sd_nrow  sd_pixp  ;17
 t sd_scrol sd_scrol sd_scrol sd_pan   error    error    sd_pan   sd_pan   ;1f
 t sd_clear sd_clrxx sd_clrxx sd_clrxx sd_clrxx sd_setfo sd_recol sd_setco ;27
 t sd_setco sd_setco sd_setfl sd_setul sd_setmd sd_setsz sd_fill  sd_donl  ;2f
 t gw_fig   gw_fig   gw_fig   gw_fig   gw_scale gw_flood gw_gcur           ;36
top

        end
