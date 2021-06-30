* IPC keyboard reader
        xdef    ip_dspm,ip_kbend,ip_kbrd

        xref    io_qin,io_qtest
        xref    sd_cure

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_ipcmd'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_mc'
        include 'dev7_m_inc_q'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'
        include 'dev7_m_inc_vect4000'

        section ip_kbrd

* Main keyboard read routine. Can be called by replacement keyboard code.

* d1 -i  - keyrow data in 6 lsb
* d2 -i  - ctrl/shift/alt in 3 lsb
* a2 -ip - current keyboard queue address
* d0/d6/a0-a1/a3-a4 destroyed

ip_kbrd
        clr.w   sv_arbuf(a6)    get rid of previous auto repeat
        move.l  sv_chtop(a6),a4 get sysvar extension
        move.l  sx_kbenc(a4),a3 get encoder address
        jsr     (a3)            call encoder via vector table
        bra.s   special         special processing return
        bra.s   kb_inch         put it into the queue
        rts                     ignore char return

* Routine to finish off keyboard read and handle auto-repeat.

* d3 -ip - number of polls missed
* d5 -i  - bit 4 set if last key is held down
* a2 -ip - current keyboard queue
* d0-d2/a3 destroyed

ip_kbend
        asr.b   #4,d5           see if the key is still held down
        bcc.s   autorld         if not, reload the counter and get out
        sub.w   d3,sv_arcnt(a6) step counter by the number of polls
        bgt.s   rts0            if it hasn't timed out yet
        jsr     io_qtest(pc)    is the queue empty?
        beq.s   shortd          no, so don't allow autorepeat
        move.w  sv_arbuf(a6),d1 retrieve char to be repeated
        beq.s   shortd          nothing
        bsr.s   kb_inch         put it into the queue
shortd
        move.w  sv_arfrq(a6),sv_arcnt(a6) reload with the shorter delay
        rts

* Special processing routines
spent   macro   t
[.lab]  dc.b    (([t])-spend)&$7fffffff
        endm

sptab
*                       ctrl/space              event 4 = break job 0
*                       ctrl/alt/space          event 5 = break multi
*                       shift/ctrl/space        event 6 = user event 0
*                       shift/ctrl/alt/space    event 7 = user event 1
        spent   ctlt    ctrl/tab                alternate screen
        spent   frez    ctrl/alt/tab            toggle display freeze
        spent   rts0    shift/ctrl/tab          reserve... easy to key!
        spent   soft    shift/ctrl/alt/tab      soft reset
        spent   comp    ctrl/enter              compose
        spent   ctlc    ctrl/alt/enter          cursor to next queue
        spent   caps    shift/ctrl/enter        caps lock
        spent   user    shift/ctrl/alt/enter    call user subroutine

special
        subq.b  #4,d1
        bpl.s   usetab
        bchg    d1,sx_event(a4)
        rts

usetab
        move.b  sptab(pc,d1.w),d1
        jmp     spend(pc,d1.w)

* Put a char in the queue
kb_inch
        cmp.w   sv_cqch(a6),d1
        beq.s   ctlc
        sf      sv_scrst(a6)    unfreeze screen
        move.w  d1,sv_arbuf(a6) store char in the autorepeat buffer
        cmp.b   #255,d1         is it a two-byte code?
        bne.s   in1
        jsr     io_qtest(pc)    how many bytes are left? (nb only d1.b zapped)
        subq.w  #2,d2           are they enough?
        blt.s   autorld         no, don't put the character in
        st      d1              reset the alt code
        bsr.s   in1             put the escape in the queue
        lsr.w   #8,d1           get the second code
in1
        jsr     io_qin(pc)      put it in the queue and return
autorld
        move.w  sv_ardel(a6),sv_arcnt(a6) reload the auto-rept counter
        rts

frez
        not.b   sv_scrst(a6)    toggle freeze flag
rts0
        rts

caps
        not.b   sv_caps(a6)     toggle caps lock flag byte
        lea     sv_csub(a6),a4  get capslock user routine address
isprog
        tst.l   (a4)            is there some code there?
        beq.s   rts0            no - not a good idea to call it...
        jmp     (a4)            yes, call it and get out
* N.B. changed above to use a4 instead of a5, which wasn't saved!

comp
        addq.b  #1,sv_ichar(a6) set compose start
        rts

user
spend   equ     user-31
        assert  0,sx_case
        move.l  (a4),d0         get user code routine address
        bpl.s   rts0            no flag (bit 31), so no call
        bclr    d1,d0           don't let msb propagate into pc
        move.l  d0,a4           if it was set up the way we want (negative) ...
        bra.s   isprog          ... check there's some code before calling it

ctlt
        bsr.s   ip_dspm         ensure sx_dspm is up to date
        bchg    #7,sx_dspm(a4)  toggle displayed screen
        move.b  sx_dspm(a4),d0  pick up new value
        bmi.s   ctlt1           top bit set, use screen 1
        add.b   d0,d0           shift for screen 0
ctlt1
        and.b   #1<<mc..blnk+1<<mc..m256+1<<mc..scrn,d0
        move.b  d0,mc_stat      set hardware only
        rts

soft
        moveq   #9,d1
        jmp     390             soft reset, quick

ctlc
        move.l  a0,-(sp)        save a0
        lea     -sd_end(a2),a0  find start of io definition block
        tst.b   sd_curf(a0)     should cursor in old wdw be visible?
        bge.s   switch_q
        jsr     sd_cure(pc)     ensure cursor in old window is visible
        lea     sd_end(a0),a2   restore a2
switch_q
        assert  q_nextq,0
        move.l  (a2),a2         switch to next queue
        cmp.l   sv_keyq(a6),a2  is this the original queue?
        beq.s   end_swit
        tst.b   sd_curf-sd_end(a2) is this cursor active?
        beq.s   switch_q        no...
        move.l  a2,sv_keyq(a6)  set new key queue pointer
        clr.w   sv_fstat(a6)    reset cursor flash cycle
end_swit
        move.l  sd_scrb-sd_end(a2),d1 have a look at the screen base here
        add.w   d1,d1           does it end with $0000 or $8000?
        bne.s   offscr          no - forget it
        roxr.b  #1,d1
        add.b   sv_mcsta(a6),d1 are we already on the indicated screen?
        bpl.s   offscr          yes - forget it
        swap    d1
        subq.b  #2,d1           is it $xx020000 or $xx028000?
        bne.s   offscr          no - forget it
        bsr.s   ctlt            switch over to that screen
        move.b  d0,sv_mcsta(a6) and say that's what we're on
offscr
        move.l  (sp)+,a0        restore a0
        rts

* A routine to copy sv_mcsta bits into sx_dspm in case someone poked it!

* a4 -  o- sysvar extension base
* d0-d1 destroyed
ip_dspm
        moveq   #1<<mc..blnk+1<<mc..m256,d1
        move.b  sv_mcsta(a6),d0
        bmi.s   setscr1
        lsr.b   #1,d0
        moveq   #(1<<mc..blnk+1<<mc..m256)>>1,d1
setscr1
        and.b   d1,d0
        not.b   d1
        move.l  sv_chtop(a6),a4 get sysvar extension
        and.b   d1,sx_dspm(a4)
        or.b    d0,sx_dspm(a4)
        rts

        vect4000 ip_kbend,ip_kbrd

        end
