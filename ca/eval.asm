* Expression evaluator
        xdef    ca_eval,ca_evalc,ca_evali,ca_expr,ca_newnt,ca_oldnt

        xref    bv_chnt,bv_chrix,bv_chss
        xref    ca_chkvv,ca_cnvrt,ca_etos,ca_fun,ca_indx,ca_opexe,ca_putss
        xref    ca_stind,ca_undo

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'
        include 'dev7_m_inc_vect4000'

mon.off equ     $16     offset on table of mono-operators

        section ca_eval

* Unravel NT from current position to initial position

unrloop
        jsr     ca_undo(pc)
unravel
        cmp.l   d2,a5           finished yet?
        bne.s   unrloop
        subq.l  #2,sp
        bra.s   setntp

* Evaluate expression to push result of required type on RI stack

* d0 -i o- required type (ca_eval only) / -ve error, 0=null or 8=val, ccr set
* a0 -i o- pointer to expression to be evaluated
* a1 -  o- pointer to arithmetic stack
* a5 -  o- pointer to name table
* d1-d3/a3-a4 destroyed

ca_evali
        moveq   #t.int,d0       evaluate an integer
        bra.s   ca_eval

ca_evalc
        moveq   #t.log,d0       evaluate a t/f condition (integer)
ca_eval
        move.b  d0,-(sp)
        bsr.s   ca_expr         evaluate expression
        ble.s   ev_exit         error or null
        jsr     ca_etos(pc)     now evaluate top of stack
        bne.s   ev_exit         error or null
        move.b  (sp),d0         good
        bne.s   convert
        moveq   #t.str,d0
convert
        jsr     ca_cnvrt(pc)    convert to type required if necessary
        subq.l  #8,a5           remove type etc. from name table
setntp
        move.l  a5,bv_ntp(a6)
        tst.l   d0
        bne.s   ev_exit
        addq.l  #8,d0
ev_exit
        addq.l  #2,sp
        rts

* Evaluates an expression pushing result as top of name table.

* d0 -  o- error code, 0 no expression (null) or 8 result pushed (ccr set)
* a0 -i o- pointer to expression to be evaluated
* a1 -  o- pointer to RI stack
* a5 -  o- pointer to name table
* d1-d3/a3-a4 destroyed

* Locally:
* d4 token value
* d5.b operator precedence and, for open parenthesis, 0=subscript or -1=expr
* a1 maintained as RI pointer, to avoid keep changing it about.

ca_expr
        move.l  bv_ntp(a6),a5
        move.l  a5,a1
        sub.l   bv_ntbas(a6),a1 in case of movement
        movem.l d4-d6/a1,-(sp)  save working registers and NT offset
        jsr     bv_chss(pc)
        move.l  bv_rip(a6),a1   pick up current RI pointer, maintained in a1
        st      d5              mark top of stack
        bra.s   put_op1

indexer
        pea     ind_tkq
        cmp.b   #t.arr,-8(a6,a5.l) it's an index, what sort ?
        beq.l   ca_indx         array index
        jmp     ca_stind(pc)    string index

oparen
        tst.b   d5              what are we expecting?
        bne.s   indexer         not a normal expression
        bsr.s   ca_expr         evaluate expression
        ble.s   err_qq0
        jsr     ca_etos(pc)     now evaluate top of stack
errne
        bne.s   err_qq0
        addq.l  #2,a0
        cmp.w   #w.cpar,-2(a6,a0.l) should have been close parenthesis
        beq.l   ind_tok         if next token wasn't a ) then it's an error
err_qq0
        bra.l   err_qq

* Precedence

pr_tab
        dc.b    5,5             + -     plus/minus, dyadic
        dc.b    6,6             * /     multiply/divide
        dc.b    4,4,4,4,4,4,4   >= > == = <> <= <  relational operators
        dc.b    1,2,1           || && ^^ bitwise or/and/xor
        dc.b    7               ^       raise to the power of
        dc.b    9               &       concatenate
        dc.b    1,2,1           or and xor logical
        dc.b    6,6             mod div interger modulus/divide
        dc.b    8               instr   posn of one string inside another
        dc.b    11,11           - +     minus/plus monadic
        dc.b    3,3             ~~ not  bitwise not logical not
        ds.w    0

* Evaluation loop, executing stacked operations

ev_loop
        move.w  (sp)+,d4        fetch operation
        jsr     ca_opexe(pc)    go execute the operation
        move.l  a1,bv_rip(a6)   a1 is correct, even on error report
        tst.l   d0
ev_tst
        bne.s   errne
        cmp.b   (sp),d5         check priority on stack
        ble.s   ev_loop         if current priority less or equal, do it
put_op
        swap    d4              restore d4 lower half
put_op1
        move.w  d4,-(sp)        put operator on stack
        move.b  d5,(sp)         put priority onto stack
        sf      d5              opening parenthesis = sub-expression, no dyadic
        bne.l   read_tok        carry on if it wasn't zero (end)
        addq.l  #2,sp           lose the end flag off the stack
