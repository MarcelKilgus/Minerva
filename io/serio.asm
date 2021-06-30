* generic serial i/o drviers
        xdef    io_serio,io_relio

        include 'dev7_m_inc_io'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_err'

* The rules for serio and relio go like this:
* When serio or relio is called:
* d0 -i o- trap key / error code (ccr set)
* d1 -i o- ioss
* d2 -i  - ioss
* d3 -i  - ioss
* a0 -ip - ioss
* a1 -i o- ioss
* d4-d5/a4 destroyed

* Routines for test, fetch and send are supplied. For io_serio, they are
* absolute addresses in the three longwords at the return address, and return
* is made to the word after them. For io_relio, the three words at the return
* address are the relative offsets from themselves to the routines, and return
* is made to the next level up on the stack.

* Any values in d6-d7/a5 (and indeed a6, though one rather expects this to be
* the base of the system variables!) are passed down to the supplied routines.
* They may make no assumptions about the contents of d0-d1/d5-d6/a1/a4.

* When the supplied routines are called, they should either return an error in
* d0 or, if they are succesful, they should return zero in d0.
* The send routine will be passed the byte to be send in d1.b, msbs undefined.
* They may destroy d1-d3 and a1-a3, with the exception that the test and fetch
* routines must return the next available byte in d1.b if they succeed.

* Note that once the test routine has indicated success, further calls to it
* should keep succeeding, and returning the same value in d1.b, until such time
* as a fetch call is made, which should also succeed, and return the same byte.

* While in here, the least significant bit of the return address is a flag.
* The bit is set for an io_serio call. It is employed to action appropriate
* code for fetching the routine addresses to a4 and doing the final return.
* We maintain a1 in the IOSS manner, with d4 as a copy of the buffer length
* from the initial d2 and d5 as the count of characters done from the initial
* d1, as appropriate.

        section io_serio

tabent  macro   t
        dc.b    (([t])-io_pend)&$7fffffff
        endm
off
        tabent  io_pend
        tabent  io_fbyte
        tabent  io_fline
        tabent  io_fstrg
        tabent  err_bp ; io.edlin
        tabent  io_sbyte
        tabent  err_bp
        tabent  io_sstrg
        tabent  fs_heads
        tabent  fs_headr
        tabent  io_fstrg
        tabent  io_sstrg

io_serio
        addq.l  #1,(sp)         set flag for old serio call
io_relio
        move.l  (sp),a4         get a copy of return address ready
        moveq   #0,d4
        move.w  d2,d4           io.xxx calls use word buffer lengths
        move.l  d1,d5           set copy of d1
        subq.w  #io.sstrg+1,d0
        bcs.s   action          key in io.xxx range, go do it
        move.l  d2,d4           fs.xxx calls use longword buffer lengths
        sub.w   #fs.save-io.sstrg,d0
        addq.w  #fs.save-fs.heads+1,d0
        bcs.s   action          key in fs.xxx range, go do it
        moveq   #6-io.sstrg-1,d0 force report of bad parameter
action
        addq.w  #io.sstrg+1,d0
        move.b  off(pc,d0.w),d0
        jsr     io_pend(pc,d0.w) call code to do the work
        moveq   #3*4-1,d4
        add.l   (sp)+,d4        get ready for return
        btst    #0,d4           check call type
        bne.s   tstret          relio: returns up a level after setting ccr
        tst.l   d0
        move.l  d4,a4
        jmp     (a4)            serio: return to word past the addresses

io_pend
*       moveq   #0,d0           test routine is the first element
        bsr.s   vectest         set up test routine address
        bra.s   callit          go do it

fs_heads
        moveq   #15,d4          fixed buffer length of 15
        tst.w   d5
        beq.s   heads1          if nothing done yet, go send the $ff prefix
io_sstrg
        bsr.s   vecsend         set routine address for sending bytes
sslp
        cmp.l   d4,d5           check count sent against buffer length
        bcc.s   setd1_ok        if we have finished, get out
        move.b  (a1),d1         get a byte from the buffer
        bsr.s   callit          call the send routine
        bne.s   setd1           on error, return d1/a1 updated by count sent
        addq.l  #1,a1           move past the byte
ssadd1
        addq.l  #1,d5           count what we've done so far
        bra.s   sslp            go see if more to send

heads1
        st      d1              prefix byte for file header is $ff
        bsr.s   io_sbyte        send that
        bne.s   setd1           on error, return with no bytes sent
        bra.s   ssadd1          continue as per send string

err_bp
        moveq   #err.bp,d0      report error for bad key or bad header prefix
        rts

vecsend
        moveq   #2*2,d0         send vector is offset by two elements
vector
        add.w   d0,a4           address for relio, needs another add for serio
vectest
        exg     a4,d0
        btst    #0,d0           test lsb of address register
        exg     a4,d0
        beq.s   vecrel          if zero, go do relative vector
        move.l  -1(a4,d0.w),a4  pick up serio's absolute vector
        rts

vecrel
        add.w   (a4),a4         add relio's relative vector to get absolute
        rts

io_sbyte
        bsr.s   vecsend         set up send routine address
        bra.s   callit          go do it

io_fbyte
        bsr.s   vecfetch        set up fetch routine address
callit
        movem.l d4-d5/a1/a4,-(sp) save our registers
        jsr     (a4)            call the test/fetch/send routine
        movem.l (sp)+,d4-d5/a1/a4 restore our registers
tstret
        tst.l   d0              ensure set ccr before returning
        rts

vecfetch
        moveq   #2,d0           fetch routing is offset by one element
        bra.s   vector          go set up the fetch routine address

fs_headr
        moveq   #15,d4          fix header read buffer size as 15
        tst.w   d5
        beq.s   headr1          if nothing yet read, go check the prefix byte
io_fstrg
        bsr.s   vecfetch        set up the fetch routine address
        bra.s   fslp            enter the loop

fsnxt
        bsr.s   callit          call the fetch routine
        bne.s   setd1           on error, return updated d1/a1
        move.b  d1,(a1)+        store byte read and update buffer pointer
fsadd1
        addq.l  #1,d5           count it
fslp
        cmp.l   d4,d5           check count against buffer size
        bcs.s   fsnxt           if not yet full, keep fetching
setd1_ok
        moveq   #0,d0           no error
setd1
        move.l  d5,d1           copy our count, or return byte, to d1
        bra.s   tstret          set ccr before returning

headr1
        bsr.s   io_pend         see if there is a byte available yet
        bne.s   setd1           if not, or there's a problem, return updated
        not.b   d1              check the value of the waiting byte
        bne.s   err_bp          error if it isn't $ff
        move.l  4(sp),a4        restore a4, as we need a new routine now
        bsr.s   io_fbyte        fetch the $ff byte, and throw it away
        bra.s   fsadd1          continue as per fetch string for the rest

io_fline
        bsr.s   vecfetch        set up the fetch routine address
fllp
        moveq   #err.bo,d0      error if the buffer fills up with no line feed
        cmp.l   d4,d5           check count against buffer length
        bcc.s   setd1           full up and no line feed, return updated d1/a1
        bsr.s   callit          call the fetch routine
        bne.s   setd1           on error, return with updated d1/a1
        move.b  d1,(a1)+        store fetched byte and update pointer
        addq.l  #1,d5           count it
        cmp.b   #10,d1          was it a line feed?
        bne.s   fllp            no, keep fetching bytes
        bra.s   setd1           successful fetch line, go return updated d1/a1

        end
