* Convert floating point to string
        xdef    cn_ftod

        xref    ri_neg,ri_div,ri_mult,ri_n_b
        xref    cn_0tod

ndigs   equ     7
maxint  equ     10000000        10 ^ 7
fptiny  equ     $07ed 431bde81  10 ^ 7-13       highest*1e13 < 1.91e7
fplow   equ     $08184c4b 4000  10 ^ 7          highest > 1e7
fphigh  equ     $081b5f5e 1000  10 ^ 7+1        highest/10 > 1e7
fphuge  equ     $0843 56bc75e3  10 ^ 7+13       highest/1e13 > 1.47e7

* The technique used is to adjust the input value until it is greater than
* 10^ndigs by factor of less than about 10.
* This uses repeated scaling by 10 or 10^13 (the largest exact fp power of 10).
* The resultant 8 digit integer (maybe squeaking to 9 digits) is then ready to
* divide by ten once (or maybe twice, on a bad day) and the remainder can be
* used to round the value (if it glitches over maxint, another divide by 10).
* The seven digits are used to build the output string.

        section cn_ftod

* d0 -  o- 0
* d1 -  o- number of characters in string
* a0 -i o- start of string buffer, output at end
* a1 -i o- arithmetic stack, float removed
reglist reg     d2-d4

cn_ftod
        movem.l reglist,-(sp)
        move.w  a0,-(sp)        only need lsw to calculate length

        moveq   #0,d4           set exponent
        move.l  2(a6,a1.l),d0   check mantissa
        bgt.s   redent          positive is ok
        beq.l   zero            zero is a special case
        move.b  #'-',0(a6,a0.l) put negative in
        addq.l  #1,a0
        jsr     ri_neg(pc)      negate (will make it strictly positive)
        bra.s   redent

put_10
        subq.w  #1,d4           take one from exponent
        moveq   #10,d0
        jmp     ri_n_b(pc)

rep13
        move.w  #$82c,0(a6,a1.l) 1e13 = largest power of 10 with exact fp
        move.l  #$48c27395,2(a6,a1.l)
        sub.w   #13-1,d4        take additional from exponent
        rts

redloop
        bsr.s   put_10          divide by ten or ...
        cmp.w   #fphuge,0(a6,a1.l)
        ble.s   godiv
        bsr.s   rep13           ... 1e13 if it is huge
godiv
        jsr     ri_div(pc)
redent
        cmp.l   #fphigh,0(a6,a1.l) have we got less than ndigs+2 yet?
        bgt.s   redloop         no - divide down by something
        neg.w   d4              negate exponent for proper value
increase
        cmp.l   #fplow,0(a6,a1.l) have we got at least ndigs+1 yet?
        bgt.s   integer         yes - go do integer calcs now
        bsr.s   put_10          multiply by 10 or ...
        cmp.w   #fptiny,0(a6,a1.l)
        bgt.s   gomul
        bsr.s   rep13           ... 1e13 if it was tiny
gomul
        jsr     ri_mult(pc)
        bra.s   increase        try again

divl_10
        moveq   #0,d0

        swap    d1
        move.w  d1,d0           get msw of number
        divu    #10,d0          divide it by 10
        move.w  d0,d1

        swap    d1              msw of quotient ready
        move.w  d1,d0           now remainder of 1st div and lsw of number
        divu    #10,d0          divide this by 10
        move.w  d0,d1           whole of quotient ready

        swap    d0              leave remainder in lsw
        addq.w  #1,d4           say we've done it
        rts

integer
        moveq   #31,d0          convert reduced fp to integer
        sub.w   0(a6,a1.l),d0   find shift
        move.l  2(a6,a1.l),d1   get mantissa
        lsr.l   d0,d1           shift it (will be 4..7 shifts)
        move.l  #maxint,d2      this is number we want to finish below

round
        bsr.s   divl_10         divide by 10
        cmp.l   d2,d1           is it more than ndigs digits
        bge.s   round           this should happen one in about 64k times

        subq.b  #5,d0           is remainder >= 5
        bmi.s   remok           no - that's ok then
        addq.l  #1,d1           round up
        cmp.l   d2,d1           that might just sneak over ...
        blt.s   remok           nope... that's ok
        bsr.s   divl_10         one in a million times!
remok

        addq.w  #ndigs+1,a0     convert digits leaving one space for dp
        moveq   #ndigs-1,d2
        moveq   #'0',d3
con_dig
        bsr.s   divl_10         divide by 10
        add.b   d3,d0           add ascii '0' to remainder to make char
        subq.l  #1,a0
        move.b  d0,0(a6,a0.l)   put char in string
        dbra    d2,con_dig

* Check if exponent is required

        move.l  a0,d2           copy buffer pointer for leading char move
        addq.l  #ndigs,a0       move a0 to last char of string
        moveq   #1,d0           no exponent required? (also d0.msw=0)
        cmp.w   #ndigs,d4       is exponent too small or large?
        bcs.s   dp_end          0..ndigs-1 then we're in business
        move.w  d4,d0           exponent required, dp after after 1st digit
        moveq   #0,d4           just move the first character
dp_loop
        move.b  0(a6,d2.l),-1(a6,d2.l) move leading characters down
        addq.l  #1,d2
dp_end
        dbra    d4,dp_loop
        moveq   #'.',d1         dp
        move.b  d1,-1(a6,d2.l)  put dp into string
zer_loop
        subq.l  #1,a0
        cmp.b   0(a6,a0.l),d3   is trailing digit a zero?
        beq.s   zer_loop        ... yes check next
        cmp.b   0(a6,a0.l),d1   is last char now the dp
        beq.s   put_exp         yes - ignore it
        addq.l  #1,a0           no  - include it
put_exp

        subq.w  #1,d0           was exponent required
        beq.s   exit            ... no (now d0.l=0)
        move.b  #'e',0(a6,a0.l) ... yes put in e
        addq.l  #1,a0
zero
        jsr     cn_0tod(pc)     convert to string
exit
        addq.l  #6,a1           remove fp from stack
        move.w  a0,d1           get end pointer (we have d1.msw=0 here)
        sub.w   (sp)+,d1        take away start to give length of string
        movem.l (sp)+,reglist
        rts

        end
