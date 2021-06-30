* Read data value, allowing arrays
        xdef    bp_read,bp_arset,bp_arind,bp_arnxt,bp_arend,bp_rdchk

        xref    bp_data,bp_let
        xref    bv_alvvz,bv_frvv
        xref    ca_eval

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_assert'

        offset  0
d_vvptr ds.l    1       descriptor values vv offset
d_dims  ds.w    1       n = descriptor number of dimensions (0..8191)
d_max   ds.w    1       max index value (0..32767) \ * n for real descriptor
d_step  ds.w    0       step value (1..32767)      /
d_oldvv ds.l    1       saved descriptor vv offset
d_index ds.w    1       current index * n, last entry unused by (sub-)strings

* Note: we know d_dims < 8191, 'cos a tokenised line had to set it up!

* Check whether object described in name table (a6,a3.l) can be input/read.

* The things which can be read into are:

*       00x1 00x2 00x3  unassiged variables
*       02x1 02x2 02x3  simple variables
*  03x0 03x1            substring and string array
*       06x1 06x2 06x3  repeat variables
*       07x1 07x2 07x3  for variables

* Substring and string arrays (03x0 and 03x1) are ok if singly dimensioned.
* Other arrays are rejected with err.ni in d0.
* The rest are rejected with err.bn in d0.

        section bp_read

* d0 -  o- error return (ccr set)
* a3 -ip - pointer to name table entry tested (a6 rel.)

bp_rdchk
        move.b  0(a6,a3.l),d0   get usage byte
        beq.s   unass           zero, so check for blank space
        ror.b   #2,d0           bit 1 set implies type 2,3,6,7 - all ok
        bpl.s   err_bn          types not allowed...
        cmp.b   #t.arr<<6,d0    is it an array?
        bne.s   okrts           not an array, so it's ok
        btst    #1,1(a6,a3.l)   check second byte
        bne.s   err_ni          fp or integer, so no go...
        move.l  4(a6,a3.l),d0   we have a (sub-)string array
        add.l   bv_vvbas(a6),d0
        cmp.w   #1,d_dims(a6,d0.l)   so is it only one dimensioned?
        beq.s   okrts           yes, so allowed
err_ni
        moveq   #err.ni,d0
        rts

unass
        moveq   #3,d0
        and.b   1(a6,a3.l),d0   is entry completely blank?
        bne.s   okrts           no, so must be unassigned - ok
err_bn
        moveq   #err.bn,d0
        rts

* d0 error code
* d6 -1 while no array block is allocated, otherwise vv offset to it
* d7 counter*8 of remaining args
* a3 nt pointer to argument being read

bp_read
        move.l  a5,d7
        sub.l   a3,d7           counter
        bra.s   nx_arg

go_arg
        bsr.s   bp_arset        set up in case array needs handling
        bsr.s   bp_rdchk        check that we can read into it (now)
        bne.s   arend
nx_ind
        jsr     bp_data(pc)     get the next data item
        bne.s   arend
        addq.b  #1,bv_daitm(a6) good, so move on next time
        bsr.l   bp_arind        set nt entry for array element
        move.b  1(a6,a3.l),d0   what are we reading
        sub.l   bv_ntbas(a6),a3
        move.l  a3,-(sp)
        jsr     ca_eval(pc)     read expression
        move.l  (sp)+,a3
        add.l   bv_ntbas(a6),a3
        ble.s   arend           evaluation error
        jsr     bp_let(pc)      do the assignment
        bsr.s   bp_arnxt        step array elements
        bgt.s   nx_ind          more elements, so carry on
arend
        bsr.s   bp_arend        discard any array index block
        bne.s   rts0
        addq.l  #8,a3
        subq.l  #8,d7
nx_arg
        bne.s   go_arg
okrts
        moveq   #0,d0
rts0
        rts

* Arrays (other than singly dimensioned (sub-)string ones) are handled by
* allocating a temporary vv structure. A dummy singly dimensioned array
* descriptor is constructed here, followed by the original descriptor offset,
* and thereafter words contain the current indices.
* The step size in the dummy descriptor is not relevent.
* For strings and substrings, the vv offset to this structure, and hence to the
* dummy descriptor replaces the vv pointer in the nt entry.
* For integer and fp arrays, the nt entry is modified to suggest that a simple
* variable is being accessed, and its vv pointer tracks through the array.
* Constructing the dummy descriptor for int/fp is somewhat redundant, but
* simplifies the code rather a lot!

* Start up for possible elements of an array (N.B. VV allocation may be done)
* d0 -i o- unchanged if no array set up, or set to zero
* d6 -  o- -1 or array index block vv offset (ccr set)
* a3 -ip - nt pointer to argument under examination
* d0-d3/a1 destroyed
bp_arset
        cmp.b   #t.arr,0(a6,a3.l) are we about to operate on an array?
        bne.s   simple          no - so just do a simple argument
        move.l  4(a6,a3.l),d3   get vv offset to array descriptor
        add.l   bv_vvbas(a6),d3 make pointer to descriptor
        bsr.s   tsttype         check for (sub-)string
        bcs.s   intfp           int/fp must always be done 
        cmp.w   #1,d_dims(a6,d3.l) check dimensionality
        bne.s   array           single dimension, i.e.(sub-)string, we can do
