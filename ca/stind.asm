* String var or exp index on rhs
        xdef    ca_ssind,ca_stind

        xref    ca_cnvrt,ca_etos,ca_putss,ca_range

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ca_stind

* d0 -  o- error code
* a0 -i o- expression pointer
* a1 -i o- ri stack pointer
* a5 -i o- name table entry top
* d1-d3/d5-d6/a3-a4 destroyed

ca_stind
        cmp.b   #t.str,-7(a6,a5.l) is it really a string already?
        beq.s   isstr
        jsr     ca_etos(pc)
        bne.s   rts0
        moveq   #t.str,d0
        jsr     ca_cnvrt(pc)    ho hum... we'll even convert numbers!
*       bne.s   rts0            there's nothing that won't convert to string!
isstr
        bsr.s   ca_ssind        get the indices
        bne.s   rts0            couldn't get indices
        move.l  a1,a4           maybe it's internal already
        move.b  -8(a6,a5.l),d3
        subq.b  #t.intern,d3
        beq.s   ptrset          yep - all set for internal
        move.l  -4(a6,a5.l),d2  string variable offset
        blt.s   err_xp          ouch - unset variable
        move.l  bv_vvbas(a6),a4
        add.l   d2,a4
ptrset
        move.w  0(a6,a4.l),d6   get length
        subq.w  #1,d5
        bcs.s   ready           just want the length, i.e. x$(0)
        cmp.w   d1,d6
        bcc.s   lenset
        move.w  d6,d1
lenset
        sub.w   d5,d1           get length of substring
        bcs.s   err_or
        lea     2(a4,d5.w),a4   pointer to start
ready
        moveq   #t.intern,d2
        move.b  d2,-8(a6,a5.l)  now definately internal
        tst.b   d3
        bne.s   riset           variable is ready
        lea     2(a1,d6.w),a1
        assert  1,t.intern
        and.b   d6,d2
        add.w   d2,a1           round up
        bsr.s   putrip          update ri pointer to drop old stack copy now
riset
        addq.w  #1,d5           were we doing length only
        bcc.l   ca_putss        no - go put substring on stack
* N.B. putss never needs any space if the string was already internal, and its
* move is non-destructive, so it'll always work ok.

* Note: we evaluated a zero index and removed it, so ri must have space for int
        addq.b  #t.int-t.str,-7(a6,a5.l) now it becomes an integer!
        subq.l  #2,a1
        move.w  d6,0(a6,a1.l)
putrip
        move.l  a1,bv_rip(a6)
        moveq   #0,d0
rts0
        rts

err_or
        moveq   #err.or,d0
        rts

err_xp
        moveq   #err.xp,d0
        rts

* d0 -  o- error code
* d1 -  o- as d6, except default is still left as -1
* d5 -  o- lower index (1..32767 or 0) (msw preserved)
* d6 -  o- upper index found (no check, except d5=0->d6=0) (msw preserved)
* a0 -i o- expression pointer
* a1 -i o- ri pointer
* d2-d3/a3-a4 destroyed

* Enhanced to accept "a$='x':a$=a$(2to 1)", i.e. null slice at end.
* Also now sensibly accepts a$(to ...) as defaulting to a$(1to ...).
* For the moment, we only baulk at a$(32768to{ 32767})!

ca_ssind
        subq.l  #2,a0           we like to start early...
        jsr     ca_range(pc)    go get subscript range
        bne.s   rts0
        move.w  d1,d6
        bpl.s   topok
        lsr.w   #1,d6           change defaulted end (-1) to max (32767)
topok
        cmp.w   d5,d6
        beq.s   rangeok         allows through special cases of (0) or (0to 0)
        tst.w   d5
        beq.s   err_or          if zero gets here, it's no good, mixed len/char
        bgt.s   rangeok         start > 0 is good
        addq.w  #2,d5           if defalted start (-1), change it to 1
rangeok
        cmp.w   #w.cpar,0(a6,a0.l) we rather hope this is a close parenthesis
        bne.s   err_xp
        addq.l  #2,a0           we can move over close bracket now
        rts

        end
