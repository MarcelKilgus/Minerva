* Convert a string to a number
        xdef    cn_dtof,cn_dtoi
        xdef    cn_htoib,cn_htoiw,cn_htoil
        xdef    cn_btoib,cn_btoiw,cn_btoil

        xref    ri_add,ri_div,ri_fllin,ri_mult,ri_neg,ri_power,ri_zero

        include 'dev7_m_inc_err'

        section cn_ston

* Because too many people expected the old, slack definition of what a floating
* point number can look like, the definition here now accepts a total lack of
* valid digits as a complete number, value zero.
* We now accept: {+|-}{<digitlist>}{.<digitlist>}{{E|e}{+|-}<digitlist>}
* I.e. "." is accepted as zero, as is a null string.
* We also stop the number on a second decimal point, rather than treating that
* as an error.

* d0 -  o- error code
* d7 -i  - points to byte after string (may be a0-1, etc to show as infinite)
* a0 -i o- points to beginning of string in bottom-up buffer
* a1 -i o- points to last pos in top-down arithmetic stack
* d1-d2 destroyed

reglist reg     d3-d6/a0-a1

put_10
        moveq   #10,d1
put_d
        jmp     ri_fllin(pc)

* Decimal to floating point
cn_dtof
        movem.l reglist,-(sp)   save a0,a1 because i'm going to use 'em
        jsr     ri_zero(pc)     push zero onto stack
        bsr.l   get_sign        get the sign (if any)
        move.w  a0,d5           remember where we start
decpt
        move.w  a0,d4           remember position after decimal point
        bra.s   nxfchr          enter loop

