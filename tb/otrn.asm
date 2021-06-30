* Standard output translation routine
        xdef    tb_otrn

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_vect'

        section tb_otrn

* sx_otrn: output translation routine:
* d1 -i o- byte after cr/lf/cz action / byte to be parity processed
* a0 -ip - base of serial channel definition
* a2 -i  - base of serial output queue
* d0/d2-d3/a1/a3 destroyed.

* If the value in d1 is not to be sent, an appropriate value should be set in
* d0 (err.nc normally) and the return address skipped.
* A one-to-many translation must verify that the queue has space, by calling
* io_qtest through the vector at $de, and if there is insufficient space,
* set err.nc in d0 and skip the return address.
* If the space is ok, the return address should be "jsr"ed to for all but the
* last byte, leaving that to go as normal.
* Only one-to-none, one-to-one and one-to-many conversions are convenient.

* If the return address mentioned above is used, it requires the following:
* d0 -  o- 0 (or error - queue full (err.nc) - should never happen!)
* d1 -i o- byte to put in queue (output with parity actioned)
* a2 -ip - pointer to queue
* d2/a3 destroyed

tb_otrn
        move.l  sv_trtab(a6),a1 get translation table
        move.w  2(a1),d2
        beq.s   rts0            no table, so get out
        add.w   d2,a1

        moveq   #0,d3
        move.b  d1,d3           save d1, and ensure offset is a byte
        beq.s   rts0            send nul directly
        move.b  0(a1,d3.w),d1   get the table entry
        bne.s   rts0            if trans_tab(char) <> 0, send it

        move.l  sv_trtab(a6),a1 get sequence table
        move.w  4(a1),d2
        beq.s   ok_fin          no sequence table, so drop it
        add.w   d2,a1

        move.w  io.qtest,a3
        jsr     (a3)            check space in queue
        moveq   #err.nc,d0      ready to tell caller we can't do this yet
        subq.w  #3,d2           is there room in queue
        bcs.s   drop            no, go back with error

        move.b  (a1)+,d0        get count (no of sequences)
        bra.s   lent

loop
        addq.l  #3,a1           push on pointer
        subq.b  #1,d0           decrement count
lent
        beq.s   ok_fin          while count # 0
        cmp.b   (a1)+,d3        if char <> table entry
        bne.s   loop            then continue loop

        moveq   #3-1,d3
send_3
        move.b  (a1)+,d1        get a byte
        move.l  (sp),a3
        jsr     (a3)            call return address
        dbra    d3,send_3
ok_fin
        moveq   #0,d0
drop
        addq.l  #4,sp           discard return address
rts0
        rts

        end
