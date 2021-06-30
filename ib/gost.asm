* Go to start/end of statement
        xdef    ib_eos,ib_gost,ib_nxst

        xref    ib_steof

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_token'

        section ib_gost

* d0 -  o- 0
* d4 -ip - statement no on this line to go to
* a4 -i o- program file (may not move if already there)
* ccr always z

goeos
        addq.l  #2,a4           skip over colon etc
        addq.b  #1,bv_stmnt(a6) and increment satement number
ib_gost
        cmp.b   bv_stmnt(a6),d4 are we there?
        ble.s   okrts
        bsr.s   ib_eos          find the end of current statement
        bge.s   goeos           not yet
        bra.s   okrts           end of line

* a4 -i o- pf pointer - doesn't change iff already at eol
* d0 - lo- 0 if statement is not on a new line, 1 new pf line, -1 end of single
* ccr z if there is a next statement, +ve if off end of pf, -ve end of single
* (d1.l was zeroed only on a valid new line being started - preserved now)

ib_nxst
        bsr.s   ib_eos          get end of this statement
        blt.s   atlf            found line feed
        addq.l  #2,a4           skip colon/then/else
        addq.b  #1,bv_stmnt(a6) increment statement on line
okrts
        moveq   #0,d0
        rts

atlf
        tst.b   bv_sing(a6)
        bne.s   rts0
        addq.l  #8,a4           skip line feed, len change and line number
        cmp.l   bv_pfp(a6),a4   gone past end of file?
        bgt.l   ib_steof        returns >0
        move.w  -6(a6,a4.l),d0  read change to current length
        add.w   d0,bv_lengt(a6) change it
        move.w  -2(a6,a4.l),bv_linum(a6) update line number
        moveq   #1,d0
        move.b  d0,bv_stmnt(a6) and initialise statement on line
*       moveq   #0,d1           dunno what this was for? preserve d1 now
        cmp.b   d0,d0
rts0
        rts

* Moves a4, the pointer to the program file while basic is running, to the
* end of the current statement. Very critical to speed of superbasic.

* a4 -i o- pointer to program file (may not move if already at eol)
* d0 -  o- -1 if end of line found
*           0 if colon found
*           1 if then found
*           2 if else found
* Was ---> d1 - l - token <--- now d1 is preserved ... a problem?

* Note. The test for fp below could be changed to something like:
*       moveq   #31,d0  or      moveq   #-32,d0
*       and.b   ...             or.b    ...
* with the branch left out, and 16 bytes more in the jump table.
* There is a trade off though, as there are lots of fp's in a program, and the
* way it is means they save on one branch taken, as opposed to the table
* lookup and jump, versus the cost to the rest being just an un-taken branch.
* A quick look at timing means that this code should be changed if programs
* tend to have a ratio of fp:other less than 4:9, i.e. less than 4/13th's of
* symbols scanned are fp. Unfortunately, this is not wildly off the sort of
* ratio one gets. In the absence of heavy benchmarking the code stays as it is.

* Update! as I have now included the possibility of tokenised short and long
* integers, the above no longer applies, so the code has been changed!
* We now ignore the top 3 bits of a token, as we should never find a token with
* any value other than $8x or $fx, and even $8f is really undefined (so far!). 

* N.B. jumps to sym and key repectively have b.colon and b.else in d0

sym
x       equ     sym-b.colon
        sub.b   1(a6,a4.l),d0
        beq.s   col
        addq.b  #b.eol-b.colon,d0
        bne.s   wrd
        subq.l  #2,d0           line feed -> -1
thn
        subq.l  #1,d0           then -> 1
els
        addq.l  #2,d0           else -> 2
col
        rts                     : -> 0

key
        assert  key-b.else-x,0
        sub.b   1(a6,a4.l),d0
        beq.s   els
        addq.b  #b.then-b.else,d0
        beq.s   thn
wrd
        addq.l  #2,a4
ib_eos
        moveq   #31,d0
        and.b   0(a6,a4.l),d0   get token type
        move.b  tokv(pc,d0.w),d0
        jmp     x(pc,d0.w)

flt
        addq.l  #6,a4
        bra.s   ib_eos

lng
        addq.l  #4,a4
        bra.s   ib_eos

txt
        moveq   #2+2+1,d0       token word, char count and one to round up
        add.w   2(a6,a4.l),d0   add length
        bclr    #0,d0           round down
        add.w   d0,a4           (txt should not be > 32767-6*2, think about it)
        bra.s   ib_eos          enter loop

tokv
        dc.b    wrd-x,key-x,lng-x,lng-x,sym-x,wrd-x,wrd-x,lng-x
        dc.b    lng-x,wrd-x,lng-x,txt-x,txt-x,lng-x,wrd-x,wrd-x
        dcb.b   16,flt-x

        end