add_fdig
        bsr.s   put_10          put 10 on stack
        jsr     ri_mult(pc)
        bne.s   cn_errne
        move.l  d6,d1
        bsr.s   put_d           put new digit on stack
        jsr     ri_add(pc)      add it to the running total (can't overflow!)
nxfchr
        bsr.l   fetch_d         get next digit
        bcs.s   add_fdig        go add digit
        addq.b  #'0'-'.',d6     yes, is it a dot?
        bne.s   fp_sgn
        cmp.w   d4,d5           have we already had a decimal point?
        beq.s   decpt           no, so go remember this position
fp_sgn
        tst.l   d5              was it negative?
        bpl.s   man_ok
        jsr     ri_neg(pc)      yes - negate
man_ok
        sub.w   d5,d4           was there a decimal point?
        beq.s   exp_set         no - exponent set
        addq.w  #1,d5           allow for decimal point from char count
        add.w   d5,d4
        sub.w   a0,d4           get -ve decimal places
exp_set
        moveq   #0,d3           set e-exponent to zero
        addq.w  #1,d5           we have moved past the last character
        cmp.w   a0,d5           make sure we got at least one digit
        beq.s   nodigs          oops. no digits, go see what we HAVE got
        cmp.b   #'E'-'.',d6     E (or e)?
        bne.s   exp_end
        bsr.s   dtoi            yes - read integer into d3
        beq.s   exp_end
        bne.s   cn_error

nodigs
        add.l   d5,d5           did we have a sign?
        bmi.s   cn_bum          yes - that's bad
; we ONLY accept pure blanks as a valid number (0)

exp_end
        add.w   d3,d4           total power of ten
        bvs.s   cn_bum          could just happen - we don't want to mess up!
        beq.s   cn_end          if zero, no point raising 10 to it
        move.w  d4,d5           set exponent sign flag
        bpl.s   power
        neg.w   d4              has to be pos for routine
power
        bsr.s   put_10          put 10 on stack
        subq.l  #2,a1
        move.w  d4,0(a6,a1.l)   put positive power on stack
        jsr     ri_power(pc)    and get 10 to the exp
        bne.s   cn_error
        tst.w   d5              negative exponent?
        bpl.s   mult

        jsr     ri_div(pc)      yes - calculate number/10^exp
        bra.s   cn_errne

mult
        jsr     ri_mult(pc)     no - calculate number*10^exp
cn_errne
        bne.s   cn_error
cn_end
        subq.l  #1,a0           back up over the character we stopped on
        movem.l (sp)+,d3-d6     restore the status quo
        addq.l  #8,sp           ignore saved a0,a1
        moveq   #0,d0           good return
        rts

spaces
        addq.l  #1,a0           move to next character
get_sign
        moveq   #' ',d5         clear flags and set useful value
        cmp.l   a0,d7           end of string?
        beq.s   rts0            yes - later bits will fail
        cmp.b   0(a6,a0.l),d5   is it a space?
        beq.s   spaces
        moveq   #'+',d6         compare char against '+'
        sub.b   0(a6,a0.l),d6
        beq.s   bump
        addq.b  #'-'-'+',d6     ... and against '-'
        bne.s   rts0
bump
        moveq   #-1,d5          use msw set for either sign seen flag
        roxr.l  #1,d5           set bit 31 for minus sign, bit 30 set if either
        addq.l  #1,a0           remove accepted sign character
        rts

* Integer conversion
dtoi
        bsr.s   get_sign
        bsr.s   fetch_d         fetch first character
        exg     d3,d6           set running total
        bcs.s   in_ent          first must be a digit
in_error
        addq.l  #4,sp           discard return
cn_bum
        moveq   #err.xp,d0
cn_error
        movem.l (sp)+,reglist
        rts

in_accum
        mulu    #10,d3          multiply running total by 10
        swap    d3
        tst.w   d3              make sure nothing creeps into msw
        bne.s   in_error
        swap    d3
        add.l   d6,d3           add digit
in_ent
        bsr.s   fetch_d         fetch next digit
        bcs.s   in_accum        go accumulate digits
        tst.l   d5              is it really negative?
        bpl.s   no_neg
        neg.l   d3              yes - negate it
no_neg
        move.w  d3,d5
        ext.l   d5
        sub.l   d3,d5
        bne.s   in_error        must have been out of range
        rts

fetch_d
        moveq   #'0',d6         clear msb's of d6
        cmp.l   a0,d7           a0 going off end?
        addq.l  #1,a0           always move on a character
        beq.s   clearc          clear carry to show nowt left
        neg.b   d6
        add.b   -1(a6,a0.l),d6  fetch possible digit value
        bmi.s   clearc          clear carry and it might be a decimal point
        cmp.b   #10,d6          is it really a decimal digit
        bcs.s   rts0            yes, then return with carry set to say so
        and.b   #$df,d6         convert rejects to upper case (hex or exp)
clearc
        and.b   d6,d6           clear carry flag
rts0
        rts

* Convert decimal string to integer
cn_dtoi
        movem.l reglist,-(sp)   save registers consistent with cn_dtof
        bsr.s   dtoi            convert
        bne.s   cn_error        bad return
        subq.l  #2,a1
        move.w  d3,0(a6,a1.l)   good return - put result on stack
cn_end1
        bra     cn_end

* Hex to byte, word or long integer
cn_htoib
        moveq   #2,d2           2 hex characters only
        bra.s   htoi

cn_htoiw
        moveq   #4,d2           4 hex characters only
        bra.s   htoi

cn_htoil
        moveq   #8,d2           8 hex characters

htoi
        movem.l reglist,-(sp)   save registers consistent with cn_dtof
        move.l  d2,d4           put number of bytes in result in d4
        lsr.b   #1,d4
        subq.l  #2,a1
        move.b  d4,1(a6,a1.l)   .. then put on stack
        move.b  #15,0(a6,a1.l)  put maximum digit value on stack
        moveq   #4,d4           put shift in d4

hxb_ent
        move.l  d2,d5           put maximum character count in d5
        moveq   #0,d3           initialise value
hxb_loop
        bsr.s   fetch_d         get next character (digit)
        bcs.s   hxb_add         add this digit
        sub.b   #'A'-'0',d6     check for >= A (or 'a')
        blt.s   hxb_end
        add.b   #10,d6          set to hex letter value
hxb_add
        cmp.b   0(a6,a1.l),d6   check digit against maximum value
        bhi.s   hxb_end
        lsl.l   d4,d3           shift number up
        add.l   d6,d3           .. and add next digit
        dbra    d2,hxb_loop     .. take next digit
        bra.s   hxb_err         too many digits

hxb_end
        move.b  1(a6,a1.l),d4   retrieve number of bytes in result
        addq.l  #2,a1           remove maximum digit from stack
        move.l  d3,-4(a6,a1.l)  put result on stack
        sub.l   d4,a1           adjust stack pointer for different lengths
        cmp.w   d2,d5           check if any digits found
        bgt.s   cn_end1
hxb_err
        bra.l   cn_bum

* Binary to byte, word or long integer
cn_btoib
        moveq   #8,d2           8 bin characters only
        bra.s   btoi

cn_btoiw
        moveq   #$10,d2         16 bin characters only
        bra.s   btoi

cn_btoil
        moveq   #$20,d2         32 bin characters

btoi
        movem.l reglist,-(sp)   save registers consistent with cn_dtof
        move.l  d2,d4           put number of bytes in result in d4
        lsr.b   #3,d4
        subq.l  #2,a1
        move.b  d4,1(a6,a1.l)   .. then put on stack
        moveq   #1,d4           put shift in d4
        move.b  d4,0(a6,a1.l)   .. put maximum value (=shift) on stack
        bra.s   hxb_ent

        end
