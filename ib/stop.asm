* Deal with things that stop basic program execution
        xdef    ib_stop,ib_clvv

        xref    ib_unret,ib_npass,ib_error,ib_pserr,ib_whzap
        xref    bp_lszap
        xref    bv_clear,bv_names,bv_vtype

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_choff'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_rt'
        include 'dev7_m_inc_stop'
        include 'dev7_m_inc_vect4000'

        section ib_stop

stop_tab macro
stop_tab
i setnum 0
l maclab
i setnum [i]+1
 assert s.[.parm([i])] [i]*2-2
 dc.w   s_[.parm([i])]-ib_stop
 ifnum [i] < [.nparms] goto l
 endm
 stop_tab clear new stop run lrun load mrun merge retry outm

* Use stop number to do real work for commands which stop program execution.

ib_stop
        move.w  bv_stopn(a6),d1 read the stop number
        move.w  stop_tab(pc,d1.w),d1 get the offset to go to
        jmp     ib_stop(pc,d1.w) and go to it

s_outm
        jsr     ib_error(pc)    write the 'out of memory' message then clear
        move.l  bv_rtp(a6),a0   get top of return stack
        sf      bv_auto(a6)
nx_rt
        cmp.l   bv_rtbas(a6),a0 bottom of return stack yet ?
        ble.s   clear_1
        move.b  -rt.rsrtt(a6,a0.l),d0 look at type
        beq.s   gsub            GOSUB
        assert  rt.rsba,rt.rstl+8
        movem.l -rt.rsba(a6,a0.l),d0-d2 offset of base of args and top locals
        sub.l   d0,d2           this is how many there are
        add.l   bv_ntbas(a6),d0 plus base of table
        bra.s   rt_ent

rt_loop
        clr.l   0(a6,d0.l)      wipe the entry as spare
        addq.l  #8,d0
rt_ent
        subq.l  #8,d2
        bcc.s   rt_loop
        sub.w   #rt.lenpr,a0
gsub
        subq.l  #rt.lentl-rt.lenpr,a0
        bra.s   nx_rt

nt_clear
        clr.l   0(a6,a2.l)      hopefully, we might be able to reuse this entry
*       clr.l   4(a6,a2.l)      no need to clear VV pointer
nt_next
        addq.l  #8,a2           move to next row
nt_ent
        cmp.l   bv_ntp(a6),a2   finished?
        beq.s   nt_done
nt_loop
        move.b  0(a6,a2.l),d0   what type is this name?
        subq.b  #t.mcp,d0
        bcc.s   nt_keep         always keep m/c proc/fn
        addq.b  #t.mcp-t.intern,d0
        beq.s   nt_clear        always discard internal
        tst.w   2(a6,a2.l)      look at namelist offset
        ble.s   nt_clear        if not +ve, then this is not required
* N.B. We know that "PRINT" is the name with NL offset 0, and it's an m/c proc
* Also, we'll drop basic PROC/FN's, as npass will reset them properly later
        jsr     bv_vtype(pc)    make it unset with proper type
        moveq   #-1,d0
        move.l  d0,4(a6,a2.l)   set no value
nt_keep
        move.l  a2,a0           remember the highest active NT entry
        bra.s   nt_next

s_clear
        bsr.s   qunrv2
clear_1
        bsr.s   ib_clvv         clear variables and reset data
        jsr     bv_clear(pc)    return RT and VV space to system
        st      bv_edit(a6)     force an npass after this
        move.l  bv_ntbas(a6),a2 start at bottom of name table
        bra.s   nt_ent

nt_done
        addq.l  #8,a0
        move.l  a0,bv_ntp(a6)   keep just the last active NT entry
s_run
        move.w  bv_nxlin(a6),-(sp) just for DEF as last line of file!
        move.w  bv_stopn(a6),-(sp)
        moveq   #2+2+2*4,d1     select stack depth
        bsr.s   qunrvl
        move.w  (sp)+,bv_stopn(a6)
        move.w  (sp)+,bv_nxlin(a6)
        jsr     ib_npass(pc)    where to run from already set
        bra.s   end_seq

