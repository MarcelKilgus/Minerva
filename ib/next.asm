* NEXT statement, etc
        xdef    ib_fname,ib_frnge,ib_gtlpl,ib_index,ib_loop,ib_next,ib_psend

        xref    ib_cheos,ib_golin,ib_gost,ib_nxnon,ib_stnxi,ib_wtest
        xref    ri_add,ri_cmp,ri_dup,ri_sub
        xref    ca_eval
        xref    bv_chri
 
        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_lpoff'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ib_next

* d6 - l - keeps name row safe, msb flags assignment made
* d4 -il - name row(i), arg for golin, gost(l)
* a4 -i o- program file
* a2 - l - loop description

isfp
        jsr     bv_chri(pc)     check ri
        move.l  bv_rip(a6),a1
        sub.w   #2*6,a1
        move.l  lp.sexp+2(a6,a2.l),2(a6,a1.l) put step onto ari stack
        beq.s   finx            zero mantissa
        move.w  lp.sexp(a6,a2.l),0(a6,a1.l) step exponent
        move.w  lp.iexp(a6,a2.l),6(a6,a1.l) put index onto ari stack
        move.l  lp.iexp+2(a6,a2.l),6+2(a6,a1.l)
        jsr     ri_add(pc)      add step to index value
        bne.s   finx

        jsr     ri_dup(pc)      copy result
        subq.l  #6,a1
        move.l  lp.eexp+2(a6,a2.l),2(a6,a1.l) put end value onto ari stack
        move.w  lp.eexp(a6,a2.l),0(a6,a1.l)
        jsr     ri_sub(pc)
        moveq   #13,d1          diff in exps (1e4) neccessary for equality
        add.w   0(a6,a1.l),d1   add the (index+step-endval) exponent
        cmp.w   lp.sexp(a6,a2.l),d1 compare it with the step exponent
        lea     lp.eexp-6(a2),a0 if we're near end value, make it exact
        ble.s   cont            this is so close, use exact endval
        move.l  a1,a0           the saved result is just above here
        tst.b   2(a6,a1.l)      look at top of mantissa
        blt.s   neg_0           negative
        tst.b   lp.sexp+2(a6,a2.l) pos, what about top of step?
        blt.s   cont            negative, continue stepping
finx
        bra.l   fin1            range exhausted

neg_0
        tst.b   lp.sexp+2(a6,a2.l) step sign?
        blt.s   finx            end of range
cont
        move.w  6(a6,a0.l),lp.iexp(a6,a2.l) update the index with new value
        move.l  6+2(a6,a0.l),lp.iexp+2(a6,a2.l)
        bra.s   assign

ib_next
        bsr.l   ib_gtlpl
        beq.s   ib_loop
        tst.l   d0
rts0
        rts

* Set psuedo end for inline consrtucts

ib_psend
        move.b  #127,bv_stmnt(a6) highly unlikely statement number
        move.w  bv_index(a6),d4 last inline index name spotted
        bsr.l   gtind           get everything else from gtlpl
        bne.s   rts0

* Machinery for NEXT

ib_loop
        moveq   #0,d6           clear msb of d6 as flag for no assignment yet
        move.w  d4,d6           save name row
        subq.b  #t.rep,d1       is this a REP loop?
        beq.s   simple_0        yes
        subq.b  #t.fp,d2        what type are we doing?
        bgt.s   isint
        beq.l   isfp

        move.b  lp.sexp+2(a6,a2.l),d0
        beq.s   fin1            step zero, so finish
        spl     d3
        tst.b   lp.iexp+1(a6,a2.l)
        beq.s   fin1            someone's made it a null, i'll stop here
        move.b  lp.iexp+2(a6,a2.l),d1
        add.b   d0,d1
        bvs.s   fin1            went over top, forget it
        cmp.b   lp.eexp+2(a6,a2.l),d1
        beq.s   usestr
        sgt     d0
        eor.b   d0,d3
        beq.s   fin1
