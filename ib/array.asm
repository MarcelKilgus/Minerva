* Deal with array assignment
        xdef    ib_array

        xref    bp_alvv,bp_let
        xref    bv_chnt
        xref    ca_eval,ca_indx
        xref    ib_frdes,ib_nxnon

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ib_array

* d0 -  o- error code (with ccr set)
* d4 -i  - name number
* a2 -i  - name table entry
* a4 -i o- tokenised buffer (token after name on input)
* d1-d3/a0-a1/a3 destroyed

err_bn
        moveq   #err.bn,d0
        rts

ib_array
        and.b   #15,1(a6,a2.l)  mask any separator
        tst.b   4(a6,a2.l)      check that array has been dimensioned
        bmi.s   err_bn
        jsr     bv_chnt(pc)     need a new nt entry
        move.l  bv_ntp(a6),a3   keep copy in a3
        addq.l  #8,bv_ntp(a6)

        move.w  0(a6,a2.l),0(a6,a3.l) copy nt,vt
        move.w  d4,2(a6,a3.l)   point at original nt entry

        move.l  4(a6,a2.l),a2   offset of array descriptor
        add.l   bv_vvbas(a6),a2 point to it
        moveq   #(4+2+2)>>2,d1  we know that alloc will round to mult of 8
        add.w   4(a6,a2.l),d1   add number of dimensions
        lsl.l   #2,d1           x 4 bytes each
        jsr     bp_alvv(pc)     allocate space for a copy and fill pntr in
copy_des
        move.l  0(a6,a2.l),0(a6,a0.l) copy descriptor by longwords
        addq.l  #4,a2
        addq.l  #4,a0
        subq.w  #4,d1
        bgt.s   copy_des

new_ind
        jsr     ib_nxnon(pc)    get next symbol
        sub.w   #w.equal,d1     is it an equals sign?
        beq.s   chk_ind         yes, make sure it's valid
        moveq   #err.xp,d0
        subq.w  #w.opar-w.equal,d1 is it an opening parenthesis?
        bne.s   clr_copy        no, nothing else allowed

        addq.l  #2,a4           skip bracket
        move.l  a4,a0           for ca_indx
        lea     8(a3),a5        ditto
        jsr     ca_indx(pc)     compress the array descriptor
        lea     -8(a5),a3
        move.l  a0,a4
        beq.s   new_ind         what's next ?
        bra.s   clr_copy

chk_ind
        addq.l  #2,a4           skip the equals sign
        cmp.b   #t.var,0(a6,a3.l) has array compressed to a single value?
        beq.s   let             yes, good
        moveq   #err.ni,d0
        cmp.b   #t.str,1(a6,a3.l) no, is it a (sub)string then?
        bgt.s   clr_copy        no, can't do it yet
        move.l  4(a6,a3.l),a2
        add.l   bv_vvbas(a6),a2
        cmp.w   #1,4(a6,a2.l)   only the one dimension i trust?
        bgt.s   clr_copy        sigh
let
        move.b  1(a6,a3.l),d0   type we want it to be
        sub.l   bv_ntbas(a6),a3
        move.l  a3,-(sp)
        move.l  a4,a0           start of expression to evaluate
        jsr     ca_eval(pc)
        move.l  a0,a4
        move.l  (sp)+,a3
        add.l   bv_ntbas(a6),a3
        ble.s   clr_copy
        jsr     bp_let(pc)
clr_copy
        cmp.b   #t.arr,0(a6,a3.l) is this still an array?
        bne.s   clr_nt          no, no descriptor then
        move.l  4(a6,a3.l),a2   free the descriptor
        add.l   bv_vvbas(a6),a2
        jsr     ib_frdes(pc)    preserves d0 these days!
clr_nt
        clr.l   0(a6,a3.l)      clear the nt copy
        addq.l  #8,a3
        cmp.l   bv_ntp(a6),a3   is this copy on top of the name table?
        bne.s   tst_d0
        subq.l  #8,bv_ntp(a6)   yes, move down
tst_d0
        tst.l   d0
        rts

        end
