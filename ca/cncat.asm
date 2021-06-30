* Concatenate strings at (a6,a1.l): b$, a$ -> a$&b$
        xdef    ca_cncat

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_mt'

* d0 -  o- zero if a$&b$ was done OK, err.ov if it was too long, CCR set
* a1 -i o- stack pointer to b$, then a$, returns with a$&b$ or null string
* a6 -ip - base address for a1
* d1-d3 destroyed

* locally:
* a0 - low address for reversals or source of shuffle
* a3 - high address for reversals or destination of shuffle
* a4 - end of result string
* d0 - byte(s), etc, and completion code
* d1 - .w count of reversal or bit 7 = len(a$&b$)&&1 and bit 0 = len(a$)&&1
* d2 - string length b$
* d3 - string length a$, then a$&b$

* N.B. As there are a lot of lax programers about, this routine now refuses to
* generate results longer than 32764 characters. See below for further info.

* This routine used to check that the string lengths on entry were positive,
* but that caused problems on handling the error return.
* Negative string lengths should never occur, but we now treat them as if they
* were unsigned, and hence just very long strings, and fail at the end when we
* find the generated result is far too long.
* Previously, the string left on the stack had a stupid value left as the
* length, and crashed when an attempt was made to drop it from the stack.
* We now guarantee that what is left behind on overflow is a genuine string
* (actually the null string), as we wish to adhere to the rule that whether an
* arithmetic stack operation succeeds or fails, it always leaves the stack with
* a result of the correct type.

reglist reg     a0/a2-a4

        section ca_cncat

* This routine should be optimised to cater for some of the special cases:
* b$ null just needs a1+=2, if we ignore funny length a$
* LEN(b$)=1 and a$ odd is fairly simple, but LEN(a$&b$) must have a check
* LEN(a$)+LEN(b$) small could be quicker
ca_cncat
        movem.l reglist,-(sp)   save anything we might want to keep
        lea     cncat,a2
        moveq   #mt.extop,d0
        trap    #1
        movem.l (sp)+,reglist   restore registers
        moveq   #0,d0           assume we're OK
* The following is a protection against lazy programmers, who use
* "addq.w #3/bclr #0" to round up and get past a string plus its length:
        cmp.l   #32765,d3       might adding 3 make it overflow? 
        bcs.s   rts0            good, it's not too long (even for cretins)
        addq.l  #1,d3
        bclr    d0,d3
        add.l   d3,a1           drop all chars of the string
        move.w  d0,0(a6,a1.l)   make result the null string
        moveq   #err.ov,d0      'overflow' error code for too-long string
rts0
        rts

* supervisor mode code
cncat
        add.l   a6,a1
        moveq   #0,d2
        move.w  (a1)+,d2        get length of b$ and set source for b$ chars
        lea     0(a1,d2.l),a0   end of b$
        moveq   #1,d0
        and.b   d2,d0           get odd-ness of length of b$
        add.l   d0,a0           skip any junk byte
        moveq   #0,d3
        move.w  (a0)+,d3        get length of a$ and set source for a$ chars
        lea     0(a0,d3.l),a3   end of a$
        moveq   #1,d1
        and.b   d3,d1           get odd-ness of length of a$
        add.l   d1,a3           skip any junk byte
        cmp.w   d1,d0           was either, but not both, string odd?
        beq.s   xeven           no, then this is the end of a$&b$
        move.b  -(a3),-1(a0)    if len(a$) was odd, this may need doing
        tas     d1              set bit 7 to remember odd length result
xeven
        move.l  a3,a4           keep a copy of end of a$&b$

* Now for some strategy... we can do little a$ or b$ strings by just grabbing
* the whole string into a register, shuffling the other string, then tacking
* in the saved string wherever it belongs. In particular, b$='' is real easy!

        moveq   #4,d0
        cmp.w   d2,d0           N.B. little b$'s are favorite!
        bcc.s   ashuff          len(b$)<5, a$ words go down, or even stay put!
        cmp.w   d3,d0
        bcc.s   bshuff          len(a$)<5, b$ bytes, or even words, go up
        bsr.s   reverse         reverse a$ bytes (plus a junk byte, maybe)
        sub.l   d3,a3           this is where the join is, and where b$ goes
        bsr.s   reva1           reverse b$ bytes (plus some junk)
        bsr.s   seta1           set final a$&b$ regs
        pea     setlen          reverse a$&b$ to get it right, then set length
reva1
        move.l  a1,a0           source from a1
reverse
        move.l  a3,d1
        sub.l   a0,d1
        lsr.l   #1,d1           swap count, an odd middle byte stays put
        bra.s   revent          enter at the bottom of the loop

revlp
        move.b  (a0),d0
        move.b  -(a3),(a0)+
        move.b  d0,(a3)
revent
        dbra    d1,revlp
        move.l  a4,a3           needed two out of three times
        rts

shuff
        move.l  (a1),d0         grab the whole of the short string
seta1
        add.l   d2,d3
        sub.l   d3,a4
        move.l  a4,a1           this will be the final string pointer
        rts

ashuff
        exg     d2,d3           we make d2 = len(a$)
        bsr.s   shuff           set it up
        cmp.l   a0,a4           hmm... b$='' or len(b$)=1 and len(a$) odd?
        bne.s   apity           no, then we must do a proper shuffle.
        add.l   d2,a4           a$ isn't moving, so skip right past it
        bra.s   shent           go to copy in the possible single b$ byte

apity
        lsr.w   #2,d2           full longwords in a$
        bcc.s   awent           no odd word to do
        move.w  (a0)+,(a4)+     move the odd single word
        bra.s   awent           enter word copy loop

adown
        move.l  (a0)+,(a4)+     copy a$ down in longwords
awent
        dbra    d2,adown
        asr.b   #1,d1           did a$ have an odd byte?
        bcc.s   short
        move.b  (a0)+,(a4)+     yes - we move it now
* As we know len(b$) was not zero, it's ok to drop straight in here

short
        rol.l   #8,d0
        move.b  d0,(a4)+        move a small string byte into the result
shent
        cmp.l   a3,a4
        bcs.s   short           carry on to the end of the small string
setlen
        move.w  d3,-(a1)        this is the final length, and a1 is ok!
        sub.l   a6,a1           set a1 to be an offset again
        rte

bshuff
        exg     a1,a0           a$ is the short string
        add.l   d2,a0           end of b$ is our source
        bsr.s   shuff           set it all up
        tst.b   d1              was len(a$&b$) odd?
        bpl.s   bword           no - don't need to do odd byte
        move.b  -(a0),-(a3)
        subq.w  #1,d2
bword
        asr.b   #1,d1           was len(a$) odd?
        bcs.s   bbent           yes, that's tough, have to do all byte shuffle
        lsr.w   #2,d2           we know this is now even (figure it out!)
        bcc.s   bwent           no carry, do longwords!
        move.w  -(a0),-(a3)     copy the odd word
        bra.s   bwent           enter loop at bottom

bbloop
        move.b  -(a0),-(a3)     copy b$ bytes
bbent
        dbra    d2,bbloop
        bra.s   short           len(a$) odd implies at least one byte!

bwloop
        move.l  -(a0),-(a3)     copy b$ longwords
bwent
        dbra    d2,bwloop
        bra.s   shent           len(a$) could have been zero

        end
