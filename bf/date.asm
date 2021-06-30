* Basic clock commands
        xdef    bf_date,bf_dates,bf_datez,bf_days,bp_adate,bp_sdate
        ; The bp routines should be in that section, but they're better here.
        ; bp_datez changed to bf_datez now in range for the ii_clock routine!

        xref    bf_fllin
        xref    bv_chri
        xref    ca_gtlin
        xref    cn_date,cn_day
        xref    ri_fllin

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_nt'

dot     equ     1961

        section bf_date

bf_date         ; -mt.aclck
        moveq   #-2-mt.aclck,d7
bf_days         ; $83
        addq.b  #2,d7
bf_dates        ; $81
        tas     d7
bp_adate        ; $01
        addq.b  #mt.aclck-mt.sclck,d7
bp_sdate        ; $00
        bsr.s   bf_datex
        bne.s   rts0
        moveq   #mt.sclck,d0
        add.b   d7,d0
        beq.s   bf_fllin        bf_date
        bpl.s   trap1           (bug in GC: bits 15..7 not ignored)
        move.w  d7,a2
        move.w  $EC-$81(a2),a2  fetch cn_day/cb_date from vector table
        moveq   #t.str,d4       set return type
        jsr     (a2)            do conversion required
putrip
        move.l  a1,bv_rip(a6)   set stack pointer
        rts

* Number of days preceeding each month in a non-leap year, less one.
monoff  dc.w    -1,30,58,89,119,150,180,211,242,272,303,333

* Make this available for date function.
* It permits zero to four or six parameters and removes them from the ri stack.
* No parameters will read the clock. If parameters are given, they are seconds,
* minutes/second, hours/minutes/seconds, days/hours/minutes/seconds or
* a complete date specification of year/month/day/hours/minute/second.
* d1.l is the resultant seconds since the year dot.
* d0.l is a normal error code, or zero for success.
* d2-d4/d6/a0/a2 are all smashed.
* a1.l will be back to the original bv_rip value.
* A reasonable amount of spare space will have been allocated on the ri stack.

bf_datex
        jsr     bv_chri(pc)     make sure of a reasonable amount of space
        jsr     ca_gtlin(pc)    get parameters as long integers
        bne.s   rts0            propagate any error
        moveq   #mt.rclck,d0
        asl.w   #2,d3
        bne.s   parms
trap1
        trap    #1
ok
        moveq   #0,d0           no error
tstrts
        tst.l   d0
rts0
        rts

parms
        move.l  a1,d2
        add.w   d3,a1
        bsr.s   putrip          reset the stack
        move.l  0(a6,d2.l),d1   pick up first parameter
        subq.w  #2<<2,d3
        bcs.s   ok              one parameter: just seconds
        beq.s   mul60add        two parameters: minutes/seconds
        subq.w  #2<<2,d3
        bcs.s   hms             three params: hours/minutes/seconds
        beq.s   dhms            four params: days/hours/minutes/seconds
        moveq   #err.bp,d0
        subq.w  #2<<2,d3
        bne.s   tstrts          if not 6 params then error

* Make this bit available to bootup i2c date copy
* d0 -  o- zero
* d1 -i o- input year, output seconds since dot
* d2 -  o- zero
* a1 -ip - pointer rel a6 to end of 20 bytes, 5 longs: mm,dd,hh,mm,ss
* a6 -ip - base for a1
* d3/d4 and d6.lsb destroyed

bf_datez
        moveq   #-16,d2
        add.l   a1,d2           offset on stack to days
        move.b  d1,d6
        sub.w   #dot,d1         (year-dot)
        move.w  d1,d4
        move.w  #365,d0
        bsr.s   muladd          ... * 365 + days ...
        lsr.w   #2,d4
        add.w   d4,d1           ... + (year-dot) div 4 ...
        move.w  -18(a6,a1.l),d0 get month
        add.w   d0,d0
        add.w   monoff-2(pc,d0.w),d1 ... + offset(month-1) ...
        lsl.b   #8-2,d6         if it's a leap year
        bne.s   dhms
        subq.w  #3<<1,d0        and it's gone february
        bcs.s   dhms
        addq.l  #1,d1           then ... + 1 ... (feb 29 not in offset table)
dhms
        moveq   #24,d0
        bsr.s   muladd          ... * 24 + hrs ...
hms
        jsr     mul60add        ... * 60 + mins ...
ms
*       bsr.s   mul60add        ... * 60 + secs
*       bra.s   ok

* Multiply and add subroutine
* Entry:
*       d0.w = w, 16 bit multiplier
*       d1.l = l, 32 bit multiplicand
*       d2.l = offset on ri stack to "p", the 32 bit addend
* Exit:
*       d0.l = 0
*       d1.l = l*w+p
*       d2.l 4 added
*       d3.l smashed

mul60add
        moveq   #60,d0
muladd
        move.l  d1,d3
        swap    d3
        mulu    d0,d3
        swap    d3              d3(msw) = l(msw) * w
        clr.w   d3              d3(lsw) = 0
        mulu    d0,d1           d1 = l(lsw) * w
        add.l   d3,d1           d1 = l * w
        add.l   0(a6,d2.l),d1   add p
        addq.l  #4,d2           move on pointer
        bra.s   ok

        end
