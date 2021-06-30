* Default input translation
        xdef    tb_itrn

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'

        section tb_itrn

* sx_itrn: input translation routine:
* d1 -i o- byte after parity action / byte to be cr/lf/cz processed
* a0 -ip - base of serial channel definition
* a2 -i  - base of serial input queue
* d0/d2-d3/a1/a3 destroyed.

* d1 should be used to supply bytes to the caller.
* Skipping the return address and setting d0 to err.nc will cause the input
* byte to be discarded. (d1 may be destroyed).
* Only one-to-none and one-to-one conversions are convenient.

tb_itrn
        move.l  sv_trtab(a6),a1 get translation table
        move.w  2(a1),d2
        beq.s   rts0            no table, so get out
        add.w   d2,a1
        moveq   #0,d2
        move.b  d1,d2           ensure offset is a byte
        tst.b   0(a1,d2.w)      look at table entry
        bne.s   lent            if not zero, enter loop
rts0
        rts

loop
        addq.b  #1,d2           push on
        cmp.b   d2,d1           back at start?
        beq.s   rts0            yes, so get out
lent
        cmp.b   0(a1,d2.w),d1   check table entry
        bne.s   loop            not equal, so carry on
        move.b  d2,d1           found it, pointer is actual value
        rts
 
        end
