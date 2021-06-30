* Console/screen driver
        xdef    od_con

        xref    gw_floof
        xref    io_name,io_qout,io_qsetl,io_qtest
        xref    ip_dspm
        xref    mm_alchp,mm_rechp
        xref    sd_clrxx,sd_cure,sd_curs,sd_curt,sd_donl,sd_entry,sd_modes
        xref    sd_newl,sd_scrol,sd_setfo,sd_wdef

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_q'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_ra'
        include 'dev7_m_inc_assert'

* Frame of data used by io.edlin/io.fline
        offset  0
width   ds.w    1       character width of window
dx      ds.w    1       finicky bit at left of window
dy      ds.w    1       finicky bit at top of window
size    ds.w    1       total chars in window
frame   ds.b    1       saved cursor flag
        ds.b    1       padding
buflen  ds.w    1       buffer length

        section od_con

od_con
        dc.w    io-*
        dc.w    open-*
        dc.w    close-*

open
        sub.w   #5*2,sp         make room on stack for parameters
        move.l  sp,a3           and point a3 to it

        jsr     io_name(pc)     check device name (con)
        bra.s   scr             not found - try open screen
        bra.s   opn_exit        bad parameter
        bra.s   open_con        recognised!!
;        if ntsc
;        dc.w    3,'CON',5,' _',420,' X',160,' A',46,' X',0,' _',128
;        else
        dc.w    3,'CON',5,' _',448,' X',180,' A',32,' X',16,' _',128
;        endif

open_con
        moveq   #sd_end+q_queue+2,d1 window def + key header + min 2 queue
        moveq   #0,d2
        move.w  8(sp),d2        get queue length (-ve lengths as unsiged!)
        add.l   d2,d1
        bsr.s   open_sub        open channel and initialise
        bne.s   opn_exit
        lea     sd_end(a0),a2   find address of queue header
        moveq   #sd_end+q_queue,d2
        sub.l   d2,d1           set actual length of queue
        jsr     io_qsetl(pc)    set up queue header
        lea     sv_keyq(a6),a3  point to keyboard queue pointer
        tst.l   (a3)            is this going to be the only queue?
        bne.s   link_in         no - go slot it in with the rest
        move.l  a2,(a3)         make this the current queue (and link to self)
link_in
        assert  q_nextq,0
        move.l  (a3),a3
        move.l  (a3),(a2)       move next queue pointer across
        move.l  a2,(a3)         and link in
        moveq   #0,d0
        bra.s   opn_exit

scr
        jsr     io_name(pc)     check name (scr)
        bra.s   opn_exit        not recognised
        bra.s   opn_exit        bad parameters
        bra.s   open_scr        recognised!!

;        if ntsc
;        dc.w    3,'SCR',4,' _',420,' X',160,' A',46,' X',0
;        else
        dc.w    3,'SCR',4,' _',448,' X',180,' A',32,' X',16
;        endif

open_scr
        moveq   #sd_end+4,d1    window def + 1 dummy
        bsr.s   open_sub

opn_exit
        add.w   #5*2,sp          remove parameters from stack
        rts

open_sub
        jsr     mm_alchp(pc)    allocate table space
        bne.s   ops_exit
        move.l  d1,-(sp)        save length allocated

        sub.l   a1,a1
        move.l  a1,a2
        jsr     sd_setfo(pc)    set fount pointers
        addq.b  #4,sd_icolr(a0) set ink colour to green
        tas     sd_linel+1(a0)  set 128 bytes per line
        move.l  #$807<<16!100<<(15-7),sd_scal(a0) initial scale 100.0

        assert  $20000,ra_bot
        assert  $8000,ra_ssize

        jsr     ip_dspm(pc)     make sure sx_dspm is up-to-date
        move.b  sx_dspm(a4),d0
        addq.b  #ra_bot>>16,sd_scrb+1(a0) set base of first screen
        move.l  sv_jbpnt(a6),a1
        move.l  (a1),a1
        move.w  a6,d1           are two screens available?
        btst    #0,jb_rela6(a1) and is job default screen one? (lsb set)
        ble.s   setscr0         no - then we're there
        tas     sd_scrb+2(a0)   set $28000, base of second screen
        bra.s   setscr1

setscr0
        add.b   d0,d0           fetch up screen 0 bits