end_1
        addq.l  #2,sp           remove marker from stack
        bsr.s   popwrk          restore working registers
        move.l  a5,d0
        sub.l   d2,d0           was anything of any interest read?
        rts

op_equ
        addq.b  #b.eq,d4        replace symbol = by operator =
        bra.s   op_now

tok_sym
tok_proc equ    tok_sym-b.equal at least we can have d4 nice for one token
        sub.b   -1(a6,a0.l),d4  check for = as in print (1)=1
        beq.s   op_equ          yes, replace it by the operator
        addq.b  #b.opar-b.equal,d4 check for open parenthesis
        beq.s   oparen          yes, go sort that out
tok_key
tok_sep
        subq.l  #2,a0           we're not going past this token
        sf      d5              evaluate back to start of expression
        tst.b   (sp)            check if any pending operators
        bpl.s   eval_tsb        yes - have to action them
        bra.s   end_1

tok_mon
        moveq   #mon.off,d4     add offset to mono-operator
        add.b   -1(a6,a0.l),d4
        move.b  pr_tab-1(pc,d4.w),d5 set up priority
        bra.s   put_op1

tok_ops
        move.b  -1(a6,a0.l),d4  fetch operator type
op_now
        tst.b   d5              check if expecting an operator
        beq.s   err_xp
        move.b  pr_tab-1(pc,d4.w),d5 set up priority
        swap    d4              save d4 lower half
eval_tsb
        pea     ev_tst
etos
        jmp     ca_etos(pc)     evaluate top of stack

err_qq
        bmi.s   errlp
tok_bip
tok_bif
tok_syv
tok_txt
tok_lno
tok_bad
err_xp
        moveq   #err.xp,d0
errlp
        tst.b   (sp)+           try to find top of stack
        bpl.s   errlp
        pea     unravel         after restoring working (d2 is saved ntp)
popwrk
        movem.l (sp)+,d2/d4-d6/a3 return / working registers / saved ntp offset
        add.l   bv_ntbas(a6),a3 in case of movement
        exg     d2,a3
        jmp     (a3)

tok_shi
        move.b  -1(a6,a0.l),d4
        ext.w   d4
shlgi
        subq.l  #2,a1
        bsr.l   moreri
        move.w  d4,0(a6,a1.l)
        move.w  #t.intern<<8+t.int,d4
setri
        move.l  a1,bv_rip(a6)   store new arithmetic stack pointer
        bsr.l   ca_newnt
        move.w  d4,-8(a6,a5.l)  put in type
ind_tok
        st      d5              operator ok and open parenthesis means index
tok_spc
read_tok
        moveq   #31,d4          note d4 msb's zero
        and.b   0(a6,a0.l),d4   ignore 3 msbit's while fetching token type
        addq.l  #2,a0           we often move past the token...
        move.b  tok_tab(pc,d4.w),d4
        jmp     tok_proc(pc,d4.w) go to code for token

tok_lgi
        addq.l  #2,a0           long integer takes four bytes
        move.w  -2(a6,a0.l),d4
        bra.s   shlgi

tok_str
        move.w  0(a6,a0.l),d1   get length
        addq.l  #2,a0           step over length
        move.l  a0,a4           set source pointer
        add.w   d1,a0           step past chars
        moveq   #1,d2
        and.w   d1,d2
        add.w   d2,a0           round up odd byte
        jsr     ca_putss(pc)    put sub-string on stack
        bsr.l   ca_newnt
        move.w  #t.intern<<8+t.str,-8(a6,a5.l) put in type
        bra.s   ind_tok         we've just read a string, so we allow index

tok_fp
        addq.l  #4,a0           step past rest of fp
        subq.l  #6,a1
        bsr.s   moreri
        movem.w -6(a6,a0.l),d0-d2
        and.w   #$0fff,d0       remove token flag
        movem.w d0-d2,0(a6,a1.l)
        move.w  #t.intern<<8+t.fp,d4
        bra.s   setri

tok_nam
        addq.l  #2,a0           step past name bit
        bsr.s   ca_newnt        create new name table entry
        move.w  -2(a6,a0.l),d4  get name number, ie pos. in name table
        move.l  d4,d0
        lsl.l   #3,d0
        move.l  d0,a3
        add.l   bv_ntbas(a6),a3 name table entry
        move.b  0(a6,a3.l),d0   get name type
        subq.b  #t.bpr,d0       is name type fairly simple?
        bmi.s   dosimp1         yes - go do simple stuff
        asl.b   #6,d0           this checks for rep/for loop index ...
dosimp1
        bmi.s   dosimp          ... this'll do (d4.b = $80 or $c0 now)
        beq.s   err_qq1         ... even gets t.bpr/t.mcpr sorted
        scs     d0              d0.b = 0 for basic or $ff for m/c
        jsr     ca_fun(pc)      go call the function
