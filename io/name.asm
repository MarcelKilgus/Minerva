* Parses a device name in standard format
        xdef   io_name

        xref   cn_dtoi

        include 'dev7_m_inc_err'

        section io_name

* d0 -  o- error code
* a0 -ip - pointer to name, prefixed with word character count
* a3 -ip - pointer to result parameter block
* d1-d3/a1-a2 destroyed (in fact, d3 is preserved, but documentation says not!)
reglist reg d4/d7/a0/a3-a4

io_name
        move.l  (sp)+,a2        basic return address taken off stack
        movem.l reglist,-(sp)   save useful registers
        lea     6(a2),a4        find start of description
        moveq   #0,d7           set up end of string address
        move.w  (a0)+,d7        fetch string length
        add.l   a0,d7           add start address of string

        move.w  (a4)+,d2        find number of characters in name
        moveq   #1,d4
        and.b   d2,d4           remember if length is odd
        moveq   #err.nf,d0      ready for name not recognised
name_lp
        bsr.s   fetch           get next character
        cmp.b   (a4)+,d1        how about it
        bne.s   exit
        subq.w  #1,d2
        bne.s   name_lp

        add.w   d4,a4           round up to get word boundry
        move.w  (a4)+,d4        set up number of options
        bra.s   end_opt

chk_opt
        move.b  (a4)+,d1        check next option type
        beq.s   char_lst
        blt.s   no_sep

sep
        bsr.s   fetch           fetch next character
        cmp.b   (a4)+,d1        is the right separator?
        beq.s   read_val
        subq.l  #1,a0           reset name pointer
        move.w  (a4)+,(a3)+     put default on
        bra.s   end_opt

no_sep
        addq.l  #1,a4           move definition pointer on
read_val
        move.w  (a4)+,(a3)+     put default in result
        move.l  a6,-(sp)        save base register
        sub.l   a6,a6           dtoi is double register addressed
        move.l  a3,a1           succesful dtoi will overwrite default
        jsr     cn_dtoi(pc)     fetch integer
        move.l  (sp)+,a6
        bra.s   end_opt

char_lst
        moveq   #0,d2
        move.b  (a4)+,d2        fetch number of possible characters
        add.w   d2,a4           goto end of list
        move.l  a4,-(sp)        save it!
        moveq   #1,d1
        and.b   d2,d1
        add.l   d1,(sp)         round saved pointer up to even
        bsr.s   fetch           get character
char_lop
        cmp.b   -(a4),d1        check this character
        beq.s   char_fnd
        sub.w   #1,d2           decrement counter (character number)
        bne.s   char_lop
        subq.l  #1,a0
char_fnd
        move.w  d2,(a3)+        put character value in result
        move.l  (sp)+,a4        point to next bit of definition

end_opt
        dbra    d4,chk_opt      look at next option

        addq.l  #2,a2           move return address by two
        moveq   #err.bn,d0      bad parameter(s)
        cmp.l   a0,d7           should now be pointing at end
        bne.s   exit
        addq.l  #2,a2           move return address by a further two
        moveq   #0,d0           wow! all ok
exit
        movem.l (sp)+,reglist   restore all registers
        jmp     (a2)

fetch
        cmp.l   d7,a0           check if off end of buffer
        scs     d1              set $ff if still in buffer, 0 otherwise
        and.b   (a0)+,d1        fetch next character (0 iff off buffer)
        cmp.b   #'_'+1,d1       is it outside TTY set
        blt.s   rts0            .. no
        sub.b   #' ',d1
rts0
        rts

        end