s_stop
        tst.b   bv_wherr(a6)    are we doing a WHEN?
        sf      bv_wherr(a6)
        bne.s   end_seq         yes, don't change continue status then
        jsr     ib_pserr(pc)    set continuation status but no errmess
        bra.s   ok_rts

qunrv2
        moveq   #2*4,d1         select stack depth
qunrvl
        tst.b   bv_unrvl(a6)    do we need to unravel first?
        beq.s   rts0            no
        jmp     ib_unret(pc)

* A common routine to initialise things hit at least by CLEAR.

* d0 -  o- 0

ib_clvv
        moveq   #1,d0
        assert  bv_dalno,bv_dastm-2,bv_daitm-3
        move.l  d0,bv_dalno(a6) clear data line number & statement, but item=1
        jsr     ib_whzap(pc)    kill when variable handling
        move.l  bv_vvbas(a6),bv_vvp(a6) delete the VV area
        clr.l   bv_vvfre(a6)    drop VV free list
        move.l  bv_rtbas(a6),bv_rtp(a6) delete the return stack
        moveq   #bv_btp-bv_ribas,d0
ri_set
        move.l  bv_ribas(a6),bv_ribas(a6,d0.w) delete RI, TG and BT stacks
        addq.l  #4,d0           move up to next pointer
        bne.s   ri_set          until change in direction
        sf      bv_unrvl(a6)    no unravel now
rts0
        rts

s_mrun
s_merge
        bsr.s   qunrv2
end_seq
        move.b  bv_sing(a6),bv_comln(a6) save on return if single line
ok_rts
        moveq   #0,d0
        rts

ib_new
s_lrun
s_load
s_new
* N.B. Qload,Qlrun search from $a000 for next two instns to find this entry 
        move.l  bv_chp(a6),a3
        move.l  bv_chbas(a6),a2
        add.w   #ch.lench*3,a2  channels 0, 1 and 2
        moveq   #bv_lnp-bv_chp,d0 kill off LN/RT as well
chzap
        move.l  a2,bv_chp(a6,d0.w)
        subq.w  #4,d0
        bcc.s   chzap
        bra.s   ch_next

s_retry
*       clr.w   bv_stopn(a6)    set to zero for return  $$$ why ? $$$
        move.w  bv_cnlno(a6),bv_nxlin(a6) copy line number to continue after
        move.b  bv_cnstm(a6),bv_nxstm(a6) copy statement to continue after
        move.w  #-1,bv_cnlno(a6) and reset the continue linum for next time
        move.b  bv_cninl(a6),bv_inlin(a6) copy old inline flag
        move.w  bv_cnind(a6),bv_index(a6) copy old index variable
retry_1
        sf      bv_comln(a6)    don't save
        bra.s   ok_rts

ch_loop
        move.l  0(a6,a2.l),d0   read channel id
        blt.s   ch_add          it's closed already
        move.l  d0,a0
        moveq   #io.close,d0
        trap    #2              close it
ch_add
        add.w   #ch.lench,a2    move to next channel block
ch_next
        cmp.l   a3,a2           any channels left?
        blt.s   ch_loop

        moveq   #-1,d1
        moveq   #-1,d2
        moveq   #mt.dmode,d0    find the current display mode
        trap    #1
        moveq   #mt.dmode,d0    and reset it to clear attributes
        trap    #1
        jsr     bp_lszap(pc)    wipe out list info
        bsr.l   ib_clvv         clear the VV table and reset data
        tas     d0              set d0.l to 128, minimal BF size
        add.l   (a6),d0
        moveq   #bv_pfp,d1
zappf
        move.l  d0,0(a6,d1.w)   zap TK and PF
        subq.w  #4,d1
        bne.s   zappf

        jsr     bv_names(pc)    clear all but mcprocs, mcfns
        bra.s   retry_1         never do rest of command line (names gone)

        vect4000 ib_new

        end
