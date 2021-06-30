* Get all the args for a fn/procedure
        xdef    ca_chkvv,ca_garg

        xref    bv_alvv
        xref    ca_expr,ca_newnt
        xref    mm_mrtor

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ca_garg

* Gets space in VV area and puts its VV offset into a name table entry.
* d0 -  o- 0
* d1 -ip - amount of room needed in VV heap
* d2 -  o- VV offset
* a1 -  o- RI stack
* a2 -  o- where to put value relative to a6
* a5 -ip - pointer above name table entry to be set 

ca_chkvv
        exg     a0,a2
        jsr     bv_alvv(pc)     also restores ri stack pointer
        exg     a0,a2
        move.l  a2,d2
        sub.l   bv_vvbas(a6),d2
        move.l  d2,-4(a6,a5.l)  store VV offset in name table
        rts

* d0 -  o- error code
* d1 -  o- next token type and number
* a0 -i o- pointer to first of list of parameters to evaluate
* a1 -  o- arithmetic stack pointer
* a5 -  o- top of name table

reglist reg     d2-d4/a2-a4

big.n   equ     361     break even string length to go for fast copy
* The break even point at which to go over to the fast copy routine was
* established by extensive testing... it may change if the fast copy is
* enhanced at all. It's a strangely elusive value to come by!

arg_str
        add.w   0(a6,a1.l),d1   get string length + 2 (msw is zero)
        bsr.s   ca_chkvv        get space to use
        addq.w  #1,d1           add one to round
        bclr    d0,d1           round to even value
        cmp.w   #big.n+3,d1     is this a rather long string?
        bls.s   arg_move        no - go do a local move
        exg     a2,a0           want destination in a0
        jsr     mm_mrtor(pc)    do a fast copy
        move.l  a2,a0
        bra.s   arg_add

arg_move
        move.l  0(a6,a1.l),0(a6,a2.l)
        move.l  4(a6,a1.l),4(a6,a2.l) copy 8 bytes off RI stack into VV slot
        addq.l  #8,a1
        addq.l  #8,a2
        subq.l  #8,d1           is that the lot?
        bgt.s   arg_move        no - keep trucking
        bra.s   arg_add

ca_garg
        movem.l reglist,-(sp)
        sf      d4              initialise # flag to non-hash
        bra.s   get_arg

arg_chk
        and.b   #15,-7(a6,a5.l) don't want any seps yet
        cmp.b   #t.intern,-8(a6,a5.l) check msb of variable type
        bne.s   arg_ok          not internal, so already set up

* An internal value is removed from the top of the arithmetic stack, copied
* into the variable values area and made to be a simple variable with no name.

        moveq   #t.fp,d1        (n.b. also set d1=2 for 2-byte integer)
        cmp.b   -7(a6,a5.l),d1  string, fp or integer?
        blt.s   arg_copy        ready for integer
        bne.s   arg_str         go do a string
        moveq   #6,d1           d1=6 for 6-byte fp
arg_copy
        bsr.s   ca_chkvv        get space to use (always multiple of eight)
        move.l  2(a6,a1.l),2(a6,a2.l) copy mantissa (irrelevant if int)
        move.w  0(a6,a1.l),0(a6,a2.l) copy exponnent or integer
arg_add
        add.l   d1,a1           adjust RI stack pointer
        move.l  a1,bv_rip(a6)   save it
        addq.b  #t.var-t.intern,-8(a6,a5.l) turn into a simple variable
        move.w  #-1,-6(a6,a5.l) make certain it has no name
arg_ok
        or.b    d4,-7(a6,a5.l)  put any hash flag into the variable type byte
        sf      d4              clear the hash flag
        move.w  0(a6,a0.l),d1   put token type plus which token in d1
        cmp.b   #b.sep,0(a6,a0.l) separator next?
        bne.s   end_arg         no
        lsl.b   #4,d1           move it up to top half of byte
        or.b    d1,-7(a6,a5.l)  put it into the variable type byte
nxt_arg
        addq.l  #2,a0           step past hash or separator
get_arg
        jsr     ca_expr(pc)     evaluate expression
        bgt.s   arg_chk         genuine argument
        bmi.s   exit            wrong
        cmp.b   #b.sep,0(a6,a0.l) is next token a separator?
        bne.s   try_hash        no - go see if it's a hash sign
        jsr     ca_newnt(pc)    yes - build a new (null) name table entry
        bra.s   arg_ok

try_hash
        tas     d4              if hash, can't do anything yet, set flag
        move.w  0(a6,a0.l),d1   put token type plus which token in d1
        cmp.w   #w.hash,d1      well, is it a hash sign then?
        beq.s   nxt_arg         yes, go get the argument itself
end_arg
        moveq   #0,d0           (actually already zero, but must get ccr right)
exit
        movem.l (sp)+,reglist
        rts

        end