setscr1

        move.b  sv_mcsta(a6),-(sp) hold onto the current mode
        move.b  d0,sv_mcsta(a6) replace temporarily with mode 4/8 as needed
        jsr     sd_modes(pc)    go set up mode dependent info
        clr.w   d2              no border
        lea     2+4+4(sp),a1    definition is on stack
        jsr     sd_wdef(pc)
        move.b  (sp)+,sv_mcsta(a6) restore the current mode

        move.l  (sp),d1         restore length allocated
        move.l  d0,(sp)         save error key
        beq.s   ops_pop         if not zero ...
        bsr.s   rechp           ... release space allocated
ops_pop
        move.l  (sp)+,d0        restore error key
ops_exit
        rts

close
        lea     sd_end(a0),a3   set pointer to keyboard queue
        move.l  (a3),d1         is there one?
        beq.s   rechp
        sub.l   a2,a2           in case it's the only one
        cmp.l   d1,a3           is it the only queue?
        beq.s   new_q           yes - this'll sort it out
        move.l  a3,a2           now we need to unlink
        cmp.l   sv_keyq(a6),a3  is this current queue?
        bne.s   unlk_q          no - leave the cursor alone
more_q
        move.l  (a2),a2         get next q
        tst.b   sd_curf-sd_end(a2) is cursor of next queue active?
        bne.s   new_q           ... yes - use it
        cmp.l   (a2),a3         was that the last?
        bne.s   more_q          ... no - keep looking
new_q
        move.l  a2,sv_keyq(a6)  set new queue
        move.l  a3,a2
unlk_q
        move.l  (a2),a2         look at next queue
        cmp.l   (a2),a3         does this point to queue to be closed?
        bne.s   unlk_q
        move.l  (a3),(a2)       link past this queue

rechp
        jsr     gw_floof(pc)    release any fill buffer!
        jmp     mm_rechp(pc)    release table space

io.bp equ 6 makes macro simpler
io_tabl macro
io_tabl
io_tabe setstr (io_bp-$78)
i setnum 0
l maclab
i setnum [i]+1
        assert  [i]-1 io.[.parm([i])]
        dc.b    (io_[.parm([i])]-[io_tabe])&$ffff force error if not positive
 ifnum [i] < 8 goto l
        assert  8 [.nparms]
 endm
        io_tabl pend fbyte fline fstrg edlin sbyte bp sstrg
* First byte of next instruction is $78, which completes the above table with
* a ninth entry (for entry code $08) which also goes to io_bp.
io
        moveq   #sd.extop,d4    N.B. see above!!!!
        assert  1,sd.extop&7
        tst.b   d3
        bne.s   tst_stat
        bset    d4,sd_flags(a0) set flag bit 1 on 1st entry
tst_stat
        tst.b   sv_scrst(a6)    is screen frozen?
        beq.s   io_chk
        moveq   #err.nc,d0      yes - operation not complete
        rts

io_chk
        bclr    d4,sd_flags(a0) clear flag bit 1 if we get here
        sne     d7              iff it was set, set d7.b for 1st entry 
        cmp.b   d4,d0           check if normal serial i/o
        bhs.s   io_dirct

        move.w  d2,d5           set d5 to buffer length
        move.l  d1,d4           set d4 to character count (msw 0 for fline)

        cmp.b   #io.sbyte,d0    check if an input operation
        bcc.s   io_jump         no - ok
        lea     sd_end(a0),a2   find address of keyboard queue
        tst.l   (a2)            check if input queue exists
        beq.s   io_bp           no - bum
        tst.b   d7              is this the first time to here?
        beq.s   io_jump         no - don't try to switch queues

        move.l  sv_keyq(a6),a4  yes - get current input queue
        tst.b   sd_curf-sd_end(a4) is the cursor for this active?
        bne.s   io_jump
        move.l  a2,sv_keyq(a6)  no - switch to this one

io_jump
        move.l  a1,a4           buffer address in a4
        move.b  io_tabl(pc,d0.w),d0 find code for fancy entry points
        jmp     [io_tabe](pc,d0.w)

io_sbyte
        cmp.b   #10,d1          is it newline
        beq.s   new_line
        tst.b   sd_nlsta(a0)    check for out of range flag
        beq.s   out_byt1
        move.b  d1,-(sp)
        bsr.s   nl_sub
        move.b  (sp)+,d1
