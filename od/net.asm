* Network driver
        xdef    od_net

        xref    io_name,io_relio
        xref    mm_alchp,mm_rechp
        xref    nd_rpac,nd_spac

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_net'
        include 'dev7_m_inc_sv'

        section od_net

od_net
        dc.w    io-*
        dc.w    open-*
        dc.w    close-*
io
        jsr     io_relio(pc)
        dc.w    pend-*
        dc.w    fbyte-*
        dc.w    sbyte-*

open
        subq.l  #4,sp           make room for parameters
        move.l  sp,a3

        jsr     io_name(pc)     check name
        bra.s   opn_exit        not net
        bra.s   opn_exit        bad parameters
        bra.s   open_net        ok!
        dc.w    3,'NET',2,2,'OI',' _',0 output or input, station 

open_net
        assert  0,net_end&3
        moveq   #(net_end+3)>>2,d1
        lsl.w   #2,d1
        jsr     mm_alchp(pc)    set up channel definition block
        bne.s   opn_exit        ... oops
        move.b  3(sp),net_dest(a0) set destination
        move.b  sv_netnr(a6),net_self(a0) set self
        subq.w  #2,(sp)         out -1 (or -2), in zero
        move.b  1(sp),net_type(a0) set in or out
        moveq   #0,d0
opn_exit
        addq.l  #4,sp           remove parameters
        rts

* Close a network channel
close
        tst.b   net_type(a0)    is it an input or output channel
        bge.s   release         ... input
        move.b  #1,net_type(a0) ... output - set eof
        move.b  net_rpnt(a0),net_nbyt(a0) and number of bytes

tst_mdv
        tst.b   sv_mdrun(a6)    is a microdrive running?
        bne.s   tst_mdv         yes - wait
        move.w  #1400,d4        keep on trying for about 15 seconds
cls_loop
        jsr     nd_spac(pc)     send the packet
        dbeq    d4,cls_loop     and keep trying until gone
release
        jmp     mm_rechp(pc)

get_pak
        sf      net_rpnt(a0)    reset running pointer
        jsr     nd_rpac(pc)     and get next block
        bne.s   exit

pend
        move.b  net_type(a0),d0 type should be read ok (0) or eof (1)
        blt.s   err_bp
        clr.w   d2              set running pointer
        move.b  net_rpnt(a0),d2
        move.b  net_data(a0,d2.w),d1 set next byte
        sub.b   net_nbyt(a0),d2 check pointer against number of bytes
        bcs.s   exit_ok         ... buffer not empty
        tst.b   d0              buffer empty - is it eof?
        beq.s   get_pak         ... no - get a new buffer
        moveq   #err.ef,d0      ... yes - thats it
        rts

err_bp
        moveq   #err.bp,d0
        rts

* Fetch a byte from the network
fbyte
        bsr.s   pend            anything pending?
        bne.s   exit            ... no
        addq.b  #1,net_rpnt(a0) update pointer
exit_ok
        moveq   #0,d0
exit
        rts

* Send a byte to the network
sbyte
        tst.b   net_type(a0)    is it an output?
        bge.s   err_bp          ... oh no it isn't
        moveq   #1,d2           next write to buffer position
        add.b   net_rpnt(a0),d2
        bcc.s   write           is in the buffer
        move.b  d1,-(sp)
        assert  net_type,net_nbyt-1
        move.w  #$00ff,net_type(a0) set type and number of bytes
        jsr     nd_spac(pc)     send packet
        move.b  (sp)+,d1
        st      net_type(a0)    restore type to write
        tst.l   d0              did it go?
        bne.s   exit
        moveq   #1,d2           set next byte pointer
write
        move.b  d1,net_data-1(a0,d2.w) set this byte
        move.b  d2,net_rpnt(a0) and pointer to next
        bra.s   exit_ok

        end
