* Pipe device driver - extended for id and long pipes
        xdef    od_pipe,io_serq

        xref    io_relio,io_name,io_qsetl,io_qeof,io_qtest,io_qin,io_qout
        xref    mm_alchp,mm_rechp
        xref    tb_multi,tb_multx
        xref    ut_unlnk

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_q'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'

idlink  equ     sx_pipc-sx_pipb should do this more properly!

* The old style pipes, which are a pain to link up, are handled by:
*       pipe{_{<length>}}{k}
* where length is present and non-zero to open a pipe for output, with the
* optional "k" to allow long pipes as an enhacement. If the length is not
* given or is zero, the channel opened is an input pipe, and d3 at the open
* call must give the channel id number of the already opened output channel.

* The new pipes have one or two non-zero ids as in:
*       pipe<id1>{x|p|t}<id2>{_{<length>}}{k}
* Unlike the old pipes, any number of channels may be opened to the same pipe.
* The first channel must give a positive length for the pipe. The length is
* ignored on any subsequent opens.
* d3=io.dir at the open call is rejected, but the other normal values all open
* channels which may be used for input and/or output.
* If the "x", "p" or "t" flag is omitted, only one id can be given, and this
* becomes both input and output.
* If any flag is given, both ids may be used, with the first specifying the
* pipe to receive data sent to the channel and the second being the one to
* fetch data from. These may be the same id.
* When all channels that may send data to a pipe have been closed, if the last
* open that included a "p" or "t" flag gave a "t", or neither was ever given,
* the pipe is marked as at end of file and is no longer accessible by the id.
* Any remaining read-only channels continue to read data left in the pipe.
* If a "p" flag is given last, all channels may be closed and the data in the
* pipe will remain, waiting for another open to the id.

* Two additional pipe-like devices are supported:
*       pipep will give the data to allow a copy of multibasic to be execed.
*       pipet is a device that always gives eof on read and discards output.

        offset  hp_end-ch_qend
pp_tag  ds.w    1       flag as -ve for ided queues (ch_tag is always +ve!)
pp_id   ds.w    1       identifier for this queue
        ds.w    3       padding, but always zero
pp_read ds.w    1       count of readers of this queue
pp_perm ds.b    1       msb set if permanent
        ds.b    1       padding, but always zero
pp_write ds.w   1       count of writers to this queue
        assert  0,*

        section od_pipe

od_pipe
        dc.w    io_serq-*
        dc.w    open-*
        dc.w    close-*

pop_exit
        add.l   d4,sp           remove parameters from stack
rts0
        rts

open
        lea     sv_lio(a3),a4   keep driver definition link address
        moveq   #2*5,d4         N.B. this is preserved by io.name (and it's 10)
        sub.l   d4,sp           make room on stack for parameters
        move.l  sp,a3           and point a3 to it

        jsr     io_name(pc)     check device name
        bra.s   pop_exit        not pipe
        bra.s   pop_exit        bad parameters
        bra.s   opn_pipe        ok!
        dc.w    4,'PIPE',5,-1,0,3,'XTP',-1,0,' _',0,1,'K'

* d0 -i o- io key / error flag
* d1 -i o- IOSS
* d2 -i o- IOSS
* d3 -i  - IOSS
* a0 -ip - pointer to channel definition block
* a1 -i o- IOSS
* a2-a3 destroyed

io_serq
        lea     ch_qin(a0),a2   get address of input queue
        move.l  d0,a3           save I/O command
        subq.b  #io.fstrg,d0    is operation simple input?
        bls.s   test_q          yes - that's OK
        sub.b   #fs.headr-io.fstrg,d0
        subq.b  #fs.load-fs.headr,d0
        bls.s   test_q          fine - fs op is input
        addq.l  #ch_qout-ch_qin,a2 get address of output queue
test_q
        move.l  (a2),a2         point to queue
        move.l  a2,d0           does queue exist (address non zero)
        exg     a3,d0           restore command
        beq.s   err_bp          oops - no queue indeed

        jsr     io_relio(pc)    simple serial io with relative pointers
        dc.w    io_qtest-*
        dc.w    io_qout-*
        dc.w    io_qin-*

opn_pipe
        movem.w (sp)+,d2/d5-d7  grab all the parameters bar last
        mulu    (sp)+,d4        1->10 for length in kilobytes
        asl.l   d4,d7
        moveq   #-4,d4          start with input queue (so as not to zap eof)
        ror.b   #2,d5           put -xpt up in top two bits
        beq.s   old_pipe
        cmp.w   #5,(a0)
        beq.s   special         got one of "pipex", "pipep" or "pipet"
new_pipe
        subq.w  #io.dir,d3
        bcc.s   err_bp
        bsr.s   alhead
        bne.s   rts0
newopen
        tst.w   d2
        beq.s   newnext
        lea     idlink(a4),a2   point to base of linked list of id queues
        bra.s   entry

lookup
        move.l  d1,a2
        cmp.w   pp_id(a2),d2    look for matching id
        beq.s   gotit
entry
        move.l  (a2),d1
        bne.s   lookup
        tst.l   d7
        ble.s   err_bp          must have a proper length now
        move.l  a2,a1           save link pointer
        move.l  a0,a5           remember our channel
        bsr.s   alqueue         much the same as old output pipe
        move.l  a5,a0           put channel back
        bne.s   newfail
        st      pp_tag(a2)      flag as new queue
        move.l  a2,(a1)         tack onto end of linked list
        move.w  d2,pp_id(a2)    store id