usestr
        move.b  d1,lp.iexp+2(a6,a2.l)
        bra.s   assign

useint
        move.w  d1,lp.iexp(a6,a2.l)
assign
        bset    #31,d6          set flag for assignment made
simple_0
        sf      d3
        bra.s   simple

isint
        move.w  lp.sexp(a6,a2.l),d0
        beq.s   fin1            step zero, so we're done
        spl     d3              remember it's sign
        move.w  lp.iexp(a6,a2.l),d1
        add.w   d0,d1
        bvs.s   fin1            went over the top, so must be finished!
        cmp.w   lp.eexp(a6,a2.l),d1
        beq.s   useint          exact match, use it
        sgt     d0
        eor.b   d0,d3           ok, so was inc +ve and we're gt, or the reverse
        bne.s   useint          yes - straight end of range

fin1
        moveq   #1,d3
simple
        bsr.s   ch_lplin
        bne.s   exit
        tst.b   bv_inlin(a6)    in-line for?
        ble.s   offinl          no, turn it off
        cmp.b   #127,bv_stmnt(a6) real end or pseudo end?
        bne.s   leaveinl
offinl
        sf      bv_inlin(a6)    turn inline flag off
leaveinl
        moveq   #0,d0
exit
        move.l  d6,d4           has a var. been assigned to?
        bpl.s   back            no, go back
        tst.w   bv_wvnum(a6)    are there any when vars. to check?
        beq.s   back            no
        jmp     ib_wtest(pc)    if when var. cond. satisfied, act

* Check loop line is all it is supposed to be

* a2 -i  - loop index entry
* d3 -i  - 0 if just check wanted, non-0 if next frange required
* d6 -i o- name row

ch_lplin
        move.b  bv_stmnt(a6),-(sp) save statement
        move.l  bv_linum(a6),-(sp) save line num, length
        move.l  a4,-(sp)
        move.w  lp.sl(a6,a2.l),d4 start line of loop
        jsr     ib_golin(pc)    set prog file pointer to FOR
        bne.s   rest_nf
        jsr     ib_stnxi(pc)    start the next line off not changing i/l
        move.b  lp.ss(a6,a2.l),d4 read start statement
        jsr     ib_gost(pc)     go to statement
        jsr     ib_nxnon(pc)    look at first thing on it
        sub.w   #w.for,d1       is it a FOR
        assert  2,w.rep-w.for
        roxr.w  #2,d1           or a REP?
        bne.s   rest_nf
        addq.l  #2,a4
        move.l  a4,a5
        jsr     ib_nxnon(pc)
        cmp.w   2(a6,a4.l),d6   does the name match?
        bne.s   rest_nf
        tst.b   d3
        bne.s   do_range
end_ch
        add.w   #4+4+2,sp
        rts

rest_nf
        moveq   #err.nf,d0
        bra.s   rest_ch

do_range
        move.l  a5,a4
        add.w   lp.chpos(a6,a2.l),a4 add previous char pos to pf pointer
        move.w  d6,d4           need this for forange
        bsr.s   ib_frnge
        beq.s   end_ch          good range
        blt.s   rest_ch         error in range line
        moveq   #0,d0           exhausted all ranges
rest_ch
        move.l  (sp)+,a4
        move.l  (sp)+,bv_linum(a6) restore line number, length
        move.b  (sp)+,bv_stmnt(a6) restore which statement
back
        tst.l   d0
        rts

* a2 -i  - beginning of index description
* d0 -  o- -ve error in exp
*            0 good range found
*           +1 for line exhausted

* N.B. Unlike previously, this doesn't zap the value in a variable when it
* finds a range that is already exhausted. It acheives this by putting the
* start value into the step slot first, then only copying it across to its
* proper place when it has established that the range is not exhausted.

ib_frnge
        move.l  a4,-(sp)        save current pf position
        move.w  0(a6,a4.l),d1
        jsr     ib_cheos(pc)    line feed or colon next?
        bne.s   chk_rng
        moveq   #1,d0
        bra.s   pop_4

