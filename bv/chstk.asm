* Check all stacks for space, or returns space from them
        xdef    bv_chbfx,bv_chbt,bv_chchx,bv_chlnx,bv_chnt,bv_chnlx,bv_chpfx
        xdef    bv_chri,bv_chrix,bv_chrt,bv_chss,bv_chssx,bv_chtkx,bv_chvvx
        xdef    bv_clear,bv_clrt,bv_die,bv_new,bv_om

        xref    ut_err0,mm_move

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_rt'
        include 'dev7_m_inc_stop'

        include 'dev7_m_inc_assert'

bv..int equ     6       jb_rela6 flag that tells us if we're an interpreter

sssize  equ     256     size reqd by parse, exec, calc and m/c procedures
headrm  equ     64      give up to this extra if we have to move anything
rbits   equ     3       round movements to a multiple of eight

* These check space in relevant memory areas and, if necessary, allocate more.

* The schemes go like this:

* 1) A call that already has enough space available should return as fast as
*       can possibly be arranged.

* 2) If a call is not imediately satisfied, the extra amount required is
*       rounded up a little, and this amount is looked for in the central free
*       area. If found, the involved sections are shuffled by this amount.

* 3) In extremis, the amount that the central area fell short by is requested
*       from the system by an albas trap. This will tell us how much extra we
*       got, which may have been rounded up a bit, e.g. to a multiple of 512.
*       The requested amount is added to the original place and any spare is
*       given over into the central area.

* 4) If we can't get enough memory off the system, we trundle off to the
*       return address held in bv_sssav, hopefully to report the problem.

* Actually, there is no requirement to round requests, other ensuring that any
* eventual shuffling of the areas moves them a sufficient even distance.
* The rounding happens to be convenient, as the headroom (which is desirable!)
* can be applied with an "addq" in the code.

* This code now only moves the active parts of each section.

* A serious flaw in the original code was that once it needed to move anything,
* it insisted on finding the originaly requested amount, plus headroom, plus
* rounding. This meant that, for instance, if a large array was re-dimensioned
* a little larger, although a mass of VV area might have been fully released,
* an "out of memory" could be reported when there was no real problem!
* This code now only goes for the, slightly bumped up, extra space needed.

* One other point that could be made here, is that it would be very nice if
* the entry points (or due to history and silly software, an new set) were
* added, that not only checked for the requested amount, but actually
* updated the pointer involved!

* Note: some of these routines are expected to be at fixed offsets from
* bv_chrix by silly s/w. So alter anything here with extreme care.

        section bv_chstk

* d0 -  o- 0
* d1 -i  - space required (bv_ch??x only, others entries set standard values)
* d1-d2 destroyed.

* N.B. d3 is now preserved!
* (A pity, but d2 could be preserved except for silly callers, as above)

bv_chri
        moveq   #10*6,d1        RI trig stuff needs a fair bit... (lwr)
bv_chrix
        moveq   #bv_rip,d2      arithmetic pointer
        bra.s   bv_down
bv_chbt
        moveq   #3*4,d1         3 long words
*bv_chbtx
        moveq   #bv_btp,d2      backtrack pointer
        bra.s   bv_down
*bv_chtg
        moveq   #4,d1           1 long word
*bv_chtgx
        moveq   #bv_tgp,d2      temporary graph pointer
        bra.s   bv_down
bv_chnt
        moveq   #1+1+2+4,d1     two byte, a word and a longword
*bv_chntx
        moveq   #bv_ntp,d2      name table
        bra.s   bv_up
bv_chrt
        moveq   #rt.lentl,d1
        moveq   #bv_rtp,d2      return stack
        bra.s   bv_up
bv_chbfx
        moveq   #bv_bfp,d2      basic buffer pointer
        bra.s   bv_up
bv_chtkx
        moveq   #bv_tkp,d2      token pointer
        bra.s   bv_up
bv_chnlx
        moveq   #bv_nlp,d2      name list pointer
        bra.s   bv_up
bv_chvvx
        moveq   #bv_vvp,d2      variable value pointer
        bra.s   bv_up
bv_chchx
        moveq   #bv_chp,d2      channel table
        bra.s   bv_up
bv_chlnx
        moveq   #bv_lnp,d2      line number table (identical code to bv_chbtp!)
        bra.s   bv_up
bv_chpfx
        moveq   #bv_pfp,d2      program file
bv_up
        addq.w  #4,d2           from now on, keep sensible value in d2
* Not a good idea to change the entry values for d2, as there are probably
* nasty people out there who jump in at bv_chrix+2, etc, with their own value!
bv_down
        add.l   -4(a6,d2.w),d1  add in previous pointer
        sub.l   0(a6,d2.w),d1   will the areas overlap?
        bgt.s   meeting         yes - we'll have to move it