gotit
        move.l  a2,ch_qout(a0,d4.w) store pipe
        addq.w  #1,pp_write(a2,d4.w) increment read/write
        move.b  d5,d1
        bpl.s   newnext
        add.b   d1,d1
        move.b  d1,pp_perm(a2)
newnext
        exg     d2,d6
        addq.w  #4,d4
        beq.s   newopen
        rts

err_bp
        moveq   #err.bp,d0
        rts

alhead
        moveq   #ch_qend,d1     reserve just enough space for channel header
alchp
        jmp     mm_alchp(pc)    allocate space

old_pipe
        move.w  d2,d6           as d5 was not set, d6 must have been zero
        bne.s   new_pipe        default out=in, if id present
        tst.l   d7              check length of pipe
        ble.s   open_in         -ve can happen!, so this is safe!
        bsr.s   alqueue
setqout
        moveq   #0,d4
setqio
        move.l  a2,ch_qout(a0,d4.w) put pointer to queue in definition data
        rts

special
        bsr.s   alqueue         set up queue channel
        bne.s   rts1            give up if no good
        bsr.s   setqio          make it input
        bsr.s   setqout         make it output
        assert  q_eoff,q_nextq,q_end-4,q_nextin-8,q_nxtout-12
        subq.l  #1,(a2)+        mark as at eof immediately, and special
        add.b   d5,d5
        bcc.s   specfail
        bpl.s   rts1            finished if "pipet", the throwaway pipe
        lea     tb_multx+1,a1   point to end of multibasic module, plus one
        move.l  a1,(a2)+        set q_end
        subq.l  #1,a1           point to actual end of module
        move.l  a1,(a2)+        set q_nextin
        lea     tb_multi,a1     point to start of multibasic module
        move.l  a1,(a2)
        sub.l   a2,a2
setqio2
        bra.s   setqio          "pipep" is read-only

alqueue
        moveq   #ch_qend+q_queue+1,d1
        add.l   d7,d1
        bsr.s   alchp
        bne.s   rts1
        lea     ch_qend(a0),a2  set up pointer to queue header
        move.l  d7,d1           pass length of pipe
        addq.l  #1,d1           including the extra byte for wrap effect
        jsr     io_qsetl(pc)    set up queue
        moveq   #0,d0           ensure ccr is z (d0 was already zero)
        rts

specfail
        moveq   #err.bn,d0
newfail
        move.l  d0,d4
        bsr.s   close           drop failed channel
        move.l  d4,d0
rts1
        rts

open_in
        cmp.w   sv_chmax(a6),d3
        bhi.s   err_bp          don't wander off end of channel table!
        lsl.w   #2,d3           fetch id
        move.l  sv_chbas(a6),a2 base of channel table
        move.l  0(a2,d3.w),a2   pick up link channel
        move.l  a2,d1           is it ok?
        bmi.s   err_bp          no good, it's closed!
        cmp.l   ch_drivr(a2),a4 is this the same driver?
err_bpne
        bne.s   err_bp          nope - don't think that's a good idea!
        add.w   #ch_qin,a2      find the other queue
        assert  ch_qin,ch_qout-4,ch_qend-8
        tst.l   (a2)+
        bne.s   err_bpne        can't open input to input!
        cmp.l   (a2)+,a2        proper old pipe?
        bne.s   err_bpne        no - complain
        moveq   #err.iu,d0
        tst.l   (a2)            check q_nextq
        bne.s   rts1            ouch! already linked to an input pipe
        bsr.l   alhead
        bne.s   rts1
        move.l  a0,(a2)         cross link the blocks
        bra.s   setqio2

close
        assert  ch_qin,ch_qout-4
        moveq   #-4,d3
        bsr.s   closeque        close input connection
        moveq   #0,d3
        bsr.s   closeque        close output connection
delete
        jmp     mm_rechp(pc)

closeque
        move.l  ch_qout(a0,d3.w),d0 get queue pointer (qout, then qin)
        beq.s   rts1
        move.l  d0,a2
        moveq   #-1,d1          special queue marker
        cmp.l   (a2),d1
        beq.s   rts1            no special handling needed for special queues
        tst.b   pp_tag(a2)
        bmi.s   closrdwr        go handle new id pipes
        move.l  d3,d0
        bne.s   close_in        note d0=0 if we stay here
        tst.l   (a2)            is output connected at the other end?
        beq.s   rts1            no - we will delete it
        addq.l  #4,sp           discard return, as we will keep the pipe
qeof
        jmp     io_qeof(pc)     mark as at end of file

closrdwr
        assert  pp_read,pp_perm-2,pp_write-4
        subq.l  #1,pp_write-2(a2,d3.w) dec read/write count
        tst.l   pp_perm(a2)     permanent or any writers?
rtsne
        bne.s   rts1            yes - return, as we must keep this going
        lea     sv_lio+idlink(a3),a1 point at base of our linked list
        exg     a2,a0
        jsr     ut_unlnk(pc)    unlink from our list (if it's still there!)
        exg     a2,a0
        bsr.s   qeof            mark as at end of file
        tst.w   pp_read(a2)     any readers left?
        bne.s   rtsne           yes, so all done for the moment
delque
        move.l  a0,a1
        lea     -ch_qend(a2),a0
        bsr.s   delete
        move.l  a1,a0
        rts

close_in
        tst.b   (a2)
        bmi.s   delque          if eof is set, delete the old output channel
        clr.l   (a2)            remove pointer to this block
        rts    

        end