chk_rng
        cmp.w   #w.equal,d1
        beq.s   read_rng
        cmp.w   #w.symcom,d1
        bne.s   pop4_or
read_rng
        move.w  d4,d6           keep name row safe
        bsr.l   ib_index        pick up info first time in
        bsr.l   getexpr         get the first expression
        cmp.w   #w.keyto,0(a6,a4.l) is it a TO ?
        beq.s   range           yes, otherwise single value, set defaults
        move.w  d0,lp.eexp(a6,a2.l) len, exp or val of the index value
        move.l  d1,lp.eexp+2(a6,a2.l) mantissa/chars of the index value
        clr.w   lp.sexp(a6,a2.l) use a step of zero
        clr.l   lp.sexp+2(a6,a2.l)
        move.l  (sp)+,d2
        move.w  d0,lp.iexp(a6,a2.l) copy index value exponent
        move.l  d1,lp.iexp+2(a6,a2.l) and mantissa
        sub.l   a4,d2
        sub.w   d2,lp.chpos(a6,a2.l) initial character position
        bra.l   done

range
        move.w  d0,lp.sexp(a6,a2.l) len, exp or val of the index value
        move.l  d1,lp.sexp+2(a6,a2.l) mantissa/chars of the index value
        addq.b  #t.fp,d2        what was the type?
        bcc.s   do_to           not string, so we're happy
        subq.w  #1,d0           is it a single char?
        beq.s   do_to           yes - we understand how to do that
pop4_or
        moveq   #err.or,d0
pop_4
        addq.l  #4,sp
        rts

do_to
        bsr.l   getexpr         get the to value
        move.w  d0,lp.eexp(a6,a2.l) and copy it into the descriptor
        move.l  d1,lp.eexp+2(a6,a2.l)

        addq.b  #t.fp,d2        once again, was it a string?
        bcc.s   dostep
        subq.w  #1,d0
        bne.s   pop4_or

dostep
        moveq   #1,d1           constructing default step of one
        moveq   #1,d0           step int 1 or strlen
        subq.b  #t.fp,d2
        bgt.s   gostep
        blt.s   dorot
        move.w  #$801,d0        fp exp
        moveq   #$40,d1         fp mant (soon)
dorot
        ror.l   #8,d1           position chr$(1) or fp mant $40000000

gostep
        cmp.w   #w.step,0(a6,a4.l) is next token step ?
        bne.s   setstep         nope, use what we just constructed
        addq.b  #t.fp,d2
        bsr.l   getexpr
        tst.b   d2              last time, is is a string?
        bpl.s   setstep
        cmp.w   #1,d0
        bne.s   pop4_or
setstep
        move.l  (sp)+,d3        take off previous pf pos
        sub.l   a4,d3           current pf position
        sub.w   d3,lp.chpos(a6,a2.l) and add the difference to prev ch pos

        tst.b   d2              which type are we doing?
        bgt.s   strtint
        beq.s   strtfp

        move.l  d1,d2
        rol.l   #8,d2
        tst.b   d2
        beq.s   swap6           step zero is good
        spl     d3
        move.b  lp.sexp+2(a6,a2.l),d2
        cmp.b   lp.eexp+2(a6,a2.l),d2
fpset
        bne.s   strint
swap6
        move.l  lp.sexp+2(a6,a2.l),lp.iexp+2(a6,a2.l)
        move.l  d1,lp.sexp+2(a6,a2.l)
swap2
        move.w  lp.sexp(a6,a2.l),lp.iexp(a6,a2.l)
        move.w  d0,lp.sexp(a6,a2.l)
done
        moveq   #0,d0
        rts

strtint
        tst.w   d0
        beq.s   swap2            step zero is good
        spl     d3
        move.w  lp.sexp(a6,a2.l),d2
        cmp.w   lp.eexp(a6,a2.l),d2
        beq.s   swap2