out_byt1
        bsr.s   sd_sbyte
        beq.s   rts_2           only error is out of range!

        move.w  sd_xinc(a0),d0  move the cursor across (not done if o/r)
        add.w   d0,sd_xpos(a0)
        assert  sd..gchr,7
        tst.b   sd_cattr(a0)    is this graphics (no auto nl?)
        bmi.s   out_exok
        move.b  #1,sd_nlsta(a0) set implicit newline (rats! no reg byte > 0)
        tst.b   sd_curf(a0)     check if cursor visible
        beq.s   out_exok        ... no it is alright
nl_sub
        bsr.s   curoff          if cursor is visible, hide it
        moveq   #0,d0           ensure no error... sd_newl preserves this
        jmp     sd_newl(pc)

io_pend
        jmp     io_qtest(pc)    check this queue

io_sslop
        move.b  (a4)+,d1        get character
        bsr.s   io_sbyte        write it
        addq.w  #1,d4
io_sstrg
        cmp.w   d4,d5           end of buffer?
        bne.s   io_sslop        nope - go send it
        bra.s   io_ok

sd_sbyte
        moveq   #io.sbyte,d0    send byte
io_dirct
        jmp     sd_entry(pc)    use screen driver

io_bp
        moveq   #err.bp,d0
        bra.s   io_mexit

new_line
        tst.b   sd_nlsta(a0)    test newline pending
        bge.s   new_exp         ... it was not explicit before
        bsr.s   nl_sub          a new line was pending so do it
new_exp
        st      sd_nlsta(a0)    ... and this one is explicit
out_exok
        moveq   #0,d0           no error - newline given or done
rts_2
        rts

io_fbyte
        lea     sd_end(a0),a2   a2 is io_q.. queue pointer
        jmp     io_qout(pc)

io_fslop
        bsr.s   io_fbyte        get next character
        bne.s   io_mexit        is it available?
        move.b  d1,(a4)+        put in buffer
        addq.w  #1,d4
io_fstrg
        cmp.w   d4,d5           check for end of buffer
        bne.s   io_fslop
io_ok
        moveq   #0,d0
io_mexit
        move.w  d4,d1           set character count
        move.l  a4,a1           save buffer pointer
        bclr    #sd..gchr,sd_cattr(a0) reset normal character positioning
        rts

curoff
        tst.b   sd_curf(a0)
        ble.s   rts_2
        jmp     sd_curt(pc)     toggle the cursor

* During edlin/fline:
* d0 returned error code only
* d4.msw -1=edlin, 0=fline
* d4.lsw current count of valid chars in buffer ( < d5.lsw, except at end )
* d5.msw not used (zero, at present)
* d5.lsw screen offset of start of buffer (-ve = off top of screen)
* d6.msw not used (undefined, could easily be 0)
* d6.lsw cursor position within buffer ( <= d4.lsw )
* a0 chan / a2 queue ptr
* a4 start of buffer
* a5 stack frame pointer to screen info
* d1-d3/a1-a3 destroyed

io_edlin
        moveq   #-1,d4          for edlin set flag in msb of d4
io_fline        ;               n.b. ioss set d1.l to 0 before fline entry
        move.l  d1,d6           get the cursor position
        swap    d6
        move.w  d1,d4           to be safe, refuse chars > 32767 ...
        bmi.s   io_bp
        cmp.w   d4,d5           ... or chars so far > buffer length ...
        blt.s   io_bp
        cmp.w   d6,d4           ... or cursor > chars so far
        bcs.s   io_bp

        sub.w   d4,a4           reset buff pointer to base
        move.w  d5,-(sp)        save buffer length
        move.b  sd_curf(a0),-(sp) save state of cursor
        tst.b   d7              is this the first time we've got this far?
        beq.s   ed_next         no - skip this stuff
        bsr.s   curoff          if cursor is visible, hide it
        jsr     sd_donl(pc)     *** this should probably be somewhere else
ed_next
        move.b  d7,d1           1st time in?
        bne.s   ed_gotc         yes: use alt prefix as redraw, nice for startup
        bsr.s   io_fbyte        fetch byte from input queue
        beq.s   ed_gotc         something there
        tst.b   (sp)            check state of cursor
        blt.s   ed_exit         it is meant to be invisible
        move.l  d0,-(sp)
        jsr     sd_cure(pc)     enable the cursor
        move.l  (sp)+,d0        
