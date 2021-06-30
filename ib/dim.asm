* Allocate dimensioned array space
        xdef    ib_dim,ib_frdes,ib_frdim,ib_mkdim

        xref    bv_alvv,bv_alvvz,bv_frvv
        xref    ca_evali,ca_frvar
        xref    ib_nxnon,ib_s2non,ib_s4non

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ib_dim

* d0 -  o- error code
* a4 -i o- program file
* d1-d6/a0-a3/a5 destroyed

ib_dim
        subq.l  #2,a4
nx_array
        jsr     ib_s2non(pc)    skip DIM or comma and get name of array
        moveq   #8,d4
        mulu    2(a6,a4.l),d4
        move.l  bv_ntbas(a6),a2
        add.l   d4,a2
        jsr     ca_frvar(pc)    free it straight off - stops fragmentation
        jsr     ib_s4non(pc)    skip the name and get to the open parenthesis
        bsr.s   ib_mkdim        make the dimensions
        bne.s   rts0
        jsr     ib_nxnon(pc)    get next non-space
        cmp.w   #w.symcom,d1    is it a comma?
        beq.s   nx_array        yes, there's another array to come
        moveq   #0,d0
rts0
        rts

* The dimensions used to be stored at bv_bfbas while they were scanned. This
* horrendous practice has been replaced by just leaving them to build up on
* the ri stack, which is perfectly safe. lwr.

dim_xp
        moveq   #err.xp,d0
dim_stop
        add.l   d5,bv_rip(a6)   discard stacked dimensions
        tst.l   d0
        rts

* d0 -  o- worked (0) or failed
* a2 -i  - vv ptr to name being dimensioned (global cleared or local new entry)
* a4 -i o- program file pointer. start at open, end past close parentheses.
* d1-d6/a0-a3/a5 destroyed

ib_mkdim
        move.l  bv_ntbas(a6),d4
        sub.l   a2,d4           save nt offset (negated)
        moveq   #0,d5           start no of dim at zero (will count in 2's)
getdim
        addq.l  #2,a4           skip over the open parenthesis or comma
        move.l  a4,a0           for evaluation
        jsr     ca_evali(pc)    dimensions must be integer
        move.l  a0,a4
        bmi.s   dim_stop
        addq.l  #2,d5           no of dimensions has just gone up
        move.w  0(a6,a4.l),d0   get expr stop token
        sub.w   #w.symcom,d0
        beq.s   getdim          if a comma, more dimensions
        addq.l  #2,a4           skip it
        subq.w  #w.cpar-w.symcom,d0 
        bne.s   dim_xp          end of dims must be a close parenthesis

* That's the interpreting side over with, now allocate the new descriptor

        move.l  d5,d1
        add.l   d1,d1
        addq.l  #6,d1
        jsr     bv_alvv(pc)     allocate new descriptor & set a1=bv_rip(a6)
        bsr.s   dim_stop        discard stack entries
        move.l  a0,a5
        add.l   d5,a5
        add.l   d5,a5           point to top of descriptor, less 6 bytes
        lsr.l   #1,d5           make this the proper dimension count
        move.w  d5,4(a6,a0.l)   store it now, in case we get problems

* New descriptor ready. Construct its details.

        move.l  bv_ntbas(a6),a3 base of name table
        sub.l   d4,a3           point at entry
        moveq   #err.bn,d0
        cmp.b   #t.arr,0(a6,a3.l) i suppose this is an array...?
        bne.s   frdes           ho hum.. we've been wasting our time

        moveq   #err.or,d0      this will be the error report in this bit

        move.w  0(a6,a1.l),d3   pick up final dimension
        move.b  1(a6,a3.l),d6
        clr.w   d4              no extra addend
        moveq   #1,d2           initial multiplier
        assert  1,t.str
        cmp.b   d2,d6           string array?
        bgt.s   descent

        addq.w  #1,d3
        bclr    d4,d3           rounds up the final string dimension to even
        addq.w  #1,d4           extra addend for word string length
        bra.s   descent
* d0=err.or, d2=1, d3=lastdim, d4.w=addend, d5=dims, d6=type

* N.B. There is a complete fluke involved here! a string array of just the
* single dimension (e.g. dim a$(5)) will always have had it's final (only)
* dimension rounded up to even. The multiplier will be one, so the calculation
* finishes up with the odd value, 1 * (dimn(1)+1), which will kindly be
* rounded up by the allocation/release routines! lwr.
 
* d1 -  o- size of array data area
* d6 -ip - type of data (0/1 string, 2 fp or 3 integer)
* a2 -ip - address of descriptor
* a0 destroyed

calcsz
        moveq   #1,d1
        add.w   6(a6,a2.l),d1   dimn(1) plus 1
        mulu    8(a6,a2.l),d1   x (mult dim 1) = no of elements in array
        cmp.b   #t.fp,d6        type of array
        blt.s   rts9            string array size already set
        bne.s   csz_int
        move.l  d1,a0
        add.l   d1,d1
        add.l   a0,d1           x 6 bytes for a floating point array
csz_int
        add.l   d1,d1           x 2 bytes for an integer array
rts9
        rts

* d0 -ip - possible error code, returned with ccr set
* d4 -i  - vv offset of descriptor to be discarded, along with its data
* d6 -ip - type of array
* d1/a0/a2 destroyed

ib_frdim
        move.l  bv_vvbas(a6),a2
        add.l   d4,a2           point at descriptor
        move.l  0(a6,a2.l),d4   offset to values
        bmi.s   ib_frdes        if they're not set, don't free 'em!
        bsr.s   calcsz
        move.l  d4,a0
        add.l   bv_vvbas(a6),a0 base of vv
        bsr.s   frvv            free the space and the descriptor

* d0 -ip - possible error code, returned with ccr set
* a2 -i  - descriptor to be discarded
* d1/a0 destroyed

ib_frdes
        move.l  a2,a0
frdes
        moveq   #(4+2+2)>>2,d1  we know vv is always multiple of eight
        add.w   4(a6,a0.l),d1   no of dimensions (less than 8188)
        asl.l   #2,d1           x 4 = no of bytes
frvv
        jmp     bv_frvv(pc)     free the array descriptor

desclp
        add.w   d4,d3           extra addend, one for last dim of string
        addq.w  #1,d3           dimension plus element zero
        mulu    d3,d2           get multiplier for previous dimension
        swap    d2
        move.w  d2,d4           clears extra addend, if all is ok
        bne.s   frdes           multiplier has gone out of range
        swap    d2
        addq.l  #2,a1           get previous dimension on stack
        move.w  0(a6,a1.l),d3
descent
        move.w  d2,6-2(a6,a5.l) fill in the multiplier
        move.w  d3,6-4(a6,a5.l) fill in the dimension
        bmi.s   frdes           dimension is out of range
        subq.l  #4,a5           get previous dimension in descriptor
        subq.w  #1,d5           finished yet?
        bne.s   desclp          no - carry on

* We now have a perfectly good new descriptor.

        move.l  a5,a2
        bsr.s   calcsz
        sub.l   bv_vvbas(a6),a2
        move.l  a2,4(a6,a3.l)   fill in offset of new descriptor
        jsr     bv_alvvz(pc)    allocate the data space, zeroed out
        sub.l   bv_vvbas(a6),a0
        move.l  a0,0(a6,a5.l)   fill in offset to array values
        moveq   #0,d0           already zero, but get ccr right
        rts

        end