simple
        moveq   #-1,d6          we haven't set up an array struct
        rts

* Step to next of possible elements of an array
* ccr-  o- lt or mi: not array, eq: end array, gt: still going
* d0 -i o- unchanged if not an array, set to zero at end or 2*indices left
* d6 -  o- -1 or array index block vv offset
* a3 -ip - nt pointer to argument under examination
* d1-d3 destroyed
bp_arnxt
        bsr.s   pickup          are we doing an array?
        bmi.s   rts5            no - just say we've finished
        add.l   d1,d2           point past counter for index
        add.l   d1,d3
        add.l   d1,d3           point at max for index
        bsr.s   tsttype         check type
        bcc.s   dec_str         skip back one subscript for (sub-)strings
cn_inc
        move.w  d_max-4(a6,d3.l),d0 get max for this dimension
        addq.w  #1,d_index-2(a6,d2.l) update count
        cmp.w   d_index-2(a6,d2.l),d0 has current count gone past max?
        bcc.s   nxt_ex          no - do this one
        clr.w   d_index-2(a6,d2.l) reset count to zero
dec_str
        subq.l  #4,d3
        subq.l  #2,d2
        subq.w  #2,d1           count off this index
        bne.s   cn_inc          and try again (if not dropping off the front)
nxt_ex
        move.l  d1,d0           set ccr and d0.l=0 at end
rts5
        rts

* Finished with array index block
* d0 -ip - error code, ccr set
* d6 -ip - -1 or array index block vv offset
* d1-d3/a1 destroyed
bp_arend
        bsr.s   pickup
        bpl.s   frvv
        tst.l   d0
        rts

intfp
        subq.b  #t.arr-t.var,0(a6,a3.l) convert int/fp from array to simple var
array
        bsr.s   cn_len
        sub.l   bv_ntbas(a6),a3
        lea     bv_alvvz(pc),a1
        bsr.s   callit
        add.l   bv_ntbas(a6),a3
        move.l  4(a6,a3.l),d_oldvv(a6,d2.l) save original descriptor offset
        addq.w  #1,d_dims(a6,d2.l) dimensionality set to one (rdchk needs it)
        move.l  d2,d6
        sub.l   bv_vvbas(a6),d6
        move.l  d6,4(a6,a3.l)   replace vv offset to go to our dummy descriptor
        rts

tsttype
        move.b  1(a6,a3.l),d0
        rol.b   #7,d0           check type
        rts

pickup
        move.l  d6,d2
        bmi.s   rts7
        move.l  bv_vvbas(a6),d3
        add.l   d3,d2           point at out index block
        add.l   d_oldvv(a6,d2.l),d3 point at original descriptor
cn_len
        moveq   #2,d1           in words (last unused for (sub-)strings)
        mulu    d_dims(a6,d3.l),d1 no of dimensions
rts7
        rts

frvv
        move.l  d_oldvv(a6,d2.l),4(a6,a3.l) restore original vv ptr into nt
        move.b  #t.arr,0(a6,a3.l)   restore array type (for int/fp)
        lea     bv_frvv(pc),a1  preserves d0.l and sets ccr from it
callit
        exg     a0,d2           swap a0 with d2
        add.w   #d_index,d1     include dummy 1-dim desc and old descr pointer
        jsr     (a1)            (note we can get away with add.w, as d1<16384)
        exg     a0,d2           restore a0
        rts

* Index possible elements of an array
* d6 -  o- -1 or array index block vv offset
* a3 -ip - nt pointer to argument under examination
* d0-d3/a1 destroyed
bp_arind
        bsr.s   pickup
        bmi.s   rts9
* Calculate position of next element in array
        sub.l   a1,a1           element offset zero
        add.l   d1,d3
        add.l   d1,d3           temporarily shift descriptor pointer by 4*n
        move.w  d_max-4(a6,d3.l),d_max(a6,d2.l) copy last max for (sub-)strings
        add.l   d1,d2           temporarily shift counter pointer by 2*n
nx_dim
        subq.l  #2,d2           move counter pointer back
        move.w  d_index(a6,d2.l),d0 get count of index
        subq.l  #4,d3           move descriptor pointer back
        mulu    d_step(a6,d3.l),d0 multiplier
        add.l   d0,a1           move element offset on for this dimension
        subq.w  #2,d1           move back one dimension
        bne.s   nx_dim          drop out when d6/d3 are back to start
        move.l  d_vvptr(a6,d3.l),d1 get vv offset to indexed value
        bsr.s   tsttype         check type
        bcc.s   add_ok          (sub-)strings are ready to have dummy set up
        add.l   a1,a1           x 2 does for integers
        bmi.s   bendptr         so they're ready here
        add.l   a1,d1
        add.l   a1,a1           x 6 for f.p.
bendptr
        moveq   #4-d_vvptr,d2
        add.l   a3,d2           bend pointer appropriatly at nt entry
add_ok
        add.l   d1,a1           form vv offset to indexed value
        move.l  a1,d_vvptr(a6,d2.l) set offset in dummy descriptor or nt entry
rts9
        rts

        end
