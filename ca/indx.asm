* Modifies array descriptor for given indices
        xdef    ca_indx,ca_range

        xref    bv_alvv,bv_frvv
        xref    ca_evali
        xref    mm_mrtor

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        offset  0
d_vvptr ds.l    1       descriptor values vv offset
d_dims  ds.w    1       n = descriptor number of dimensions (0..8191)
d.base  ;               size of fixed part of descriptor
d_max   ds.w    1       max index value (0..32767) \ * n for real descriptor
d_step  ds.w    1       step value (1..32767)      /
d.adim  equ     *-d.base size of repeated part of descriptor
d..adim equ     2       repeated part should be four bytes, so...
        assert  d.adim,1<<d..adim
* Note: dims<8192, as a tokenised line must have set it up

        section ca_indx

* General usage:
* d0 to d3 scratch / used by ca_evali
* d4 index counter
* d5 start index given
* d6 possibly reduced new number of dimensions
* a0 pointer to tokenised buffer
* a1 pointer to arithmetic stack
* a3 base of / running pointer to descriptor
* a4 vv offset to data
* a5 current pointer to name table
* a6 base of basic variables

* Get slice range
* d0 -  o- error code (ccr set)
* d1 -  o- second index in lsw, -1 for defaulted. msw preserved.
* d5 -  o- first index in lsw, -1 for defaulted. msw zero.
* a0 -i o- pointer to token before first index to check / at token stopped on
* a1 -  o- pointer to arithmetic stack
* a5 -ip - pointer to some nt entry
* d2-d3/a3-a4 destroyed

ca_range
        sub.l   bv_ntbas(a6),a5 protect nt pointer against movement
        move.l  a5,-(sp)
        moveq   #-1,d5          flag first index
rng_ind
        addq.l  #2,a0           move to next token
        jsr     ca_evali(pc)    fetch value of next index
        beq.s   rng_def         go set set default flag value
        bmi.s   rng_exit        die if index was bad
        moveq   #err.or,d0
        addq.l  #2,bv_rip(a6)   drop supplied value from stack
        move.w  0(a6,a1.l),d1   get supplied value
        addq.l  #2,a1
        bmi.s   rng_exit        no good if negative (ccr is right)
        bra.s   rng_nxt

rng_def
        moveq   #-1,d1          use -ve to flag omitted index
rng_nxt
        tst.l   d5
        bpl.s   rng_out         if 2nd time though, both indices are ready
        moveq   #0,d5           ready for 2nd pass
        move.w  d1,d5           save 1st index
        cmp.w   #w.septo,0(a6,a0.l) check for 'to'
        beq.s   rng_ind         if so, go get 2nd index
        moveq   #err.xp,d0
        tst.w   d5
        bmi.s   rng_exit        error if we didn't get any index (ccr is right)
rng_out
        moveq   #0,d0
rng_exit
        move.l  (sp)+,a5
        add.l   bv_ntbas(a6),a5
        rts

* d0 -  o- error code (ccr set)
* a0 -i o- token list pointer (ends up after close paren, if all ok)
* a1 -  o- pointer to arithmetic stack
* a5 -ip - pointer to top of nt entry being processed (with valid vv pointer)
* d1-d6/a3-a4 destroyed

ca_indx
        and.b   #15,-7(a6,a5.l) mask any separator
        bsr.s   get_ptrs
        move.l  a3,d6           a3 running input, d6 running output
        move.l  d_vvptr(a6,a3.l),a4 get vv pointer to data
        subq.l  #2,a0           back up to start loop easy
nxt_indx
        sub.l   a3,d6
        sub.l   bv_vvbas(a6),a3 ensure we're protected against movement
        move.l  a4,-(sp)
        move.l  a3,-(sp)
        bsr.s   ca_range
        move.l  (sp)+,a3
        move.l  (sp)+,a4
        bne.s   rts0
        add.l   bv_vvbas(a6),a3 restore our pointers
        add.l   a3,d6
        subq.w  #1,d4           there should have been an index left
        blt.s   err_or          if not, we've got too many dimensions spec'd
        bne.s   def_1st         no worries if not on last dimension
        assert  0,t.str-1,t.fp-2,t.int-3
        move.b  -7(a6,a5.l),d2
        asr.b   #1,d2
        bne.s   def_1st         only worry if last dim of non-numeric array
        bcc.s   is_char         already character array, so just byte index
        move.w  d5,d2
        or.w    d1,d2           are both indices zero? ('0' or '0to 0' allowed)
        beq.s   str_int         yes: string lengths convert to integer array
        addq.l  #2,a4           push vv data base offset over integer length
        clr.b   -7(a6,a5.l)     change type to character
is_char
        st      d0              set a flag for byte slicing
        subq.w  #1,d5           put index down to proper value
        bcs.s   err_or          shouldn't have zero start index here!
def_1st
        tst.w   d5              start defaulted? (-1 or -2)
        bpl.s   ok_lo
        clr.w   d5              default 0 start (effectively 1 for byte data)
