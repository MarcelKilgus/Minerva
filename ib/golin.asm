* Go to start of line with line number equal to, or first greater than, request
        xdef    ib_glin0,ib_glin1,ib_golin,ib_nxtk

        xref    ib_steof

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_token'

        section ib_golin

* If bv_sing is set:
* d0 -  o- 0
* a4 -  o- base of token list
* ccr-  o- zero

* If bv_sing is clear:
* d0 -  o- 0
* d1 -  o- bv_lengt (applies to prior line, zero if a4=pfbas). msw preserved.
* d2 -  o- bv_pfp
* d4 -ip - line number to go to
* a4 -i o- token within a line / found line length change or end of program
* ccr-  o- zero if a4<d2, otherwise a stop is set up and ccr is positive

ib_golin
        tst.b   bv_sing(a6)     is this a command line other than goto?
        beq.s   getlf
        move.l  bv_tkbas(a6),a4 yes, so go to token base and return ok
ok_rts
        moveq   #0,d0
        rts

findlf
        bsr.s   ib_nxtk         get next token
getlf
        cmp.w   #w.eol,0(a6,a4.l) are we at end of line?
        bne.s   findlf          not yet, so keep looking
        addq.l  #2,a4           space over lf
        move.w  bv_lengt(a6),d1 pick up this line length
        bsr.s   glin1           postion to requested line
        subq.w  #2,d1           left as +2 by routine
        move.w  d1,bv_lengt(a6) store the prior line length
        cmp.l   a4,d2
        bge.s   ok_rts
        jmp     ib_steof(pc)    returns ccr for > 0

* Moves a4 to point at next token in program file, or token list.
* This now ignores the top 3 bits of a token, as a token should only ever be
* one of $8x or $fx, with $8f currently undefined, so far!

* d0 -  o- 1st byte of next token
* d1 -  o- 1st word of next token
* a4 -i o- offset to tokenised code, moved across current token to next token

ib_nxtk
        moveq   #31,d1          lose all but 5 lsb's of token
        and.b   0(a6,a4.l),d1   get token type
        move.b  toktab(pc,d1.w),d1 get no of bytes token comprises
        bpl.s   add_tok         strings are different
        neg.b   d1              no of bytes to add to no of chars
        add.w   2(a6,a4.l),d1   add no of chars
        bclr    #0,d1           make it even
add_tok
        add.l   d1,a4           move pointer along correct number of bytes
        move.w  0(a6,a4.l),d1   next token (word)
        move.l  d1,d0
        lsr.w   #8,d0           next token (byte)
        rts

toktab  dc.b    2,2,4,4,2,2,2,4,4,2,4,-5,-5,4,2,2 $80..$8f
        dcb.b   16,6 $f0..$ff

* Entry to find a line starting from scratch.
* Same as later entry, but a4/d1 set up for going from start of program.
ib_glin0
        move.l  bv_pfbas(a6),a4
        clr.w   d1
glin1
        addq.w  #2,d1

* Enter here with a4 at any PF line length change word or at top of program.
* The length in d1 must apply to the whole prior line and be two if at pfbas.
* The case of an empty program file will work fine, leaving d0=a4=d2 and d1=2.

* We go for a complex, but fast technique. Once we have established whether we
* are to go forward or back through the program, we try to insert an extra
* pre-word at the end we are headed for. If there is space for it, the scan
* loop gets down to 56 cycles. (This may be forced up to 60 by the QLs wait
* states). If no spare word is available (which we try hard elsewhere to ensure
* is not the case), we have to settle for an alternative loop of 68 cycles.
* This scan loop is used to move across increasing sets of lines, without
* checking the line numbers. Only after each progressively larger jump, do we
* check the line number. When we have got far enough, we are left with a known
* sequence of lines where the first is definately not the line to go to and the
* last is maybe the one (or is the top of the program). We then scan that final
* section to get the proper position.
* By calculating the performance of various choices of how to arrange the
* skip amount, the best algorithm turns out to be to just increment the skip
* by one each time. This gives reasonable performance for short overall travels
* and finishes up averaging 67% of the speed of the plain search over all
* movements from 1 to 1000 lines.
* Changing the step by a factor (e.g. 9/8) each time is definately NOT any
* better... its average performance is worse over all ranges.
* Also, attemping binary chop searches is pretty naff.
* What would be marvellous would be to have the program file sensibly organised
* with the line numbers and length change words held in a totally separate
* block, then we could really whizz to lines. The timing would be of the order
* of the log of the number of lines, instead of directly proportional to the
* distance travelled! Mind you, saying that doesn't make it too bad, maybe...
* if most jumps are short?
* Another good idea would be if an extra word at the end was a length change
* back to zero, so we could scan from either end.
* A thought: can the current length change words be operated on to make the
* same code execute in both directions? To go forward, we do add.w d1,a4 and
* add.w 0(a6,a4.l),d1 but to go back, if we first did add.w d1,a4 and neg.w d1,
* we would be steaming with the same code. Maybe if the code were more
* complex it would be worth considering.

