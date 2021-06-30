* Converts integers to strings
        xdef    cn_itod,cn_itobb,cn_itobw,cn_itobl,cn_itohb,cn_itohw,cn_itohl
        xdef    cn_0tod

        section cn_itos

* Decimal conversion

* d0 -  o- 0
* d1 -  o- length of output number string
* a0 -i o- beginning of string in bottom-up buffer, output at end of number
* a1 -i o- top of arithmetic stack, output with number removed
cn_itod
        move.w  0(a6,a1.l),d0   fetch number
        addq.l  #2,a1

* d0 -i o- lsw = signed value to be printed, return 0
* d1 -  o- length of output number string
* a0 -i o- beginning of string in bottom-up buffer, output at end of number
cn_0tod
        move.w  a0,-(sp)        save start of buffer (only need lsw)
        ext.l   d0
        bpl.s   d_ok            is it negative
        move.b  #'-',0(a6,a0.l) yes - put in minus sign
        addq.l  #1,a0
        neg.l   d0              make number unsigned absolute value
d_ok

        moveq   #1,d1           set flag for last of digits
d_loop
        divu    #10,d0          form remainder=lsdigit and quotient=msdigits
        swap    d0              bring down digit
        ror.l   #1,d1           roll down flag
        move.b  d0,d1           keep digit
        ror.l   #4,d1           roll down digit
        clr.w   d0              discard digit
        swap    d0              bring down remainder
        bne.s   d_loop          loop until no more significant digits left
* We have now got at most five digits and flags tucked away in d1.l, making a
* total of 25 bits. The remaining seven bits are zero. Note d0.l is now zero.
d_put
        addq.b  #'0'>>4,d1      make digit ascii
        rol.l   #4,d1           roll back lsb's of next digit
        move.b  d1,0(a6,a0.l)   put it in output
        addq.l  #1,a0           step on
        sf      d1              clear that digit
        add.l   d1,d1           are there any more digits?
        bcc.s   d_put           until we hit the set flag bit, carry on
        move.w  a0,d1           end of string (d1.msw is zero)
        sub.w   (sp)+,d1        less start = length
        rts

* Hex and binary conversions

* a0 -i o- beginning of string in bottom-up buffer, output at end of number
* a1 -i o- top of arithmetic stack, output with number removed
* d0 destroyed

cn_itohl
        pea     cn_itohw        for long do two words
cn_itohw
        pea     cn_itohb        for word do two bytes
cn_itohb
        move.b  0(a6,a1.l),d0   get first four bits
        lsr.b   #4,d0
        bsr.s   put_hex         put character in buffer

        moveq   #15,d0          get next four bits
        and.b   0(a6,a1.l),d0
        addq.l  #1,a1

put_hex
        add.b   #'0',d0         convert to ascii digit
        cmp.b   #'9',d0         is it greater than 9
        bls.s   put_hex1
        addq.b  #'A'-10-'0',d0  convert to letter a-f
put_hex1
        move.b  d0,0(a6,a0.l)   set digit
        addq.l  #1,a0
        rts

cn_itobl
        pea     cn_itobw        for long do 2 words
cn_itobw
        pea     cn_itobb        for word do 2 bytes
cn_itobb
        moveq   #7,d0           for 8 bits
bit_loop
        btst    d0,0(a6,a1.l)   test bit
        seq     0(a6,a0.l)      set result to -1 for '0', 0 for '1'
        add.b   #'1',0(a6,a0.l) form digit
        addq.l  #1,a0
        dbra    d0,bit_loop
        addq.l  #1,a1           move stack pointer on
        rts

        end
