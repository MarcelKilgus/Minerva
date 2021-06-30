* do a SELect
        xdef    ib_sel

        xref    bv_chrix
        xref    ca_eval
        xref    ib_chinl,ib_eos,ib_fchk,ib_index,ib_nxcom,ib_nxnon,ib_s2non
        xref    ri_cmp
        xref    ut_csstr

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ib_sel

* d0 -  o- error code
* a4 -i o- program file pointer
* d0-d6/a0-a2 destroyed

* Locally:
* d3 - nest level
* d4 - name row
* d5 - variable type
* d6 - string length, fp exponent or integer value
* a1 - ri stack
* a2 - vv offset to string, fp mantissa or unused

ib_sel
        jsr     ib_nxnon(pc)
        cmp.w   #w.on,d1
        bne.s   nametok
        jsr     ib_s2non(pc)    don't need it
nametok
        move.l  0(a6,a4.l),d4   read name row, and keep msw as w.nam
        jsr     ib_index(pc)    find its value (d0=offset, d1=use, d2=type)
        bge.s   valok           ok if the offset is >= 0
err_xp
        moveq   #err.xp,d0
        rts

valok
        move.b  d2,d5           set variable type
        subq.b  #t.arr,d1       we need to catch (sub)string arrays
        bne.s   simple          (too bad if it's some silly type)
        move.w  6(a6,a2.l),d6   possible sub-string length
        assert  0,t.str-1,t.fp-2,t.int-3
        moveq   #t.str,d3
        cmp.w   4(a6,a2.l),d3
        bne.s   err_xp          one dimension only
        move.l  0(a6,a2.l),a2   get VV offset to data
        cmp.b   d3,d2
        bhi.s   err_xp          don't allow fp/int arrays (d2 now -1)
        bne.s   all_set         substring is ready now
        move.l  a2,d0           save the offset           
        add.l   bv_vvbas(a6),a2 need to pick up length of string
simple
        movem.l -2(a6,a2.l),d6/a2 pick up length, exponent+mantissa or integer
        subq.b  #t.fp,d2
        bcc.s   all_set         ready except for string
        move.l  d0,a2           put back just the offset
        addq.l  #2,a2           step past the length
all_set
        clr.w   d3              set nest level zero
        tst.b   bv_inlin(a6)    are we already embedded?
        bne.s   entry           yes, leave it as is
        jsr     ib_chinl(pc)    is this now an in-line clause?
        blt.s   entry           no, get on with it
        st      bv_inlin(a6)    only set to -1 if not already set
        bra.s   entry

* find an ON (or =) for a SELect, or drop out at END SELect, etc.

skipto
        jsr     ib_nxcom(pc)    skip over "TO expr", looking for a comma
nextrnge
        cmp.w   #w.symcom,0(a6,a4.l) is token a comma?
        beq.s   onrng           yes, then the list carries on
        moveq   #-1,d3          reset count of nested sels
add1
        addq.w  #1,d3
nxstat
        jsr     ib_fchk(pc)     find next statement and check it
        bne.s   chklev          not starting with a keyword
        subq.b  #b.end,d1       is it END?
        beq.s   do_end
        subq.b  #w.sel-w.end,d1 is it SELect?
        beq.s   do_sel
        assert  1<<4,w.on-w.sel
        roxl.b  #4,d1           is it ON?
        bne.s   nxstat
        jsr     ib_s2non(pc)    skip the ON and get the next thing
        cmp.l   0(a6,a4.l),d4   is it a name, and the same name?
        bne.s   nxstat
entry
        addq.l  #4,a4           move over name, now we may find '='
        ;                       (this could still be ON <expr> GO)
        jsr     ib_nxnon(pc)
chklev
        tst.w   d3              is count equal to zero
        bne.s   nxstat          carry on if nested
chkeq
        cmp.w   #w.equal,d1     is first, or after "{SEL} ON <name>", an = ?
        bne.s   nxstat          no

* check on range against value
onrng
        jsr     ib_s2non(pc)    skip token and look for range
        cmp.w   #w.rmndr,d1     REMAINDER ?
        beq.s   okrts
        bsr.s   eval            read lower or only limit
        cmp.w   #w.keyto,0(a6,a4.l)
        beq.s   do_to
        sf      d1
        moveq   #3,d0           (string comparison type is ==)
        bsr.s   docmp           check for a1==a2
qgood
        bne.s   nextrnge
okrts
        moveq   #0,d0
        rts

do_sel
        tst.b   bv_inlin(a6)    are we in-line already?
        bne.s   add1            yes, inc nest count, else skip over whole line
        jsr     ib_chinl(pc)    select in-line?
        bne.s   add1            no, inc nest count
loop
        addq.l  #2,a4           move over the token
        jsr     ib_eos(pc)      get end of statement
        bge.s   loop            if not end of line, try again
        bra.s   nxstat

do_end
        jsr     ib_s2non(pc)    step past end
        cmp.w   #w.sel,d1       END SELect?
        bne.s   nxstat
        dbra    d3,nxstat       yes, drop a level and continue if still nested
        bra.s   okrts           found an END SELect or nothing

do_to
        moveq   #1,d1
        bsr.s   docmp2          check for a2>=a1
        bne.l   skipto          failed first part of range
        addq.l  #2,a4           skip to
        bsr.s   eval            get upper limit
        st      d1
        bsr.s   docmp2          check for a2<=a1
        bra.s   qgood

eval
        move.l  a4,a0
        move.l  a2,-(sp)
        move.b  d5,d0
        jsr     ca_eval(pc)     read limit
        move.l  (sp)+,a2
        move.l  a0,a4
        bgt.s   rts1
        addq.l  #4,sp           give up if there's any problem in eval
        rts

docmp2
        moveq   #2,d0           (string comparison type is <= or >=)
docmp
        cmp.b   #t.fp,d5        which type are we doing?
        beq.s   comfp
        blt.s   comstr

* right... integer select, do it!
        addq.l  #2,bv_rip(a6)   discard integer
        cmp.w   0(a6,a1.l),d6   check against on variable value
        beq.s   rts1            equal is always good
        slt     d3              set flag
        subq.b  #1,d1           were we looking for equality?
        bcs.s   rts1            yes - then this is no good
eorb
        eor.b   d3,d1           this establishes the sign bit as what we want
        asr.b   #7,d1           so this is the answer!
rts1
        rts

comfp
        move.b  d1,d3           save comparison type
        moveq   #6,d1
        jsr     bv_chrix(pc)    gotta make sure of space
        move.l  bv_rip(a6),a1   reload pointer
        addq.l  #6,bv_rip(a6)   discard comparand from bv_rip
        subq.l  #6,a1           make space for our comparison
        move.l  a2,2(a6,a1.l)   copy mantissa
        move.w  d6,0(a6,a1.l)   copy exponent
        jsr     ri_cmp(pc)      calculate comparison (this is nice, saves d3)
        neg.b   d3              check comparison type
        bne.s   frel            not zero means we want to test <= and >=
        tst.b   0(a6,a1.l)      msb exponent is 0 if == true, otherwise 8
        rts

frel
        move.b  2(a6,a1.l),d1   get msb mantissa which will be $80, 0 or $40
        bne.s   eorb            if not zero, we go to eor signs for answer
        rts                     if zero, this is an exact =, which is fine

comstr
        moveq   #0,d2
        move.w  0(a6,a1.l),d2
        addq.l  #3,d2
        bclr    #0,d2
        add.l   d2,bv_rip(a6)   discard string on RI stack
        move.l  a2,a0
        add.l   bv_vvbas(a6),a0
        move.w  d6,d2
        jsr     ut_csstr(pc)
        beq.s   rts1            equal is always great
        cmp.b   d0,d1           otherwise compare it to comparison type
        rts

        end 
