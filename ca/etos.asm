* Evaluate top of stack
        xdef    ca_etos,ca_putss,ca_undo

        xref    bv_chrix,bv_frvv
        xref    mm_mrtor

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'

        section ca_etos

* Evaluate current top of stack, guaranteeing a result on the RI stack.

* There is a problem to resolve here... is a1 guaranteed to match bv_rip on
* entry? This rather assumes so in some cases, but not in others!
* A similar problem crops up with a5, and usage of ca_undo...

* d0 -  o- error return code
* a1 -i o- pointer to arithmetic stack
* a5 -i o- pointer to name table
* d1-d2/a4 destroyed

ca_etos
        and.b   #15,-7(a6,a5.l) mask any seps which may have crept in
        assert  2,2&t.var&t.arr&t.rep&t.for
        assert  0,2&(t.unset!t.intern!t.bpr!t.bfn!t.mcp!t.mcf)
        assert  64,t.intern<<6,256-t.arr<<6
        moveq   #64,d0          for sorting out intern/arry
        move.b  -8(a6,a5.l),d1  look at msb of variable type
        ror.b   #2,d1
        bcc.s   qintern         divide into two sets
        add.b   d1,d0
        beq.s   put_arry        array
put_item
        move.l  -4(a6,a5.l),d1  get vv offset
        blt.s   ets_err         no value, that's an error
        move.l  d1,a4
        add.l   bv_vvbas(a6),a4 make into rel a6
        cmp.b   #t.fp,-7(a6,a5.l) check type
        bne.s   put_qs          not floating point
put_fp
        moveq   #6,d1           put a floating point (6 bytes)
        bsr.s   chk_ri          make room
        move.l  2(a6,a4.l),2(a6,a1.l) move mantissa
        bra.s   ets_wrd

qintern
        sub.b   d1,d0
        beq.s   ets_exit        if internal it's already on RI stack
ets_err
        moveq   #1,d2           undo anything
        bsr.l   ca_undo         remove the offending entry
        move.l  a5,bv_ntp(a6)   and reset the NT pointer
        moveq   #err.xp,d0
        rts

moreri
        move.l  d1,a1
        jsr     bv_chrix(pc)    make room
        move.l  a1,d1
chk_ri
        move.l  bv_rip(a6),a1   set arithmetic stack pointer
        sub.l   d1,a1
        cmp.l   bv_rip-4(a6),a1
        blt.s   moreri
        rts

put_qs
        blt.s   putst           go if item is a string
        moveq   #2,d1           put an integer (2 bytes)
        bsr.s   chk_ri
ets_wrd
        move.w  0(a6,a4.l),d1
        move.b  #t.intern,-8(a6,a5.l) internal now
ets_put
        move.w  d1,0(a6,a1.l)  put integer (fp exponent) on RI stack
ets_exit
        move.l  a1,bv_rip(a6)   save arithmetic stack pointer
        moveq   #0,d0
        rts

put_arry
        move.l  -4(a6,a5.l),d1  fetch address of array descriptor
        add.l   bv_vvbas(a6),d1 absolute
        move.l  0(a6,d1.l),a4   find base address of array
        add.l   bv_vvbas(a6),a4 absolute
        movem.w 4(a6,d1.l),d0/d2 get dimensions and possible substring length
        subq.w  #1,d0           array must be one dimensional
        bgt.s   ets_err
        move.b  -7(a6,a5.l),d0  it must be a (sub)string
        subq.b  #t.str,d0       check this
        bgt.s   ets_err
        bsr.s   fr_des          discard descriptor
        exg     d2,d1           put possible substring length in right reg
        bne.s   putss           it is a substring
putst
        move.w  0(a6,a4.l),d1   find length of string (assumed non-negative)
        addq.l  #2,a4
putss
        move.w  #t.intern<<8!t.str,-8(a6,a5.l) becoming internal string now

* Puts a sub-string on the RI stack.

* d0 -  o- 0
* d1 -i o- string length in lsw (if negative, made 0. msw destroyed)
* a1 -  o- RI stack
* a4 -i  - pointer to string characters (may be odd).
* d2 destroyed

ca_putss
        ext.l   d1              want it long
* We don't really expect to be called with a negative length...
*       bpl.s   put_lok
*       moveq   #0,d1           just to be realy safe (lwr)
*put_lok
        addq.l  #2,d1           extra to store length and rely on even pointers
        bsr.s   chk_ri
        subq.l  #2,d1           restore string length
        beq.s   ets_put         nothing to copy

        moveq   #1,d2
        and.b   d1,d2
        sub.l   d2,a1           this is where it's going
        add.l   d1,d2           length rounded up to even

        subq.l  #2,d2           check for 1/2 bytes only
        bne.s   put_sg2         not just an odd one or two bytes
        move.b  0(a6,a4.l),d2   get first byte
        rol.w   #8,d2           put it in msw
        move.b  1(a6,a4.l),d2   get second byte, or junk
        move.w  d2,2(a6,a1.l)   put byte pair (we've allowed for 'ab'(2))
        bra.s   ets_put         finished
* The above can be extended to cope with 1..4 bytes, should it seem too slow.

put_sg2
        exg     a0,a1           want destination in a0
        exg     a4,a1           want source in a1
        addq.l  #2,a0
        jsr     mm_mrtor(pc)    use the fast move
        subq.l  #2,a0
        exg     a4,a1
        exg     a0,a1
        bra.s   ets_put

* Free a string descriptor

* ccr-  o- result of "tst.l d0"
* d1 -i  - pointer to decriptor

fr_des
        move.l  a0,-(sp)
        move.l  d1,a0           free from here
        moveq   #4+2+2+2,d1     this much space
        jsr     bv_frvv(pc)
        move.l  (sp)+,a0
        rts

* Undoes an entry on the name table and RI stack.
* z  -  o- if d2.l is zero, z is set iff a t.intern gets undone
* d2 -ip - longword flag zero, only undo t.intern, or non-zero, undo anything
* a5 -i o- NT stack
* d1 destroyed

ca_undo
        moveq   #t.intern,d1
        sub.b   -8(a6,a5.l),d1
        beq.s   undo_int

        tst.l   d2              do non-int or stop at them?
        beq.s   ret_undo        stop
        addq.b  #t.arr-t.intern,d1 do them
        bne.s   nxt_un          if not an array, kill it off

        move.l  -4(a6,a5.l),d1  where is the copy descriptor?
        bmi.s   nxt_un          isn't one
        add.l   bv_vvbas(a6),d1
        bsr.s   fr_des          go and free the descriptor
        bra.s   nxt_un

undo_int
        moveq   #15,d1
        and.b   -7(a6,a5.l),d1
        add.b   d1,d1           this is neatly ready for (t.int-t.fp)*2 = 2
        subq.b  #t.fp*2,d1      what is the variable type?
        bgt.s   int_int         integer
        beq.s   int_fp          floating point

        move.l  bv_rip(a6),d1
        move.w  0(a6,d1.l),d1
        ext.l   d1
        subq.l  #6-3,d1
        bclr    #0,d1           length of string + 2 for len and evened
int_fp
        addq.l  #6,d1           + 6 for fp
int_int
        add.l   d1,bv_rip(a6)   also, guarantee non-z on return
nxt_un
        subq.l  #8,a5
ret_undo
        rts

        end
