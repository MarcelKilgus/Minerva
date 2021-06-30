* Wait for end of gap and reset pll
        xdef    md_endgp

        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_delay'

        section md_endgp

* a3 -ip - address of microdrive control register
* d0-d1 destroyed
* return+0 on error, return+2 ok

md_endgp
        moveq   #0,d1           wait for up to 64k loops of 7.73us (.5secs)
wait_gap ; 58 cycles in loop
        subq.w  #1,d1         8 decrement wait counter
        beq.s   exit      18/12 ... timeout?
        btst    #pc..gap,(a3) 20 is there a gap yet?
        beq.s   wait_gap  18/12

* Gap found - now wait for it to go away (for a reasonable time).

        moveq   #0,d1           wait for up to 64k cycles of 8.8us (.6secs)
wait_sig ; 66 cycles while signal is low
        subq.w  #1,d1         8 decrement wait counter
        beq.s   exit      18/12 ... timeout?
        moveq   #24-1,d0      8 need signal for 24 loops of 6.67us (160us)
chek_sig ; 50 cycles per loop while signal is low
        btst    #pc..gap,(a3) 20 is there a signal?
        bne.s   wait_sig   18/12 ... if not reset debounce counter
        dbra    d0,chek_sig 18/26
* If the above accepts the gap signal is over, the btst in the loop will have
* been seen zero a total of 24 times, thus an end of gap will be accepted if it
* has a duration of just 23*50 cycles. i.e. 153.3us will do.

        moveq   #pc.read,d1   8 set up pll reset byte
        move.b  d1,(a3)      12 ... reset pll
        delay   25              wait >2 bit times for zero to clock through
        move.b  d1,(a3)      12 ... reset controller electronics

        addq.l  #2,(sp)      40 return ok
exit
        rts                  32
* On return, the total elapsed time from the end of the gap signal should be
* close to 197us.

        end