strint
        slt     d2
        eor.b   d2,d3
        bpl.s   swap6
next
        bra.l   ib_frnge

strtfp
        tst.l   d1
        beq.s   swap6           step zero is good
        move.l  d1,-(sp)        save stuff for a moment
        move.w  d0,-(sp)
        jsr     bv_chri(pc)     make sure we've got some space
        move.l  bv_rip(a6),a1
        moveq   #12,d0
        add.l   d0,a2
pushfp
        subq.l  #4,a2           put initial, then end, value on stack
        subq.l  #4,a1
        move.l  lp.eexp(a6,a2.l),0(a6,a1.l)
        subq.w  #4,d0
        bne.s   pushfp
        jsr     ri_cmp(pc)      compare them
        move.w  (sp)+,d0
        move.l  (sp)+,d1
        spl     d3
        move.b  2(a6,a1.l),d2
        bra.s   fpset

* Evaluate one of x, y or z from "for var = x to y step z"
* d2 = var type, d6 = name row, a4 = program 
pop_8
        addq.l  #8,sp
        rts

getexpr
        addq.l  #2,a4           skip the token we just matched
        move.l  a4,a0           beg of expression
        move.b  d2,d0
        jsr     ca_eval(pc)     evaluate it
        move.l  a0,a4           points to 1st non-expression token
        ble.s   pop_8
        bsr.s   ib_indx1        get beg of loop description
        move.w  0(a6,a1.l),d0   len, exp or val of the index value
        bsr.s   formoff         make up a nice adjuster for ri stack
        add.l   d1,bv_rip(a6)
        move.l  2(a6,a1.l),d1   mantissa/chars of the index value
        rts

formoff
        moveq   #2,d1
        subq.b  #t.fp,d2        what is it's type?
        bgt.s   rts1            integer, we're ready
        beq.s   form4p          fp, a bit more to drop
        move.w  d0,d1           copy the length
        subq.l  #4,d1           is it a bit too long?
        bcs.s   formrnd         no, so go round it
        sub.w   d1,d0           truncate to max. four
formrnd
        addq.l  #3,d1           incorporate length and one for rounding
        bclr    #0,d1           round to even
form4p
        addq.l  #4,d1
rts1
        rts

* d0 -  o- found(0) or not (o)
* d1 -  o- 1st byte of nt description
* d2 -  o- 2nd byte of nt description
* d4 -  o- name row
* a2 -  o- pointer to loop description
* a4 -i o- program file

ib_gtlpl
        jsr     ib_nxnon(pc)    get non-space
        move.w  2(a6,a4.l),d4   read name
        addq.l  #4,a4
gtind
        bsr.s   ib_index        get offset on vv of loop description
        moveq   #t.for,d0
        sub.b   d1,d0           is it a FOR
        assert  1,t.for-t.rep
        lsr.b   #1,d0           or a REP?
        beq.s   rts2
        moveq   #err.nf,d0
rts2
        rts

* d0 -  o- vv offset from vvbas
* d1 -  o- 1st byte of name description (name type)
* d2 -  o- 4 lsbs of 2nd byte (variable type)
* d4 -ip - name row
* a2 -  o- beg of vv desc

ib_indx1
        move.w  d6,d4           put_str in eval uses d4 in strings
ib_index
        bsr.s   ib_fname
        move.b  0(a6,a2.l),d1   name type
        moveq   #15,d2
        and.b   1(a6,a2.l),d2   variable type
        move.l  4(a6,a2.l),d0   get value offset
        move.l  bv_vvbas(a6),a2 base of var tab
        add.l   d0,a2           move to beginning of index description
        rts

* d0 -  o- name offset
* d4 -ip - name row
* a2 -  o- beg of name table data

ib_fname
        moveq   #0,d0           (being cautious, don't expect msw 0. lwr)
        move.w  d4,d0
        lsl.l   #3,d0           offset of name entry
        move.l  bv_ntbas(a6),a2
        add.l   d0,a2           point at name entry
        rts

        end
