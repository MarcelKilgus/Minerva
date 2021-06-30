* Move memory as quickly as practical (within 5% of max possible!)
        xdef    mm_clear,mm_clrr,mm_move,mm_mrtoa,mm_mrtor

        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_vect4000'

* The call sequence is kept as simple as possible to avoid having lots of
* complex code in the calling routines. To this end, these preserve the values
* of all registers (except d0/ccr), including their call parameters.

* Setting d0.l to zero on exit is a concession to the fact that the routines
* are available as vectored routines, and can conveniently be "call"'ed.

* The main routines (move and clear) use absolute addresses and may be called
* in either user or supervisor mode.
* The additional entry points must be called in user mode and they then provide
* for switching to supervisor mode and handling source and/or destination as a6
* relative addresses.

* Moves are always non-destructive. If the source is below the destination and
* overlaps it, this will do the move starting from the top of the areas.

* A bit of a waste on a normal QL, but in order to provide for the astounding
* medusa spec, we'll leave the code so it can actually trundle more than a
* megabyte around! After all, it only costs 32 bytes of code.

* The choice of instruction sequences to acheive the move is based on some very
* exhaustive testing of alternatives. The only improvement could be to employ
* "movem.l", but at some considerable expense for a very minor speed increase. 

* This version is inefficient when called to move small amounts of memory, but
* the current callers are usually asking for much more, or have already spent
* so much time setting up for this that it doesn't matter?
* With normal (slow) internal RAM, the overhead seems to be around about fifty
* bytes worth of move. I.e. it's a moot point whether string copying should use
* this routine, though I believe that it should, as it has already done such a
* vast amount of processing before deciding to move a string, one might just as
* well get the speed improvement for very long strings, without hassle.

        section mm_move

* d0 -  o- 0 (sets ccr)
* d1 -ip - number of bytes to move
* a0 -ip - destination address
* a1 -ip - source address (ignored by clear and clrr)
* a6 -ip - base address (ignored by move and clear)

mm_clrr
        moveq   #clrr-mrtor,d0
        bra.s   mvrel

mm_mrtoa
        moveq   #mrtoa-mrtor,d0
        bra.s   mvrel

mm_mator
        moveq   #mator-mrtor,d0
        bra.s   mvrel

mm_mrtor
        moveq   #0,d0
mvrel
        move.l  a2,-(sp)
        lea     mrtor(pc,d0.w),a2
        moveq   #mt.extop,d0
        trap    #1
        move.l  (sp)+,a2
okrts
        moveq   #0,d0
        rts

* d0 -  o- 0 (sets ccr)
* d1 -ip - number of bytes to clear (<=0 = none)
* a0 -ip - address of area to clear
* a6 -ip - base address (clrr only)

clrr
        add.l   a6,a0           make address absolute
        pea     matorex         return via common code
mm_clear
        moveq   #32,d0          this needs tuning, though it's about right
        cmp.l   d1,d0
        ble.s   clr32           only do the hoopy clear if a fair bit needed
        move.l  d1,d0
        ble.s   okrts           finished if <= 0 bytes to do here
clr1
        sf      (a0)+           clear small areas a byte at a time
        subq.b  #1,d0
clrq
        bne.s   clr1
        sub.l   d1,a0           restore pointer
        rts

clr32
        move.l  d1,-(sp)        save original length
        move.w  a0,d0           check start address
        lsr.b   #1,d0
        bcc.s   clreven
        sf      (a0)+           if odd, clear the initial byte
        subq.l  #1,d1
clreven
        moveq   #0,d0           move.l is quicker than clr.l!
        move.b  d1,-(sp)        save any odd bytes needed at end
        lsr.l   #5,d1           do rest in blocks of 32
        bra.s   clre            enter loop

clrh
        swap    d1
clrw
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
        move.l  d0,(a0)+
clre
        dbra    d1,clrw
        swap    d1
        dbra    d1,clrh
        moveq   #31,d0
        and.b   (sp)+,d0        get back any odd bytes that need doing
        move.l  (sp)+,d1        reload full length
        tst.b   d0
        bra.s   clrq            go do last bit