ed_exit
        add.w   d4,a4           set a4 to end of line
        move.w  d6,d1           save the cursor position
        swap    d1
        addq.l  #4,sp           get rid of cursor status and save max len
        bra.s   io_mexit

ed_gotc
        bsr.s   curoff          ensure cursor is off
* create stack frame with all details on current position and screen size
        moveq   #0,d3
        lea     sd_xinc(a0),a1
enqset
        move.l  d0,d2
        moveq   #0,d0
        moveq   #0,d5
        move.w  sd_xsize-sd_xinc(a1),d5
        move.w  sd_xpos-sd_xinc(a1),d0
        bpl.s   enqlft
        clr.w   d0              pull in from off left of screen
enqlft
        sub.w   d0,d5
        bpl.s   enqrgt
        add.w   d5,d0
        clr.w   d5              pull in from off right of screen
enqrgt
        divu    (a1),d0
        move.w  d0,-(sp)
        divu    (a1)+,d5
        add.w   d5,d0
        bne.s   enqok
        moveq   #1,d0           protect against silly windows/cursors!
enqok
        not.b   d3
        bne.s   enqset
* d0=dy/height, d2=dx/width, (sp)=row, 2(sp)=col
        move.w  (sp)+,d5        pick off row
        mulu    d2,d5
        move.w  (sp)+,a2        pick off col
        add.w   a2,d5           width*row+col = screen loc of cursor
        sub.w   d6,d5           screen loc of start of buff, signed
        move.w  d2,d3
        swap    d2
        mulu    d0,d3
        move.w  d3,d0
        move.l  d0,-(sp)        save dy,size
        assert  4,dy,size-2
        move.l  d2,-(sp)        save width,dx
        assert  0,width,dx-2
        move.l  sp,a5           mark the frame
* Stack frame now active
        lea     edittabl,a1
ed_tloop
        move.w  (a1)+,d0        fetch table bytes: msb=jmp/2, lsb=topchar
        sub.b   d1,d0           is the character > lsb byte of entry?
        bcs.s   ed_tloop        yes, continue scan
        lsr.w   #8,d0           pull down execute vector byte
        add.b   d0,d0
        subx.l  d7,d7           put delete flag into d7 ms bits
        lea     0(a4,d6.w),a1   pointer to cursor byte
        moveq   #' ',d2         for word searches
        move.w  d6,d7           set convenient initial value for d7.lsw
        jsr     dis_base(pc,d0.w) go action the byte
        bsr.s   ed_exec1
        addq.l  #frame,sp       lose stack frame
        moveq   #err.bo,d0      in case buffer has become full
        asl.l   #8,d7           clear 1st time flag and test exit flag
        bvc.l   ed_next         still all ones or zeroes, that's fine
ed_exitp
        bpl.s   ed_exit         buffer is full
        addq.w  #1,d4           terminator present
        jsr     sd_curs(pc)     get rid of cursor
        bsr.l   new_line 
        clr.w   d6
        moveq   #0,d0
        bra.s   ed_exitp

dis_base

dis_entr
        moveq   #10,d1          convert shift/enter to normal enter
dis_endr
        move.b  d1,0(a4,d4.w)   store terminator in final byte
        bset    #31-8,d7        cause termination after positioning
        bra.s   dis_allr        move cursor across rest of line

dis_escp
        tst.l   d4
        bmi.s   dis_endr
        bra.s   dis_ignr        change up/down/esc to ignore for fline

dis_rowl
        cmp.w   a2,d6
        ble.s   dis_escp
        sub.w   width(a5),d7
        bge.s   dis_sbc
dis_alll
        clr.w   d7
        bra.s   dis_sbc

dis_rowr
        add.w   d4,a2
        sub.w   width(a5),a2
        cmp.w   a2,d6           is cursor going to go down off line with eod?
        bgt.s   dis_escp        yes: go check for edlin termination
        add.w   width(a5),d7    move whole row
        bra.s   dis_rgt         go check if we need to trim it to eod

dis_onel
        beq.s   dis_rts
        subq.w  #1,d7
        bra.s   dis_sbc

dis_oner
        addq.w  #1,d7
        bra.s   dis_rgt

dis_tabl
        beq.s   dis_rts
        subq.w  #1,d7
        bra.s   dis_tabx

dis_tabr
        addq.w  #8,d7
dis_tabx
        and.w   #-8,d7
dis_rgt
        cmp.w   d4,d7
        ble.s   dis_sbc