* I trust that this leave a1/bv_rip(a6) correct. (M/c definate, deffn?)
ind_tkq
        beq.s   ind_tok         if ok, get the next token
err_qq1
        bra.l   err_qq          failed

tok_tab
        dc.b    tok_spc-tok_proc
        dc.b    tok_key-tok_proc
        dc.b    tok_bip-tok_proc
        dc.b    tok_bif-tok_proc
        dc.b    tok_sym-tok_proc
        dc.b    tok_ops-tok_proc
        dc.b    tok_mon-tok_proc
        dc.b    tok_syv-tok_proc
        dc.b    tok_nam-tok_proc
        dc.b    tok_shi-tok_proc
        dc.b    tok_lgi-tok_proc
        dc.b    tok_str-tok_proc
        dc.b    tok_txt-tok_proc
        dc.b    tok_lno-tok_proc
        dc.b    tok_sep-tok_proc
        dc.b    tok_bad-tok_proc
        dcb.b   16,tok_fp-tok_proc

* Make space for literal int/fp

moreri
        cmp.l   bv_rip-4(a6),a1 is RI pointer ok?
        bge.s   rts0            yes - great!
        sub.l   bv_rip(a6),a1   keep a1 as -ve space wanted
        move.l  a1,d1
        neg.l   d1              d1 is now the space we want
        jsr     bv_chrix(pc)    get the space
        add.l   bv_rip(a6),a1   put a1 ready at requested point
rts0
        rts

* Re-use a spare name table entry, or create a new one and set it up as null

* This used to be nicer, before a bug came up. It is now not allowed to back
* up across named entries, otherwise the order of the name list entries can
* disagree with the order in the name table, causing a screwup in NEW. There
* are at least two ways round this, being either to make the name entry be
* insertion sorted in the right place, or to make new accept the unmatched
* sequence. The former would require a little code but the latter would be
* marvellous, if it we're darned nigh impossible! We cop out...

* d0 -  o- 0
* d2 -  o- -1
* a1 -  o- RI stack pointer
* a5 -  o- top of new name table entry
* d0-d1 destroyed

ca_oldnt
        movem.l bv_ntbas(a6),a1/a5
oldnext
        cmp.l   a1,a5
        beq.s   ca_newnt        no spare entries, so add at top
        move.l  -8(a6,a5.l),d0
        beq.s   set_nt          re-use a spare entry (d0.l=0)
        subq.l  #8,a5
        tst.w   d0
        bmi.s   oldnext         can't back across named entries (see above)
*       bra.s   ca_newnt

* Create a new name table entry and set it up as null

* d0 -  o- 0 (ccr set)
* d2 -  o- -1
* a1 -  o- RI stack pointer
* a5 -  o- top of new name table entry
* d1 destroyed

ca_newnt
        jsr     bv_chnt(pc)     check room for at least one more
        addq.l  #8,bv_ntp(a6)   we can get the space
        move.l  bv_ntp(a6),a5   get new name table entry address
set_nt
        moveq   #-1,d2
        move.l  d2,-4(a6,a5.l)  no value
        move.w  d2,-6(a6,a5.l)  unnamed
        clr.w   -8(a6,a5.l)     null type
        move.l  bv_rip(a6),a1   reload RI stack pointer
        rts

* Process simple variables

dosimp
        move.w  0(a6,a3.l),-8(a6,a5.l) copy entry
        moveq   #15,d1          separator mask and clear msw
        and.b   d1,-7(a6,a5.l)  don't including any separator
        move.w  d4,-6(a6,a5.l)  point at original name entry
        move.l  4(a6,a3.l),a3   pick up value pointer
        addq.b  #t.bpr-t.arr,d0 is name type array?
        beq.s   dup_desc        yes - need to duplicate the descriptor
        move.l  a3,-4(a6,a5.l)  store duplicate value pointer
ind_tk2
        bra.l   ind_tok         go get next

dup_desc
        move.l  a3,d0           check pointer to descriptor
        blt.l   err_xp          it hasn't been dimensioned!!
        add.l   bv_vvbas(a6),a3 actual descriptor pointer
        move.w  4(a6,a3.l),d1   number of dimensions
        lsl.l   #2,d1           two words per dimension
        addq.l  #4+2,d1         plus value offset and dimesion count
        move.l  a2,-(sp)        save new descriptor register
        jsr     ca_chkvv(pc)    find space for a copy (offset done & a1 reset)
arr_loop
        move.l  0(a6,a3.l),0(a6,a2.l) copy descriptor, longword at a time
        addq.l  #4,a3
        addq.l  #4,a2
        subq.l  #4,d1
        bpl.s   arr_loop
        move.l  (sp)+,a2        no longer need new descriptor pointer
        bra.s   ind_tk2

        vect4000 ca_eval

        end
