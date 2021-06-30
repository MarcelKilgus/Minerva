* Deal with machine code procedure
        xdef    ib_proc

        xref    ca_carg,ca_garg
        xref    ib_cheos,ib_unret

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'

        section ib_proc

* d0 -  o- error code
* d2 -  o- error code
* a1 -  o- bv_rip
* a2 -i  - name table entry
* a4 -i o- program pointer to next token after proc name, updated to eos
* d1/d3-d6/a0/a3/a5 destroyed

ib_proc
        move.l  4(a6,a2.l),d5   just want absolute address of procedure
nextgo
        sf      bv_undo(a6)     turn undo off
        move.l  a4,a0           put prog pointer in a0
        assert  bv_ntbas,bv_ntp-4
        movem.l bv_ntbas(a6),d6/a3
        sub.l   d6,a3           offset of base of args
        sub.l   a4,d6           program pointer offset, in case of redo
        jsr     ca_garg(pc)     get the arguments (only touches d0-d1/a0-a1/a5)
        move.l  bv_ntbas(a6),a4 may have moved
        bne.s   carg            wrong
        jsr     ib_cheos(pc)    check that d1 is an end of statement
        bne.s   err_bp
        sub.l   a4,a5           top of args offset
        sub.l   a4,a0           program offset
        move.l  bv_rip(a6),a1
        sub.l   bv_ribas(a6),a1 ri offset
        movem.l d5-d7/a0-a1/a3/a5,-(sp) don't want to lose our place, do we?
        moveq   #0,d7           absolute guarantee of zero in d7
        add.l   a4,a3
        add.l   a4,a5
        assert  bv_linum,bv_lengt-2
        move.l  bv_linum(a6),-(sp)
        move.b  bv_stmnt(a6),-(sp)
        assert  bv_inlin,bv_sing-1,bv_index-2
        move.l  bv_inlin(a6),-(sp)

        move.l  d5,a2
        jsr     (a2)            do the relevent mc proc

* The stack looks like this to the called code:
*       $00 l return address
*       $04 b bv_inlin
*       $05 b bv_sing
*       $06 w bv_index
*       $08 b bv_stmnt
*       $09 b junk
*       $0a w bv_linum
*       $0c w bv_lengt
*       $0e l (d5) m/c code address, in case of a redo
*       $12 l (d6) prog offset from bv_ntbas, before garg, for redo (positive)
*       $16 l (d7) data register (always zero, wasting space on here!)
*       $1a l (a0) current program offset down from bv_ntbas (negative)
*       $1e l (a1) ri stack offset down from bv_ribas (negative)
*       $22 l (a3-ntbas) offset to top of args up from bv_ntbas
*       $26 l (a5-ntbas) offset to bottom of args up from bv_ntbas
* I have stopped saving d5-d6 in to get space for undo stuff, swapped the
* current prog offset with the ri offset and changed registers on the call.
* Previously, a0 had a copy of nt_bas and a4 was the current prog offset.
* With luck, no one will have expected particular register values, other than
* d0/d7/a3/a5, and no further exploration up the stack!
* N.B. Beware! Qload and Qlrun zero out the two arg ptrs above by referencing
* them as $22(sp) and $26(sp). Qload also expects msw d6 zero!!!! (lwr)

        move.l  (sp)+,bv_inlin(a6)
        move.b  (sp)+,bv_stmnt(a6)
        move.l  (sp)+,bv_linum(a6)
        movem.l (sp)+,d5-d7/a0-a1/a3/a5 now then, where were we?
        add.l   bv_ribas(a6),a1
        move.l  a1,bv_rip(a6)   restore ri pointer
        move.l  bv_ntbas(a6),a4
        add.l   a4,a0           restore position in program
        add.l   a4,a5           top of args on nt
        bsr.s   carg
        tst.b   bv_undo(a6)     um, must we undo the return stack first?
        bne.s   redo            yes, go see to it
        rts

err_bp
        moveq   #err.bp,d0
carg
        sub.l   a4,d6           prog pointer for redo (negated)
        add.l   a4,a3           bottom of args on nt
        move.l  a0,a4           prog pointer back into correct register
        jmp     ca_carg(pc)     clear out the arguments

redo
        neg.l   d6              un-negate saved program pointer
        move.l  d6,a4           put back the saved program pointer
        move.l  a4,-(sp)           \
        move.l  d5,-(sp)            \
        move.l  bv_linum(a6),-(sp)   > save full current context
        move.b  bv_stmnt(a6),-(sp)  /
        move.l  bv_inlin(a6),-(sp) /
        moveq   #7*4+2,d1       tell unret how deep the stack is
        jsr     ib_unret(pc)    go unravel everything
        move.l  (sp)+,bv_inlin(a6)
        move.b  (sp)+,bv_stmnt(a6)
        move.l  (sp)+,bv_linum(a6)
        move.l  (sp)+,d5
        move.l  (sp)+,a4
        bra.l   nextgo

        end