mrtoa
        add.l   a6,a1
        bsr.s   mm_move
        sub.l   a6,a1
        rte

mrtor
        add.l   a6,a1
        bsr.s   movtor
        sub.l   a6,a1
matorex
        sub.l   a6,a0
        rte

mvreg   reg     d5-d6/a0-a1

* Using "movep" instructions is a little faster than eight single byte moves on
* standard memory. Even quicker on faster memory.
mvpreg  reg     d2-d5   we need some more work registers

mvph
        swap    d0
mvpw
        movep.l 0(a1),d2
        movep.l 1(a1),d3
        movep.l 8(a1),d4
        movep.l 9(a1),d5
        movep.l d2,0(a0)
        movep.l d3,1(a0)
        movep.l d4,8(a0)
        movep.l d5,9(a0)
mvpu
        add.l   d6,a1
        add.l   d6,a0
mvpd
        dbra    d0,mvpw
        swap    d0
        dbra    d0,mvph
        movem.l (sp)+,mvpreg
        tst.b   d6
        bpl.s   mvdbe
        sub.l   d6,a1
        sub.l   d6,a0
        bra.s   mvube

mvp
        moveq   #15,d5
        and.b   d0,d5
        asr.l   #4,d0
        movem.l mvpreg,-(sp)
        tst.b   d6
        bpl.s   mvpd
        bra.s   mvpu

mator
        pea     matorex
movtor
        add.l   a6,a0
mm_move
        move.l  d1,d0
        ble.s   mvok            don't bother if zero (or negative!) amount

        movem.l mvreg,-(sp)

        moveq   #16,d6          flag for move down and maybe "movep" step
        move.l  a0,d5
        sub.l   a1,d5           going up or going down?
        bcs.s   mvset           down - start doing it
        beq.s   mvend           neither - leave memory just where it is!
        cmp.l   d0,d5           do areas overlap?
        bcc.s   mvset           no - we can move down, it's quicker!
        add.l   d0,a1           top of source
        add.l   d0,a0           top of destination
        moveq   #-16,d6         "movep" step and direction flag
mvset

        asr.b   #1,d5           is move travelling an odd distance?
        bcs.s   mvp             yes - use "movep" instructions

        move.w  a1,d5
        asr.b   #1,d5           are addresses currently odd?
        bcc.s   mvword
        subq.l  #1,d0           yes - count one off the total
        tst.b   d6
        bmi.s   mv1up
        move.b  (a1)+,(a0)+     move odd byte to get both on word bdrys
        bra.s   mvword

mvub
        move.b  -(a1),-(a0)
mvube
        dbra    d5,mvub
        bra.s   mvend

mvdb
        move.b  (a1)+,(a0)+
mvdbe
        dbra    d5,mvdb
mvend
        movem.l (sp)+,mvreg
mvok
        moveq   #0,d0
        rts

mvulh
        swap    d0
mvulw
        move.l -(a1),-(a0)
        move.l -(a1),-(a0)
        move.l -(a1),-(a0)
        move.l -(a1),-(a0)
        move.l -(a1),-(a0)
        move.l -(a1),-(a0)
        move.l -(a1),-(a0)
        move.l -(a1),-(a0)
mvule
        dbra    d0,mvulw
        swap    d0
        dbra    d0,mvulh
        bra.s   mvube

mvdlh
        swap    d0
mvdlw
* We've taken so long getting here, make it worth our while!
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
        move.l (a1)+,(a0)+
mvdle
        dbra    d0,mvdlw
        swap    d0
        dbra    d0,mvdlh
        bra.s   mvdbe

mv1up
        move.b  -(a1),-(a0)
mvword
        moveq   #31,d5          addresses even, move 32 bytes at a go
        and.l   d0,d5
        lsr.l   #5,d0
        tst.w   d6
        bpl.s   mvdle
        bra.s   mvule

        vect4000 mm_clear,mm_clrr,mm_mator,mm_move,mm_mrtoa,mm_mrtor

        end
