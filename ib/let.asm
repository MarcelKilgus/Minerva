* Assigns expression value on rhs of assignment op to simple variable on lhs
        xdef    ib_let

        xref    bp_let,bp_rdchk
        xref    ca_eval,ca_ssind
        xref    ib_fname,ib_nxnon,ib_wtest

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ib_let

* d0 -  o- return code
* d1 -i  - first word of next token
* d4 -i  - name table index
* a2 -i  - name table entry
* a4 -i o- pf pointer (start at token after name)
* d2-d3/d5-d6/a0-a1/a3 destroyed

ib_let
        move.l  a2,a3
        and.b   #15,1(a6,a3.l)  mask out any separator which may have crept in
        jsr     bp_rdchk(pc)    can we assign to this ?
        bne.s   rts0            ..no
        clr.w   d5              set flag for normal variable type
        move.b  1(a6,a3.l),d0   get type
        cmp.w   #w.opar,d1      got an ( ?
        bne.s   eval            ..no

        subq.b  #t.str,d0       must be a string
        bne.s   err_bn
        tst.b   4(a6,a3.l)      must already have a value
        bmi.s   err_bn

        lea     2(a4),a0
        jsr     ca_ssind(pc)    read the substring indices
        move.l  a0,a4
        bne.s   rts0
        tst.w   d5
        ble.s   err_or          can't assign to string length word
        jsr     ib_nxnon(pc)
        moveq   #t.str,d0       set type string required
eval
        cmp.w   #w.equal,d1     followed by equals
        bne.s   err_bn
        lea     2(a4),a0        start of expression to evaluate
        jsr     ca_eval(pc)
        move.l  a0,a4
        ble.s   err_ev
        jsr     ib_fname(pc)    make nt pointer again from d4 index
        move.l  a2,a3
        subq.w  #1,d5           did we get substring indices?
        bcs.s   normal          nope - that's a go
        move.l  4(a6,a3.l),a2   get offset
        add.l   bv_vvbas(a6),a2 base of string
        move.w  0(a6,a2.l),d0   get its length
        cmp.w   d0,d6           are we falling off the end?
        ble.s   notrunc         nope, that's fine
        move.w  d0,d6           yes, trim it down
notrunc
        cmp.w   d5,d6           where are we starting?
        blt.s   err_or          no good if beyond last char+1
        addq.w  #1,d5           put d5 back as standard start index
        sf      1(a6,a3.l)      set substring type for bp_let to sort out
normal
        jsr     bp_let(pc)      do the assignment
        bne.s   rts0            did it work?
        tst.w   bv_wvnum(a6)    any when variables?
        beq.s   rts0            no - return now
        jmp     ib_wtest(pc)    yes - go check it out

err_bn
        moveq   #err.bn,d0      must be mistyped
rts0
        rts

err_or
        moveq   #err.or,d0
        rts

err_ev
        blt.s   rts0
        moveq   #err.xp,d0      null
        rts

        end