dis_allr
        move.w  d4,d7
dis_ignr
dis_sbc
        sub.w   d6,d7
dis_rts
        rts

ed_exec1
        bra.s   ed_exec

dis_spac
        moveq   #' ',d1         change shift/space to ordinary space
dis_char
        bsr.s   dis_allr        tail end char count
        add.w   d7,a1           start at top of buffer
        bra.s   ins_ent

dis_wrdl
wrdls
        subq.w  #1,d7
        bcs.s   wrdx
        cmp.b   -(a1),d2
        beq.s   wrdls
wrdln
        subq.w  #1,d7
        bcs.s   wrdx
        cmp.b   -(a1),d2
        bne.s   wrdln
        addq.l  #1,a1
        bra.s   wrdx

dis_wrdr
        bsr.s   dis_allr
wrdrn
        subq.w  #1,d7
        bcs.s   wrdx
        cmp.b   (a1)+,d2
        bne.s   wrdrn
wrdrs
        subq.w  #1,d7
        bcs.s   wrdx
        cmp.b   (a1)+,d2
        beq.s   wrdrs
        subq.l  #1,a1
wrdx
        move.w  a1,d7
        sub.w   a4,d7
        bra.s   dis_sbc

ins_lp
        move.b  -(a1),1(a1)
ins_ent
        dbra    d7,ins_lp
        move.b  d1,(a1)         insert new char at cursor
        addq.w  #1,d4           add this into buffer count
        move.w  d4,d7
        add.w   d5,d7
        move.w  d6,d0
        add.w   d5,d0
        bsr.s   redraw1         write to end of data (or end of screen)
        moveq   #1,d7           force finish up with position right one
        rts                     if buffer is full it'll catch it after this

ed_exec
        tst.l   d7
        bpl.s   op_move
* Delete
        move.w  d5,d3
        add.w   d4,d3           offset to end of displayed/displayable data
        tst.w   d7              check distance for delete left/right
        bpl.s   op_bdel
        neg.w   d7              make delete left distance positive
        sub.w   d7,d6           new cursor for delete left
op_bdel
        sub.w   d7,d4           less chars in buffer
        lea     0(a4,d6.w),a1   char destination
        move.w  d4,d0
        sub.w   d6,d0           chars to be shifted down in buffer
        bra.s   op_bdent

op_bdlp
        move.b  0(a1,d7.w),(a1)+ pack buffer chars down
op_bdent
        dbra    d0,op_bdlp
        move.w  d3,d7           set old eod
        move.w  d6,d0
        add.w   d5,d0           start display here, maybe
        bpl.s   redraw          ready now if cursor is staying on screen
        not.w   d0
        ext.l   d0
        divu    width(a5),d0    rows that need pulling in, less one
        addq.w  #1,d0
        mulu    width(a5),d0    total to adjust base by
        add.w   d0,d5           pull base up
        move.w  d4,d3
        add.w   d5,d3           new eod
        cmp.w   d3,d7           is it now further down than the old one?
        bge.s   redeodok
        move.w  d3,d7           yes, so use new eod
redeodok
        assert  2,dy-dx,sd_ypos-sd_xpos
        move.l  dx(a5),sd_xpos(a0)
        moveq   #sd.scrtp,d0    clean up top row scrap, maybe
        bsr.s   scrxx
*       clr.w   d0              need to display from start of screen
redraw1
        bra.s   redraw

op_move
        add.w   d7,d6           go straight to new cursor position
        moveq   #0,d1
        move.w  d6,d1
        add.w   d5,d1
        bmi.s   op_scrdn        have to scroll screen down to get cursor on
        clr.w   d0
        sub.w   size(a5),d1
        blt.s   op_noscr
* We need to display the cursor, so we'll have to scroll up some
        divu    width(a5),d1
        addq.w  #1,d1           this number of rows
        bsr.s   negscrol
        move.w  d1,d0
op_noscr
        move.w  size(a5),d7
        add.w   d7,d0
        bra.s   redraw

negscrol
        neg.w   d1
scrol
        moveq   #sd.scrol,d0
scrxx
        move.w  d1,-(sp)
        muls    sd_yinc(a0),d1
        jsr     sd_scrol(pc)   do the scroll
        move.w  (sp)+,d1
        muls    width(a5),d1
        add.w   d1,d5
        rts

