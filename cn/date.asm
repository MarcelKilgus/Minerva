* Time and date (as string)
        xdef    cn_date,cn_day

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_mt'

        section cn_date

* d0 -  o- zero, CCR set (no errors possible)
* d1 -ip - date (numeric)
* a1 -i o- pointer to ri stack

dot     equ     1961    (n.b. dot+3 is a leap year)

reg_list reg    d1-d5/a0

* String writing subroutines

wHHMM
        swap    d2
        moveq   #':',d1         colon first
        bsr.s   wX
        move.l  d2,d1
w99
        pea     wlast
wdigit
        ext.l   d1
        divu    #10,d1
        swap    d1
wlast
        add.b   #'0',d1
        bsr.s   wX
        swap    d1
        rts

wS
        moveq   #' ',d1         write a space
wX
        subq.l  #1,a1
        move.b  d1,0(a6,a1.l)
        rts
 
wAAAS
        moveq   #mt.inf,d0
        trap    #1
        move.l  sv_mgtab(a0),a0
        add.w   0(a0,d3.w),a0
        moveq   #3,d0
        mulu    d0,d4
        lea     3(a0,d4.w),a0
        moveq   #' ',d1         space after 3 chars
loop
        bsr.s   wX
        move.b  -(a0),d1        copy 3 chars into string
        dbra    d0,loop         four chars in all
        rts

cn_date
        movem.l reg_list,-(sp)
        bsr.s   calend          reduce to components
        swap    d1
        bsr.s   w99             write secs into string
        bsr.s   wHHMM           write mins into string with a colon
        bsr.s   wHHMM           write hours into string with a colon
        bsr.s   wS              write space
        move.w  d3,d1
        bsr.s   w99             write day in month
        moveq   #montab*2,d3
        bsr.s   wAAAS           get month into string with a space
        bsr.s   wS              write space
        move.w  d5,d1
        bsr.s   wdigit
        bsr.s   wdigit
        bsr.s   w99             write the year
        moveq   #20,d1          total chars
exit_ok
        subq.l  #2,a1
        move.w  d1,0(a6,a1.l)   set string length
        movem.l (sp)+,reg_list
        moveq   #0,d0           no error
        rts

cn_day
        movem.l reg_list,-(sp)
        bsr.s   calend
        swap    d4
        moveq   #daytab*2,d3
        bsr.s   wAAAS           move day into string and pad with a space
        moveq   #3,d1           string length excludes the trailing space
        bra.s   exit_ok

* Calendar subroutine
* Call with d1.l = time in seconds since 00:00:00 on 1st jan in year dot
* Returns with:
* d0 = 7
* d1.msw = second
* d2.msw = minute
* d2.lsw = hour
* d3.lsw = day of month (1..31)
* d4.msw = day of week (0..6)
* d4.lsw = month (0..11)
* d5.lsw = year.w

calend
        lsr.l   #1,d1           adjust so we can divide properly (X preserved)
        divu    #12*60*60,d1    d1.lsw = days since dot, d1.msw*2+X=sec in day
        moveq   #0,d3
        move.w  d1,d3           d3 = days since dot
        clr.w   d1
        swap    d1
        addx.l  d1,d1           d1 = second in day
        moveq   #60,d0
        divu    d0,d1           d1.msw = second
        moveq   #0,d2
        move.w  d1,d2
        divu    d0,d2           d2.msw = minute, d2.lsw = hour
        move.l  d3,d4           duplicate days since dot
        divu    #7,d4           d4.msw = day of week
        divu    #3*365+366,d3   d3.msw fyp days, d3.lsw = fyps since t0
        move.w  d3,d5           d5.lsw = sets of four years since dot
        clr.w   d3
        swap    d3              d3 = day of four year period
        divu    #365,d3         d3.msw = day of year, d3.lsw = year of fyp
        moveq   #31+28,d0       d0 = jan+feb (non-leap)
        subq.w  #3,d3           check for year in period >= 3
        blt.s   notleap
        beq.s   not4th          if it's the final odd day 0 / year 4
        move.l  #365<<16,d3     make it right
not4th
        moveq   #31+29,d0       d0 = jan+feb(leap)
notleap
        asl.w   #2,d5
        add.w   d3,d5
        add.w   #dot+3,d5       d5.lsw = year
        clr.w   d3
        swap    d3              d1 = day in year
        sub.w   d0,d3
        blt.s   notjf           if day >= jan+feb (month >= march) then
        moveq   #31+30,d0       make feb look like a 30 day month
notjf
        add.w   d0,d3

* Pattern now goes like: 31,30,31,30,31,30,31,31,30,31,30,31
        moveq   #7,d0           d0 = months in cycle
        mulu    d0,d3
        addq.w  #3,d3
        divu    #7*30+4,d3      d3 = (day * d0 + d0 div 2) / (days in cycle)
        move.w  d3,d4           d4.msw = day of week, d4.lsw = month in year
        clr.w   d3
        swap    d3
        divu    d0,d3           day in month = remainder div d0
        addq.w  #1,d3           plus one
        rts
 
        end
