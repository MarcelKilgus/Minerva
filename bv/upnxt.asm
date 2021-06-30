* Call user trace routine
        xdef    bv_upnxt,bv_uplet,bv_upmcf,bv_upswp,bv_uprnm

        include 'dev7_m_inc_bv'

* If there is a negative value set up in bv_uproc(a6), the least significant 31
* bits should be the address of the user trace routine, and this is called.

* On entry to the user's code, the long word on the top of the stack is set up
* to reflect which type of operation was in progress:

*       0 bv_upnxt      about to start interpreting the next statement 
*       2 bv_uplet      about to assign to a variable
*       4 bv_upmcf      about to call a machine code function
*       6 bv_upswp      about to swap proc/fn args
*       8 bv_uprnm      about to renumber a range of lines

* N.B. The above list may expand, so user trace routines should expect to get
* higher, even values passed to them, and ignore them. One guarantee is that
* the first three bytes will be zero and the final, least significant byte will
* be even, positive and less than 32. I.e. provide for at most 16 call types.

* The registers, etc., are as they happened to be at the point that this code
* was called and reference must be made to the source files where the calls are
* made to see what might contain useful data.
* a6 is the only defined value, in that it will be the bv area base address.

* All registers must be preserved by the user routine, which will normally
* finish with an "rts" after removing the longword parameter.

        section bv_upnxt

comm
        move.l  d0,-(sp)        save a data register
        pea     bv_upnxt+2      base of return addresses
        move.l  (sp)+,d0        into a data register
        sub.l   d0,4(sp)        longword parameter for user code
        move.l  (sp),d0         reload register
        move.l  bv_uproc(a6),(sp) should be user's trace procedure
        bmi.s   ok              check that the vector is (still) ok
        addq.l  #8,sp           if not, scrap the whole business
ok
        rts                     call user code or go back home

bv_upnxt
        bsr.s   comm            0: trace start of statement
bv_uplet
        bsr.s   comm            2: trace assignments
bv_upmcf
        bsr.s   comm            4: trace machine code function calls
bv_upswp
        bsr.s   comm            6: trace proc/fn arg swaps
bv_uprnm
        bsr.s   comm            8: trace renumbering of program

        end