retzero
        moveq   #0,d0           this was silly, but Qlib expected it!
return
        rts

* Sanitary, though odd looking, check on stack. No longer zaps a1.
bv_chss
        moveq   #(sssize-4-2-2)>>1,d1 leave out return address and two words!
        add.w   d1,d1           ( ... to be friendly to sb startup.)
* New entry point! needed when unvr tries to stack a command line!
bv_chssx
        add.l   bv_ssp-4(a6),d1 intended offset to low address of stack
        add.l   d1,a6
        cmp.l   a7,a6           enough room between sp and previous area?
        sub.l   d1,a6
        ble.s   retzero         yes, so room is available

        subq.l  #8,sp           no enough space, 68020 compatible...
        movem.l a6-a7,(sp)      ...take a snapshot of a6 and a7
        moveq   #-6*4,d0        we may need to stack 7 regs and a return
        sub.l   (sp)+,d0
        add.l   (sp)+,d0        offset to required base of stack
        move.l  d0,bv_ssp(a6)   
        sub.l   d0,d1           this is the extra space we're after
* Note: if d1 has become negative, it means the stack has overflowed!
* We don't need to take special notice of it here though, as the albas call
* will fail, since it treats requests as unsigned.
        moveq   #bv_ssp,d2      stack pointer offset

* OK. So we have to do some shuffling, but we'll give the requestor a bit extra
* space so they don't come back pestering us too often!

* d0 -  o- 0
* d1 -i  - extra space required
* d2 -i  - space is to be made between pointers at -4(a6,d2.w) and 0(a6,d2.w)

meeting
        lsr.l   #rbits,d1       discard odd bits
        addq.l  #headrm>>rbits,d1 give headroom+1-1<<rbits to headroom extra
        lsl.l   #rbits,d1       and round needed space
* If we're gonna move things about, make sure we get value for money!

        movem.l d1-d3/a0-a3,-(sp) save local registers
        lea     getrela6,a2
        moveq   #mt.extop,d0
        trap    #1
        assert  6,bv..int
        add.b   d0,d0
        bpl.s   bv_om           not an interpreter, so we die!

* See if we can satisfy the request from the middle of the basic area
chkfree
        move.l  (sp),d1         get extra space requested
        add.l   bv_chang-4(a6),d1 add bottom of free space area
        sub.l   bv_chang(a6),d1 compare to top of free space
        ble.s   midok           enough space there - go get it

* Not enough space in middle. have to add a block to the top and move up

albas
        moveq   #mt.albas,d0
        trap    #1              get the extra and move basic
        tst.l   d0              did we get our memory OK?
        bne.s   outmem          no - report out of memory
        moveq   #bv_chang,d2    it may be going to the middle
        move.l  4(sp),d3        get the requested pointer
        cmp.w   d2,d3           are we trying to add between top areas?
        ble.s   uptop           no - that's straightforward now

* We've found new space from the system and need to put between upper areas
        move.l  d3,d2           transfer space to below requested upper area
        sub.l   d1,(sp)         remainder to be transferred from middle
* ( This is likely to be negative, i.e. give some of the new space to middle )
* ( There is also the (unlikely?) event that it might be zero! )

uptop
        moveq   #bv_endpt+4,d3  space coming from top of basic area
        bsr.s   moveset         move up the stack, at least

midok
        move.l  (sp)+,d1        get extra space required
        move.l  (sp)+,d2        restore requested pointer
        moveq   #bv_chang,d3    middle pointer offset
        bsr.s   moveset
        movem.l (sp)+,d3/a0-a3  restore all local registers
retz2
        bra.s   retzero

* Hmmm.... someone has asked for space beyond the available, but they're not
* an interpreter! Only thing to do is kill them off.
bv_om
        moveq   #err.om,d0      we were out of memory
        jsr     ut_err0(pc)     try to write error message to chans 0/1
bv_die
        move.l  d0,d3           tell any waiting jobs
        moveq   #-1,d1          commit suicide
        moveq   #mt.frjob,d0
        trap    #1

* We ask the system for more memory, and it said "No!" ... boo hoo.

outmem
        move.w  #s.outm,bv_stopn(a6) set the stop number
        clr.b   bv_cont(a6)     tell it to stop, and set zero ccr
        move.l  bv_ssbas(a6),a0 top of basic wrt base of basic
        sub.l   bv_sssav(a6),a0 get to the saved position in start
        lea     -4(a6,a0.l),sp  here is the return, we hope
        rts

* Clear low areas for new, etc. Move the areas individually, for speed.
* The BF has been reset to minimal, and TK + PF are empty and at bfp.
* Upper stacks have been removed.

