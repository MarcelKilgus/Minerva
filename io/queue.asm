* Set/test/in/out/eof queues
        xdef    io_qset,io_qsetl,io_qtest,io_qin,io_qout,io_qeof

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_q'
        include 'dev7_m_inc_vect4000'

        assert  0,q_eoff,q_nextq,q_end-4,q_nextin-8,q_nxtout-12,q_queue-16

        section io_queue

* As a general idea, the code here tries to work efficiently when data is being
* accessed in a queue that is partially full. I.e. it should cope with high
* volume traffic of qin/qout calls as its forte.

* Set up a queue

* d1 -ip - length of queue (max. bytes in queue + 1, d1.w = 1..32767, we hope!)
* a2 -ip - pointer to queue
* a3 destroyed

io_qset
        move.l  d1,-(sp)
        ext.l   d1
        bsr.s   io_qsetl
        move.l  (sp)+,d1
        rts

* As above, but d1.l is used to set long queues!

io_qsetl
        lea     q_queue(a2,d1.l),a3 set pointer to end of queue
        clr.l   (a2)+           clear eoff and nextq
        move.l  a3,(a2)+        set end
        sub.l   d1,a3           start the queue in an arbitrary place = bottom
        move.l  a3,(a2)         set nextin
        move.l  a3,-(a3)        and nxtout
        subq.w  #q_nextin,a2    restore queue pointer
        rts

* Test status of a queue

* d0 -  o- error flag - 0, queue empty (nc) or eof
* d1 -  o- next byte in queue (all but d1.b preserved)
* d2 -  o- spare space in queue (bits 31..15 always zero)
* a2 -ip - pointer to queue
* a3 destroyed

io_qtest
        movem.l q_nextin(a2),d2/a3 get pointer to next bytes in/out
        move.b  (a3),d1         show caller next byte
        sub.l   a3,d2           set difference between in and out
        blt.s   set_spar        negative: wrapped, so just complement this
        bgt.s   set_wrap        positive: must take off the wrap length
        bsr.s   set_wrap        zero: queue empty, but we must still set space
say_why
        moveq   #err.ef,d0      end of file
        tst.b   (a2)            is it eof?
        bmi.s   rts0            yep - ccr is ok for that
err_nc
        moveq   #err.nc,d0      not complete
rts0
        rts

set_wrap
        moveq   #-q_queue,d0
        sub.l   a2,d0
        add.l   q_end(a2),d0    this is the overall queue area
        sub.l   d0,d2           so this'll be the free space, when complemented
set_spar
        not.l   d2              zero will mean no spare space in queue
        move.w  #32767,a3       we must return a positive word
        cmp.l   a3,d2
        bls.s   say_ok
        move.l  a3,d2           if the queue is oversize, return a max value
say_ok
        moveq   #0,d0
        rts

* Put bytes into a queue

* d0 -  o- error flag - queue full
* d1 -ip - byte to put in queue (discarded with no error if eof set)
* a2 -ip - pointer to queue
* a3 destroyed

io_qin
        tst.b   (a2)            is it eof? (eoff)
        bmi.s   say_ok          ... yes - throw it away (!!!)
        move.l  q_nextin(a2),a3 get pointer to end of queue
        move.b  d1,(a3)+        put byte regardless (there's alway a gap)
        cmp.l   q_end(a2),a3    is next pointer off end of queue
        blt.s   chk_next
        lea     q_queue(a2),a3  next is start of queue
chk_next
        cmp.l   q_nxtout(a2),a3 is queue full
        beq.s   err_nc
        move.l  a3,q_nextin(a2) save pointer to next in queue
        bra.s   say_ok

* Fetch bytes out of a queue

* d0 -  o- error flag - queue empty, and possibly at eof
* d1 -  o- byte from queue
* a2 -ip - pointer to queue
* a3 destroyed

io_qout
        move.l  q_nxtout(a2),a3 get pointer to next byte
        cmp.l   q_nextin(a2),a3 is there anything in queue
        beq.s   say_why         no - go tell caller nc/eof
        move.b  (a3)+,d1        fetch byte
        cmp.l   q_end(a2),a3    is next pointer off end of queue
        blt.s   save_out
        lea     q_queue(a2),a3  next is start of queue
save_out
        move.l  a3,q_nxtout(a2) save pointer to next in queue
        bra.s   say_ok

* Set end of file on a queue

* a2 -ip - pointer to queue

io_qeof
        tas     (a2)            flag in msbit (eoff)
        rts

        vect4000 io_qsetl

        end
