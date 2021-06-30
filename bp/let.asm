* Do let assignments from RI to VV
        xdef    bp_let,bp_alvv

        xref    bv_alvv,bv_frvv,bv_uplet

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_nt'

        section bp_let

* d0 -  o- 0 (this routine doesn't believe in errors!)
* d5 -ip - low limit, if assigning to a substring of a simple string variable
* d6 -ip - high limit, ditto
* a1 -  o- RI stack pointer
* a2 -ip - VV area, if assigning to a substring of a simple string variable
* a3 -ip - pointer to NT entry
* d1-d2 destroyed

reg_let reg     d4/a0/a3-a5

bp_let
        movem.l reg_let,-(sp)
        moveq   #15,d0
        and.b   1(a6,a3.l),d0   mask seps
        tst.b   bv_uproc(a6)    is there a user trace procedure?
        bpl.s   noup
        jsr     bv_uplet(pc)    yes - go see to it
noup
        bsr.s   main
        add.l   d1,a1
        move.l  a1,bv_rip(a6)
        movem.l (sp)+,reg_let
        moveq   #0,d0
        rts

* Assign a floating point to var or array

let_fp
        moveq   #6,d1           entry should be 6 bytes long
        bsr.s   ch_off          get the space
        move.l  2(a6,a1.l),2(a6,a0.l) copy mantissa
        bra.s   int_fp

main
        moveq   #2,d1           2 bytes needed for integer, and clear msw
        subq.b  #t.fp,d0
        bmi.s   let_str         assign to a string of some sort
        beq.s   let_fp          assign to floating point
        bsr.s   ch_off          check it has a value pointer
int_fp
        move.w  0(a6,a1.l),0(a6,a0.l) put 1st word into VV area
ch_type
        moveq   #t.var,d0
        cmp.b   0(a6,a3.l),d0   look at variable type
        ble.s   rts0            vt already set
        move.b  d0,0(a6,a3.l)   set variable type to simple var
rts0
        rts

ch_off
        move.l  4(a6,a3.l),d4   current offset on VV table
        bpl.s   get_pos         ..it's all right

* d0 -  o- 0
* d1 -ip - space required from VV area
* d4 -  o- VV offset of new space
* a0 -  o- rel a6 address of new space
* a1 -  o- RI stack pointer (a bonus!)
* a3 -ip - NT entry to receive space

bp_alvv
        jsr     bv_alvv(pc)     get the required space & set a1=bv_rip(a6)
        move.l  a0,d4
        sub.l   bv_vvbas(a6),d4 get the offset
        move.l  d4,4(a6,a3.l)   and fill it in
        rts

cht_get
        bsr.s   ch_type

* Get positions of assignee & assignor

* a0 -  o- VV position of destination string
* a1 -  o- RI pointer of source string
* d4 -i  - offset of array values on VV

get_pos
        move.l  bv_vvbas(a6),a0
        add.l   d4,a0
        move.l  bv_rip(a6),a1
        rts

* Assign a string to something

let_str
        move.l  bv_rip(a6),a1
* We rather assume that the given string length is sensible!
        move.w  0(a6,a1.l),d1   length of string to be assigned

        cmp.b   #t.arr,0(a6,a3.l) is this an array?
        bne.s   str_var         no - go for string varible

        move.l  4(a6,a3.l),a0   get descriptor offset
        add.l   bv_vvbas(a6),a0
        move.w  6(a6,a0.l),d2   max length to replace
        move.l  0(a6,a0.l),d4   where to start replacement
        bsr.s   set_par         get max copy and blank fill
        bsr.s   get_pos         get source and destination bases
        addq.b  #t.fp,d0
        beq.s   str_ret         no length if a substring of a string array
* There was a strange anomaly here... for some reason there was an extra
* comparison of the copy length with the source length... it did nothing, but
* it looked as if it was meant to compare against the current length of the
* destination, then cause it to only expand in length. Wierd!
* Another thing it could have been an attempt at acheiving may have been to
* only blank fill to the extent of old length, which might make some sense, if
* string arrays were initially set to blanks... unfortunately, we now come up
* against compatability again. It would speed things up no end if we could
* scrap the blank filling, but I guess we're stuck with it!
        bra.s   put_len         go duplicate copy length

str_norm
        addq.l  #1,d1
        bclr    #0,d1           round up assign length to even
        move.w  0(a6,a0.l),d0   get length of current string
        addq.l  #1,d0
        bclr    #0,d0           rounded up to even

        move.l  d0,d2
        eor.l   d1,d0           any chance that old & new space is the same?
        lsr.l   #3,d0           (we know VV space is in multiples of eight)
        beq.s   fill_str        VV space is right mult of 8, so leave it

        addq.l  #2,d2           total amount to free, a0 already set
        exg     d2,d1           save d1, and set amount to release
        jsr     bv_frvv(pc)
        move.l  d2,d1           restore d1
crt_str
        addq.l  #2,d1           entry must be length of string + 2
        bsr.s   bp_alvv         allocation will round up any odd byte
fill_str
        bsr.s   cht_get         check out variable type and get a0,a1
        moveq   #0,d2           nothing to blankfill on a0
        move.w  0(a6,a1.l),d1   get source length again
put_len
        move.w  d1,0(a6,a0.l)   set destination length
str_len
        addq.l  #2,a0           pos to start replacing at
str_ret
        move.w  0(a6,a1.l),d0   get length (we know msw is zero)
        addq.l  #2,a1           move a1 past length word
        add.l   a1,d0           set to end of text
        bra.s   s_copy          do the copy

* Check copy length fits into space

* d1 -i o- new chars available / number to copy from RI stack to VV area
* d2 -i o- space available / amount of VV area to blankfill after copy

set_par
        sub.w   d1,d2           will new chars fit into old space?
        bhi.s   rts1            yes - fine
        add.w   d2,d1           set amount to copy
        moveq   #0,d2           and blank fill nothing
rts1
        rts

str_var
        addq.b  #t.fp,d0        string or sub-string
        beq.s   let_sst         ..substring (only allowed direct from let)

        move.l  4(a6,a3.l),d4   current offset on VV
        blt.s   crt_str         ..isn't one, have to make one

        move.l  bv_vvbas(a6),a0
        add.l   d4,a0

* This is it! We must not screw up rep/for string variable, which has max len
* of 4 chars. If assigning to such, truncate anything longer than four chars.
* An alternative would be to scrap their rep/for status...
* While we're doing this, we can get the spinoff of quick assigns to others.

        assert  0,t.var-2,t.arr-3,t.rep-6,t.for-7
        moveq   #4,d0
        cmp.b   0(a6,a3.l),d0   is this string a rep/for index?
        bgt.s   str_norm        no - go do normal strings
        cmp.w   d1,d0           what's the source string length then?
        bcs.s   truncit         bother... longer than four
        move.w  d1,d0           use short strings as they come
truncit
        move.w  d0,0(a6,a0.l)   set variable length
        move.l  2(a6,a1.l),2(a6,a0.l) copy 4 bytes regardless
        addq.l  #3,d1
        bclr    #0,d1           round up for the space to release on RI stack
        rts

* Assign a string to a substring of a string variable

let_sst
        addq.b  #t.str,1(a6,a3.l) reset type to string (it was zero before)
        move.w  d5,a0
        subq.l  #1,a0           offset to first char to replace
        move.w  d6,d2
        sub.w   a0,d2           destination space available
        add.l   a2,a0
        bsr.s   set_par         gives d1,d2
        bra.s   str_len         go copy after stepping past length

* Copy string characters

* d0 -  i- offset to end of text of RI stack string
* d1 -i o- no of chars to copy from RI stack to VV area / addend for a1
* d2 -i  - no of chars on VV area to blank fill
* a0 -i o- VV pos to copy to
* a1 -i o- RI pointer to source string, string removed except for d1

copy_lp
        move.b  0(a6,a1.l),0(a6,a0.l) copy a character
        addq.l  #1,a0           step VV
        addq.l  #1,a1           step RI
s_copy
        dbra    d1,copy_lp
        moveq   #' ',d1
        bra.s   b_fill

fill_lp
        move.b  d1,0(a6,a0.l)   blank one character
        addq.l  #1,a0           step VV
b_fill
        dbra    d2,fill_lp
        move.l  d0,a1           replace with end of text
        moveq   #1,d1
        and.b   d0,d1           chars (0/1) left before end of string
        rts

        end