* d0 -  o- 0
* d1-d3/a0-a2 destroyed

bv_new
        moveq   #bv_ntbas,d3    move name table onwards down onto program file
        bra.s   clrlp

* Clear and return room for a clear, etc. VV onward are squashed down here.
* Upper stacks have been removed.

* d0 -  o- 0
* d1-d3/a0-a2 destroyed

bv_clear
        moveq   #bv_vvbas,d3    move VV onwards down to butt into each other
clrlp
        move.l  d3,-(sp)
        bsr.s   clrm
        move.l  (sp)+,d3
        addq.l  #8,d3
        cmp.w   #bv_chang,d3
        bne.s   clrlp
* There has to be some way of building the above into the main routine, but it
* all seems too complicated to me at the moment!

* Move top section of basic down and then try to release space to system

        moveq   #bv_endpt+4,d2  current top of basic area
        move.l  0(a6,d3.w),d1   get base of next area
        sub.l   -4(a6,d3.w),d1  less top of area gives its current free amount
        and.w   #-512,d1        round space to a multiple of 512 (2^9)
        bsr.s   moveset         move spare room in middle to top of basic
        moveq   #mt.rebas,d0    release space at top of basic area and move
        trap    #1              the whole shebang up. sp changed too.
        bra.s   retz2           just to be nice, say d0=0

* Clear top of rt stack, so ln can come down

* d1-d3/a0-a2 destroyed

bv_clrt
        moveq   #bv_lnbas,d3
clrm
        move.l  d3,d2
        addq.l  #8,d2
        move.l  0(a6,d3.w),d1   get base of area being moved
        sub.l   -4(a6,d3.w),d1  less top of prior area gives free space
        and.w   #-2,d1          make it even

* A routine to manage basic areas.

* The call sequence is kept as simple as possible to avoid having lots of
* complex code in the calling routines.

* d0 -  o- 0
* d1 -ip - even amount of space to transfer (positive or negative)
* d2 -i  - offset to between pointer pairs where d1 is to be added to the space
* d3 -i  - ditto, but where d1 is to be subtracted from the space
* a6 -ip - base of basic area
* a7 -i o- basic stack pointer (updated if need be)
* a0-a2 destroyed

movsav  reg     d1/d6-d7

moveset
        movem.l movsav,-(sp)
        lea     moveop,a2       code to call
        moveq   #mt.extop,d0    do it in supervisor mode
        trap    #1
        movem.l (sp)+,movsav
        rts

moveop
        cmp.w   d2,d3
        bgt.s   movdir
        exg     d2,d3           turn it round, so we have:
        neg.l   d1              amount by which to relocate pointers
movdir

        moveq   #8,d6           pointer step
        move.l  d1,d7
        beq.s   movstp          if no actual movement, get out now!
        bmi.s   movnxt
        exg     d2,d3           if up, we need to move upper areas first
        neg.w   d6
        add.w   d6,d3           remember to stop in the right place
        bra.s   movadd

movptr
        lea     4(a6,d2.w),a1   pointer pair to operate on
        add.l   d7,(a1)         relocate high pointer
        move.l  (a1),d1         get its new value
        add.l   d7,-(a1)        relocate low pointer
        move.l  (a1),a0         get its new value

        cmp.w   #bv_vvbas,d2    are we moving the VV area ...
        bne.s   isss
        tst.l   bv_vvfre(a6)    ... and does it have any free space set?
        beq.s   ssok
        add.l   d7,bv_vvfre(a6) yes, add movement to base free space ptr
isss
        cmp.w   #bv_ssp,d2      are we moving the SS area?
        bne.s   ssok
        move    usp,a0          yes - get the real SS pointer
        add.l   d7,a0           relocate it
        move    a0,usp          and save it
        sub.l   a6,a0           make it relative for a moment
* There is a query here... should this try to record the new bv_ssp(a6) value?
* All it essentially needs is:
*       move.l  a0,(a1)         set exact ssp value
* However, we get out quick when the movement is zero, and it would miss this.
ssok

        sub.l   a0,d1           overall size of area
        add.l   a6,a0           make new base absolute
        move.l  a0,a1
        sub.l   d7,a1           form old absolute base
        jsr     mm_move(pc)
movadd
        add.w   d6,d2
movnxt
        cmp.w   d2,d3
        bne.s   movptr
movstp
        rte

* Called in supervisor mode to get jb_rela6 flag byte
getrela6
        move.l  d0,a2
        move.l  sv_jbpnt(a2),a2
        move.l  (a2),a2
        move.b  jb_rela6(a2),d0 hang on... what am I? ...
        rte

        end
