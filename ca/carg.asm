* Clear out all the fn/proc arguments
        xdef    ca_carg,ca_frvar

        xref    bv_frvv
        xref    ib_frdes,ib_frdim

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_lpoff'
        include 'dev7_m_inc_nt'

        section ca_carg

* Frees the VV space allocated to a simple, repeat or for variable
* local arrays must be freed here too.
* Non-local arrays also come here when redimensioning
* Anything else is an error.

* d0 -  o- error return (ccr set)
* a2 -ip - NT entry of variable to free
* d1/a0 destroyed

f_misc
        assert  2<<(t.rep-t.arr),(lp.lnrep+7)&$fff8
        assert  2<<(t.for-t.arr),(lp.lnfor+7)&$fff8
        ror.b   d0,d1
        assert  0,(t.arr-t.rep)&2,(t.arr-t.for)&2
        lsr.b   #2,d0
        bcc.s   f_this
        moveq   #err.bn,d0
        bra.s   f_error

reglist reg     d2/d4/d6/a1-a3
ca_frvar
        movem.l reglist,-(sp)
        move.l  4(a6,a2.l),d4
        blt.s   f_end           ..nothing to free
        move.b  1(a6,a2.l),d6   for simple/freedim
        moveq   #2,d1           int/fp, note bv_frvv rounds up to mult of 8
        moveq   #t.arr,d0
        sub.b   0(a6,a2.l),d0   what sort of name is this?
        lea     ib_frdim(pc),a3
        beq.s   f_this
        lea     bv_frvv(pc),a3
        move.l  bv_vvbas(a6),a0
        add.l   d4,a0           position of var to free
        blt.s   f_misc
        subq.b  #t.fp,d6
        bge.s   f_this          free a floating point or integer
        add.w   0(a6,a0.l),d1   add string length (bv_frvv rounds up odd len)
f_this
        moveq   #-1,d0
        move.l  d0,4(a6,a2.l)   as we're freeing it, cancel pointer
        jsr     (a3)            do appropriate free
f_end
        moveq   #0,d0
f_error
        movem.l (sp)+,reglist
        rts

* Clear all proc/fn args
* d0 -ip - error code (ccr set)
* d2 -  o- copy of d0
* a3 -ip - base of args to be cleared from NT
* a5 -i o- top of args to be cleared on NT, returned = a3.l
* d1/a2 destroyed

ca_carg
        move.l  a0,-(sp)        save a0
        move.l  d0,d2           save possible error code
        cmp.l   bv_ntp(a6),a5   are args at very top of name table?
        bne.s   tst_arg
        move.l  a3,bv_ntp(a6)   yes, reset name table running pointer
        bra.s   tst_arg

done
        move.l  (sp)+,a0        restore a0
        move.l  d2,d0           duplicate any input error, and set ccr
        rts

tmp_arg
        move.l  a5,a2
        bsr.s   ca_frvar        free temp arg value
clr_arg
        clr.w   0(a6,a5.l)      wipe out usage/type entry
tst_arg
        cmp.l   a3,a5
        ble.s   done
        subq.l  #8,a5
        and.w   #$ff0f,0(a6,a5.l) strip off the separator nibble
        beq.s   tst_arg         forget it if the usage/type is now zero (null)
        move.w  2(a6,a5.l),d1   is this arg temporary?
        bmi.s   tmp_arg         yes, go free the value
        move.l  4(a6,a5.l),a2   pick up any VV ptr
        moveq   #-1,d0
        move.l  d0,4(a6,a5.l)   wipe out the VV ptr
        move.w  d0,2(a6,a5.l)   wipe out the "other entry" pointer
        move.b  0(a6,a5.l),d0   what have we come back with?
        cmp.b   #t.intern,d0    what have we come back with?
        ble.s   clr_arg         unset or internal, clear entry

        ext.l   d1
        lsl.l   #3,d1
        add.l   bv_ntbas(a6),d1 copy of another entry, find the other one

        cmp.b   #t.arr,0(a6,d1.l) is the original arg an array?
        beq.s   old_arr
        move.b  d0,0(a6,d1.l)   copy usage (only nec for set but doesn't harm)
        move.l  a2,4(a6,d1.l)   copy where new VV is
        bra.s   clr_arg

old_arr
        subq.b  #t.arr,d0       is the return arg still an array?
        bne.s   clr_arg         variable, just clear it
        add.l   bv_vvbas(a6),a2 point at the redundant array descriptor
        jsr     ib_frdes(pc)    free the copy descriptor
        bra.s   clr_arg         and clear the argument

        end