* d0 -  o- pfbas
* d1 -i o- prior line length including pre-word (2 iff a4=pfbas) msw preserved
* d2 -  o- pfp
* d4 -ip - lno to look for, end at equal or first higher line
* a4 -i o- program file pointer to start of line (may be pfp if none)
* ccr-  o- result of final a4,d2 comparision, i.e. "le" if at end of program

ib_glin1
        move.l  d3,-(sp)        we need one register extra
        moveq   #0,d3           use it as skip counter
        bsr.s   pickup          get fpbas/pfp and compare a4 with pfp
        ble.s   subtop          if at end of program, must see about going up
        cmp.w   4(a6,a4.l),d4   check the line we've started on
        bls.s   subbing         if desired <= actual, need to look earlier
        cmp.l   bv_pfp+4(a6),d2 is there a word spare at end?
        beq.s   slowfwd         no, so we won't do our very fast scan
        move.w  #32767,0(a6,d2.l) set a pre-word that will block forward scan
        ; we now go by dead reckoning, and can reload d0/d2 at the end
fastfwd
        move.w  d3,d0
fflp
        add.w   0(a6,a4.l),d1   fastest skip lines
        add.w   d1,a4
        dbmi    d0,fflp
        bmi.s   ffsent          if -ve line length, we hit the sentinel
        cmp.l   d2,a4
        bge.s   backlp          we may be at top, so don't compare
        addq.w  #1,d3           skip more next time
        cmp.w   4(a6,a4.l),d4
        bhi.s   fastfwd         if still not there, skip further
backtest
        beq.s   found           if equal, we can skip out
* Now, we have skipped lines forward and found a line number greater than the
* request. Now look back, recalling that we have definately got an earlier line
* with a line number that is definately less than the request
backlp
        sub.w   d1,a4
        sub.w   0(a6,a4.l),d1
        cmp.w   4(a6,a4.l),d4
        blo.s   backlp
        beq.s   found           actually on the right line, so get out
bump
        add.w   0(a6,a4.l),d1   we went one too far
        add.w   d1,a4
found
        move.l  (sp)+,d3        restore saved register
pickup
        assert  bv_pfbas,bv_pfp-4
        movem.l bv_pfbas(a6),d0/d2 get ptrs to bottom and top of program text
        cmp.l   a4,d2           leave ccr as 'le' if at end of program
        rts

* Overran and hit the top sentinel, must go back over that first
ffsent
        sub.w   d1,a4           bring a4 back to pfp
        sub.w   #32767,d1       we know what our sentinel was
        bra.s   backlp          do backward scan

slowfwd
        move.w  d3,d0
sflp
        add.w   0(a6,a4.l),d1
        add.w   d1,a4
        cmp.l   d2,a4
        dbge    d0,sflp
        bge.s   backlp          we may be at top, so don't compare
        addq.w  #1,d3           skipping more next time
        cmp.w   4(a6,a4.l),d4
        bhi.s   slowfwd         if still not there, skip further
        bra.s   backtest        go start backward scan, unless we're there

subtop
        cmp.l   d0,d2
        beq.s   found           get out on empty file, as we don't like it much
        sub.w   d1,a4
        sub.w   0(a6,a4.l),d1   back up over last line in program
        cmp.w   4(a6,a4.l),d4   look at it
        bhi.s   bump            go out if the top is where to be
subbing
        beq.s   found           what luck, we're at the right line already!
        cmp.l   d0,a4           are we actually at the start
        ble.s   found           yes, don't bother ourselves, this is it
        cmp.l   bv_pfbas-4(a6),d0 is there a word spare at start
        beq.s   slowback        no, can't do a fast backward search
        move.w  #8,-2(a6,d0.l)  set a pre-word that'll block backward scan
fastback
        move.w  d3,d2
fblp
        sub.w   d1,a4
        sub.w   0(a6,a4.l),d1
        dbmi    d2,fblp
        bmi.s   fbsent          we ran off into the sentinel
        addq.w  #1,d3           skip more next time
        cmp.w   4(a6,a4.l),d4
        blo.s   fastback        if not there yet, increase backward steps
fwdtest
        beq.s   found  
* Now to scan forward
fwdlp
        add.w   0(a6,a4.l),d1
        add.w   d1,a4
fwdcmp
        cmp.w   4(a6,a4.l),d4
        bhi.s   fwdlp           go forward until we get the right place
        bra.s   found  

fbsent
        addq.w  #8,d1           we know what our sentinel was (pf not corrupt?)
        add.w   d1,a4           now at pfbas
        bra.s   fwdcmp          go forward from here

slowback
        move.w  d3,d2
sblp
        sub.w   d1,a4
        sub.w   0(a6,a4.l),d1
        cmp.l   d0,a4
        dble    d2,sblp
        ble.s   fwdcmp          we ran onto the front, so go to fwd compare
        addq.w  #1,d3           increase skip next time
        cmp.w   4(a6,a4.l),d4
        blo.s   slowback        increase backward steps
        bra.s   fwdtest

        end