ok_lo
        move.w  d5,d3
        assert  d_max,d_step-2
        move.l  d_max(a6,a3.l),d2 pick up max dim and increment
        addq.l  #d.adim,a3      move on
        mulu    d2,d3           multiply by increment
        cmp.b   #t.fp,-7(a6,a5.l) check type of array
        blt.s   addbas          string
        bgt.s   double          integer
        add.l   d3,d3           float
        add.l   d3,a4           x 6 bytes for floating points
double
        add.l   d3,a4           x 2 bytes for integers
addbas
        add.l   d3,a4           add to vv data base offset
        swap    d2              bring down max dim
        cmp.w   d2,d5           start must be positive and le dimension
        bhi.s   err_or
        tst.w   d1
        bmi.s   max_2nd         default 2nd index, make it max
        cmp.w   d1,d2
        bcc.s   top_ok          ok if not greater than current dimension
        tst.b   d0              are we slicing last dimension of byte data?
        bne.s   max_2nd         yes - we allow top>dim (consistent with strvar)
err_or
        moveq   #err.or,d0
rts0
        rts

get_ptrs
        move.l  -4(a6,a5.l),a3  fetch pointer to descriptor
        add.l   bv_vvbas(a6),a3 make absolute
        move.w  d_dims(a6,a3.l),d4 fetch number of dimensions
        rts

* String slice has picked out lengths, which become an integer array
* Note that the ultimate element size is now 2, so all increments need halving 
str_int
        addq.b  #t.int-t.str,-7(a6,a5.l) change type to integer
        bsr.s   get_ptrs        reload a3 with start of descriptor
        clr.w   d4              put remaining dims back to zero
halveit
        cmp.l   d6,a3           have we got anything left to do?
        beq.s   skip_dim        no, the last dim vanishes
        lsr     d_step(a6,a3.l) halve the increment, 'cos string is now integer
        addq.l  #d.adim,a3      move along to next dimension
        bra.s   halveit

top_ok
        move.w  d1,d2           replace dim with new value
max_2nd
        sub.w   d5,d2
        bcs.s   err_or          can't allow it to go negative!
        bne.s   put_dim         gotta keep non-zero dimension
        tst.b   d0              are we slicing last dimension of byte data?
        beq.s   skip_dim        we allow null sub-strings, but don't lose dim!
put_dim
        swap    d2
        assert  d_max,d_step-2
        move.l  d2,d_max(a6,d6.l) save new dimension and increment
        addq.l  #d.adim,d6
skip_dim
        move.w  0(a6,a0.l),d0   look at delimiter
        cmp.w   #w.sepcom,d0     is it a comma?
        beq.l   nxt_indx        yes - continue getting slices/subscripts
        cmp.w   #w.cpar,d0      is it our close parenthesis?
        beq.s   desc_rdy        yes - that's nice
err_xp
        moveq   #err.xp,d0      didn't find the closing parenthesis
        rts

* We've finished scanning the program code and got all our dimensions now

tail_cpy
        assert  d_max,d_step-2
        move.l  d_max(a6,a3.l),d_max(a6,d6.l)
        addq.l  #d.adim,d6
        addq.l  #d.adim,a3
desc_rdy
        dbra    d4,tail_cpy     copy down any remaining dim/inc pairs
        bsr.s   get_ptrs        reload a3 and d4
        addq.l  #2,a0           move over matched close parenthesis
        sub.l   a3,d6           total space occupied by repeated part
        move.l  d6,d1           saved for possible allocate
        lsr.l   #d..adim,d6     are we reducing to a simple variable?
        bne.s   keep_arr        skip if not all dimensions have vanished

* $$$$$ Note. This may cause problems later if proc tries to free it $$$$$$$$

        subq.b  #t.arr-t.var,-8(a6,a5.l) set name type to simple variable
        bra.s   ind_free        go free the descriptor

keep_arr
        move.l  a4,d_vvptr(a6,a3.l) set vv offset
        cmp.w   d4,d6           are we actually keeping everything?
        beq.s   okrts           yes - so we've finished!

* Create new descriptor first (they're only small and it makes copying easy)

        move.w  d6,d_dims(a6,a3.l) set new dimension count
        addq.l  #d.base,d1      total length of new desc
        move.l  a0,a4           save a0
        jsr     bv_alvv(pc)     allocate the space (resets a1 from bv_rip(a6))
        exg     a1,a3           swap ri and old descriptor pointers
        jsr     mm_mrtor(pc)    copy shortened descriptor to new area
        exg     a1,a3           swap back ri and old descriptor pointers
        exg     a0,a4           restore a0 and set a4 to new area pointer
        sub.l   bv_vvbas(a6),a4 prepare new offset
ind_free
        move.l  a4,-4(a6,a5.l)  fill in changed vv offset
        moveq   #d.adim,d1
        mulu    d4,d1
        addq.l  #d.base,d1      total length of original descriptor
        exg     a0,a3
        jsr     bv_frvv(pc)     free old descriptor
        exg     a0,a3
okrts
        moveq   #0,d0
        rts

        end
