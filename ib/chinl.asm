* Check for an in-line clause
        xdef    ib_chinl

        xref    ib_eos,ib_s2non

        section ib_chinl

* a4 -ip - position in program file
* d0 -  o- inline (0) or not (-ve)
* d1 destroyed

ib_chinl
        move.l  a4,-(sp)        save what we're going back with
        jsr     ib_eos(pc)      get end of current statement
test
        tst.b   d0              are we at line feed?
        blt.s   popret          -lf, not an i/l clause then
        jsr     ib_s2non(pc)    skip col/then/else and get next non-space
        move.l  a4,d1           save this position
        jsr     ib_eos(pc)      and get the end of the statement
        cmp.l   a4,d1           (-lf), was the statement empty?
        beq.s   test            no, therefore this is an i/l clause
        moveq   #0,d0           set yes flag
popret
        move.l  (sp)+,a4        restore the register
        rts

        end