op_scrdn
        not.w   d1
        divu    width(a5),d1
        addq.w  #1,d1           this number of rows
        bsr.s   scrol
*       clr.w   d0
        move.w  d1,d7
*       bra.s   redraw          draw that

* Draw any amount of the screen, includes final position to cursor
* d0 start screen offset
* d4 eod
* d5 buffer screen offset
* d6 cursor
* d7 end screen offset
redraw
        move.w  d6,-(sp)
        add.w   d5,d4
        add.w   d5,d6
        move.w  d4,d1
        cmp.w   d6,d1           is cursor supposed to be at eod?
        beq.s   redecur
        subq.w  #1,d1           no - so relax a bit (signed arith on this now!)
redecur
        sub.w   size(a5),d1
        add.w   width(a5),d1
        ext.l   d1
        divs    width(a5),d1    we'd like to scroll up this many rows
        ext.l   d6
        divs    width(a5),d6    this is how many rows we can scroll up
        cmp.w   d6,d1
        ble.s   redscrl
        move.w  d6,d1           at most, push cursor to top row
redscrl
        tst.w   d1
        ble.s   redscrex        either we couldn't, or didn't want to scroll!
        move.w  d0,-(sp)
        bsr.s   negscrol
        move.w  (sp)+,d0
        add.w   d1,d0
        add.w   d1,d4
        move.w  d4,d7           we must now want to show to eod
redscrex
        move.w  d0,d6
        bpl.s   redent
        clr.w   d6
redloop
        cmp.w   size(a5),d6
        bcc.s   redlast
        moveq   #5,d0           clear space at end
        lea     sd_clrxx(pc),a1 new call: lets us wipe space to paper colour
        cmp.w   d4,d6
        bge.s   redgo           after eod must want clearing
        move.w  d6,d1
        sub.w   d5,d1
        blt.s   redgo           before start of data must want clearing
        lea     sd_sbyte,a1
        move.b  0(a4,d1.w),d1   get a real data byte to display
redgo
        moveq   #0,d2
        move.w  d6,d2
        divu    width(a5),d2
        move.w  d2,d3
        lea     sd_yinc(a0),a2
        mulu    (a2),d3
        swap    d2
        assert  sd_xpos,sd_ypos-2,sd_xinc-4,sd_yinc-6
        mulu    -(a2),d2
        swap    d2
        move.w  d3,d2
        add.l   dx(a5),d2
        assert  dx,dy-2
        move.l  d2,-(a2)        store calculated cursor position
        jsr     (a1)            clear char to paper, draw real char or get out
        addq.w  #1,d6
redent
        cmp.w   d7,d6
        blt.s   redloop
redlast
        lea     redstop,a1
        move.w  (sp)+,d6
        add.w   d5,d6
        bra.s   redgo

redstop
        addq.l  #4,sp           discard return
        sub.w   d5,d6
        sub.w   d5,d4
        cmp.w   buflen(a5),d4   is the buffer full yet?
        bne.s   redok           no - we're ok
        moveq   #1,d7
        ror.l   #1,d7           $80000000 for buffer overflow
redok
        rts

flg.del equ     $8000           flag for deletion (or initial re-display)
flg.    equ     0               no flag
cno setnum 0
 assert 0 (dis_ignr-dis_base)&$ff01
ed macro chr,dis,del
 ifnum [chr] = [cno] goto n
 dc.w (dis_ignr-dis_base)<<7!flg.[del]!([chr]-1)
n maclab
 ifnum [chr] <> $20 goto g
chr setnum $c0-1
g maclab
 assert 0 (dis_[dis]-dis_base)&$ff01
 dc.w (dis_[dis]-dis_base)<<7!flg.[del]![chr]
cno setnum [chr]+1
 endm

edittabl
 ed $09 tabr
 ed $0a entr
 ed $1b escp
 ed $20 char
 ed $c0 onel
 ed $c1 alll
 ed $c2 onel del
 ed $c3 alll del
 ed $c4 wrdl
 ed $c6 wrdl del
 ed $c8 oner
 ed $c9 allr
 ed $ca oner del
 ed $cb allr del
 ed $cc wrdr
 ed $ce wrdr del
 ed $d0 rowl
 ed $d8 rowr
 ed $fc spac
 ed $fd tabl
 ed $fe entr
 ed $ff ignr del ; alt cheats a bits. Initial entry uses it. Shorter macro def.

        end
