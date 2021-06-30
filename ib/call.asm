* Call and return from basic PROC/FN/GOSUB
        xdef    ib_bproc,ib_call,ib_cheos,ib_ret,ib_unret

        xref    bv_chrt,bv_upswp,bv_vtype
        xref    ca_carg,ca_eval,ca_garg,ca_newnt,ca_undo
        xref    ib_golin,ib_gost,ib_mkdim,ib_nxnam,ib_nxnon,ib_nxst
        xref    ib_s2non,ib_s4non,ib_stbas,ib_stimm,ib_stnxl
        xref    ut_err

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_rt'
        include 'dev7_m_inc_token'

* Call types
*x.gsb  equ     0       GOSUB
x.bpr   equ     1       PROCedure 
x.bfn   equ     2       function
x.bf0   equ     3       function (no arguments)

        section ib_call

* In the case of a FN, 8(sp) holds the position in the expression wrt tkbas

* N.B. (lwr) This has been altered to continuously keep the NT pointers in the
* RT stack as offsets relative to nt_bas. The code could probably be improved!

ib_bproc
        moveq   #x.bpr,d5

* d4 -i  - line number of GOSUB or name row PROC/FN
* d5 -i  - call type as above
* a2 -i  - nt entry for PROC, FN
* d0-d6/a0-a5 destroyed

ib_call
        jsr     bv_chrt(pc)     check enough room on the return table
        moveq   #rt.lentl,d1    set space for PROC/FN
        tst.b   d5
        bne.s   lenset
        moveq   #rt.lentl-rt.lenpr,d1 GOSUB requires less
lenset
        add.l   d1,bv_rtp(a6)   move up return table
        move.l  bv_rtp(a6),a1   top of return table
        move.b  bv_stmnt(a6),-rt.rsstm(a6,a1.l) statement to go back to
        move.w  bv_linum(a6),-rt.rslno(a6,a1.l) linenumber to go back to
        assert  bv_inlin,bv_sing-1,bv_index-2
        move.l  bv_inlin(a6),-rt.rssta(a6,a1.l) inline, single flags,index var
        move.b  d5,-rt.rsrtt(a6,a1.l) type of routine
        beq.s   rts0            finished for GOSUB, go back to that code
        sf      bv_inlin(a6)    not inline now (hmm... fudge kills fudge. lwr)
        move.l  d4,d3           save name row
        bsr.s   set_bltl        set base and top of locals
        move.l  a5,-rt.rsba(a6,a1.l) set base of args
        move.b  1(a6,a2.l),-rt.rsfnt(a6,a1.l) function type
        sf      -rt.rsswp(a6,a1.l) set not swapped
        move.w  4(a6,a2.l),-rt.rsdfl(a6,a1.l) line number of def line
        ble.l   err_nf1         was a single liner (???)

        cmp.b   #x.bf0,d5       this might be a FN with no args
        beq.s   no_arg

        move.l  a4,a0
        jsr     ca_garg(pc)     get all the actual arguments
        move.l  bv_rtp(a6),a1
        bsr.s   set_bltl        base and top of locals
        tst.l   d0
        bne.s   clr_err
        cmp.b   #x.bfn,d5
        beq.s   ch_cbr
        bsr.l   ib_cheos        PROCedure - check end of statement next
        beq.s   set_ok
clr_bp
        moveq   #err.bp,d0
clr_err
        moveq   #rt.lentl,d1
        sub.l   d1,bv_rtp(a6)   take this call off the return stack
        bra.l   clr_arg         clear any args found so far

set_bltl
        move.l  bv_ntp(a6),a5
        sub.l   bv_ntbas(a6),a5
        move.l  a5,-rt.rstl(a6,a1.l) set top of locals
        move.l  a5,-rt.rsbl(a6,a1.l) set base of locals
rts0
        rts

ch_cbr
        cmp.w   #w.cpar,d1      function - should be a close parenthesis here
        bne.s   clr_bp
        addq.l  #2,a0           skip it
        move.l  a0,d1
        sub.l   bv_bfp+4(a6),d1 get wrt just above the buffer
        move.l  d1,8(sp)        update pos for eval to continue from
set_ok
        move.l  a0,a4
no_arg
        st      -rt.rsswp(a6,a1.l) set swapped flag
        ; (if error following this then it's practically irrecoverable anyway)
        move.l  -rt.rsba(a6,a1.l),a5 restore bottom of args
        tst.b   bv_sing(a6)     if this is a single line command
        bsr.l   qstbas          check if we have to start at the top again
        bne.l   err_nf1         idiot's have lost the program
        bsr.l   posdfl          go to the start of subroutine line
        bsr.l   do_arg          do the formal arguments
get_loc
        bsr.s   find_loc        find a local line
        beq.s   nx_loc
        tst.l   d0              was there an error?
        bne.s   rts0            yes, get out
        addq.l  #4,sp           delete this return
        jmp     ib_stimm(pc)    because we're going to start immediately

nx_loc
        bsr.s   s2non           get next token
        cmp.b   #b.nam,d0       is it a name?
        bne.s   ch_sym          no, better check for significant symbols
        bsr.l   mk_dum          make a dummy entry and bump top of locals
        cmp.w   #w.opar,d1      is this a dimensioned local?
        bne.s   ch_sym          no, good, get next one
        addq.b  #t.arr-t.var,0(a6,a2.l) turn it into an array
        jsr     ib_mkdim(pc)    and make all the dimension space in the VV
        bne.s   rts2
        jsr     ib_nxnon(pc)
ch_sym
        cmp.w   #w.symcom,d1    is it a comma?
        beq.s   nx_loc          yes, ok
        bsr.l   ib_cheos        is it end of line then?
        beq.s   get_loc         yes, get another local line
        moveq   #err.bl,d0      anything else is wrong
rts2
        rts

err_ef
        moveq   #err.ef,d0
        rts

find_loc
        jsr     ib_nxst(pc)     get start of next statement
        bne.s   err_ef          no file left
        bsr.s   nxnon
        sub.w   #w.rem,d1       ignore remarks
        beq.s   find_loc
        addq.w  #w.rem-w.data,d1 ignore data statements too
        beq.s   find_loc
        moveq   #0,d0
        subq.w  #w.loc-w.data,d1 is it a LOCal?
        rts

s2non
        jmp     ib_s2non(pc)

swapit
        addq.l  #8,a5           move on up the name table
swapnew
        moveq   #0,d0
        move.w  2(a6,a4.l),d0   which name am I swapping with?
        lsl.l   #3,d0
        move.l  bv_ntbas(a6),a2 base of name table
        add.l   d0,a2
        tst.b   bv_uproc(a6)
        bpl.s   noup
        jsr     bv_upswp(pc)
noup
        move.w  0(a6,a2.l),d0   swap first word (not the NL pointer)
        move.w  -8(a6,a5.l),0(a6,a2.l)
        move.w  d0,-8(a6,a5.l)
        move.l  4(a6,a2.l),d0   and then second long word
        move.l  -4(a6,a5.l),4(a6,a2.l)
        move.l  d0,-4(a6,a5.l)
        addq.l  #4,a4           and along the PF line
        rts

mk_dum
        jsr     ca_newnt(pc)    get a new 0/0/noname/noval nt entry
        move.l  bv_rtp(a6),a1
        addq.l  #8,-rt.rstl(a6,a1.l) update top of locals, at least
        addq.b  #t.var,-8(a6,a5.l) say it's a simple variable for now
        bsr.s   swapnew         now swap it
        jsr     bv_vtype(pc)    make it unset + original type for its name
        addq.b  #t.var,0(a6,a2.l) make extra formal or local into a simple var
nxnon
        jmp     ib_nxnon(pc)

ib_cheos
        cmp.w   #w.eol,d1       end of line?
        beq.s   rts1
        cmp.w   #w.colon,d1     colon?
rts1
        rts

* Check the DEF PROC/FN line and swap the formal arguments for real ones
do_arg
        bsr.s   nxnon           get the def token
        bsr.s   s2non           get the PROC/FN token
        bsr.s   s2non           get the name
        tst.w   d3
        blt.s   no_nmchk
        cmp.w   2(a6,a4.l),d3   is it the one we think we're calling?
        bne.s   err_nf4         you can't fool us
no_nmchk
        jsr     ib_s4non(pc)
        cmp.w   #w.opar,d1      is it a close parenthesis?
        beq.s   get_arg         yes, good, get the arguments
        bsr.s   ib_cheos        at end of statement?
        beq.s   rts4            yes: fine, we just get out here
err_nf4
        addq.l  #4,sp           skip the return
err_nf1
        moveq   #err.nf,d0      must be a duff line
rts4
        rts

nxarg
        cmp.w   #w.cpar,d1      end of args yet?
        beq.s   rts4            yes, get out
get_arg
        addq.l  #2,a4           skip
get_arg1
        bsr.s   nxnon
get_arg2
        cmp.b   #b.nam,d0       is this a name?
        bne.s   nxarg
        move.l  bv_ntbas(a6),d1
        add.l   -rt.rsbl(a6,a1.l),d1
        cmp.l   d1,a5           is there a real arg to swap it with?
        bge.s   argshort
        bsr.l   swapit          yes - swap it
        bra.s   get_arg1        and look for the next one

* This happens when we have more formal than actual args
argshort
        bsr.s   mk_dum          make a dummy one, just like a local
        addq.l  #8,-rt.rsbl(a6,a1.l) update base of locals as well
        bra.s   get_arg2

ib_ret
        move.l  bv_rtp(a6),a1   now then, top of return table
        cmp.l   bv_rtbas(a6),a1 anything on stack?
        ble.s   err_nf1         not been called so can't return
        moveq   #rt.lentl-rt.lenpr,d1 ready to take GOSUB len off rt
        move.b  -rt.rsrtt(a6,a1.l),d5 what have we here?
        beq.s   gohome          it's a GOSUB, so we're done
        assert  0,x.bpr-1,x.bfn-2,x.bf0-3
        lsr.b   #1,d5           is this a function?
        beq.s   not_fn
        move.b  -rt.rsfnt(a6,a1.l),d0 if so, get function type
        move.l  a4,a0
        jsr     ca_eval(pc)
        move.l  a0,a4
        ble.s   err_ev
        move.l  bv_rtp(a6),a1
not_fn
        bsr.s   undo_ret
        moveq   #rt.lentl,d1    PROCs and FNs have an extra lump
gohome
        sub.l   d1,bv_rtp(a6)   take len off rt
        move.l  -rt.rssta(a6,a1.l),bv_inlin(a6) restore inline, single, index
        move.w  -rt.rslno(a6,a1.l),d4 linenumber to go back to
        bsr.s   restart         go to it
        move.l  -rt.rssta(a6,a1.l),bv_inlin(a6) restore inline, single, index
        move.b  -rt.rsstm(a6,a1.l),d4 restore statement
        jsr     ib_gost(pc)     and go
        sf      bv_unrvl(a6)    turn off the unravel flag
        tst.b   d5              is this a function?
        beq.s   okrts           no - we're done
        move.l  bv_ntp(a6),a5   should be entry that goes with ri stack
        assert  x.bfn>>1,x.bf0>>1,t.intern
        move.b  d5,-8(a6,a5.l)  mark it as internal
        addq.l  #8,sp           definately don't want to go back to start
        move.l  (sp)+,a0        restore position in expression
        add.l   bv_bfp+4(a6),a0 wrt a6
        move.l  bv_rip(a6),a1   restore arithmetic stack pointer
okrts
        moveq   #0,d0
        rts

err_ev
        blt.s   rts6
        moveq   #err.xp,d0
rts6
        rts

qstbas
        beq.s   rts6            at eof?
        jmp     ib_stbas(pc)    yes, have to start at the top again

posdflq
        bsr.s   qstbas          check if we have to start at the top again
posdfl
        move.w  -rt.rsdfl(a6,a1.l),d4 line number of def line
        add.l   bv_ntbas(a6),a5
restart
        jsr     ib_golin(pc)
        jmp     ib_stnxl(pc)

* a1 -i o- top of return table
undo_ret
        cmp.l   bv_pfbas(a6),a4
        ble.s   set_strt
        cmp.l   bv_pfp(a6),a4
        blt.s   get_lin
set_strt
        jsr     ib_stbas(pc)    set to top of PF & all the other bits
get_lin
        move.b  -rt.rsswp(a6,a1.l),d0 have the args been swapped?
        beq.s   clr_arg         no, err must have occurred during garg
        move.l  -rt.rsbl(a6,a1.l),a5 base of locals
        bsr.s   posdfl          go to def line
get_loc1
        bsr.l   find_loc        find a LOCal statement
        bne.s   end_loc         isn't one
nx_loc1
        jsr     ib_nxnam(pc)    get next local name
        beq.s   get_loc1        loop if end of statement
        bsr.l   swapit          and swap it back
        subq.l  #4,a4           else nxnam doesn't work on dimensioned local
        bra.s   nx_loc1

end_loc
        moveq   #-1,d3          we don't want to check the name
        move.l  -rt.rsba(a6,a1.l),a5 base of args
        tst.b   d0              end of file?
        bsr.s   posdflq         go back to def line, from top if at eof
        bsr.l   do_arg          do the argument swapping again

* Now free the arguments
clr_arg
        move.l  bv_ntbas(a6),a5
        move.l  a5,a3
        add.l   -rt.rsba(a6,a1.l),a3 base of args to free
        add.l   -rt.rstl(a6,a1.l),a5 top of args to free
        jmp     ca_carg(pc)     clear all the args (local as well)

rts8
        rts

* d1 -i  - depth of stack that needs to be copied to top of stack
* a4 -i  -
* d0/a0-a1/a3/a5 destroyed

ib_unret
        subq.l  #8,sp           68020 compatible
        movem.l a6/sp,(sp)      get a snapshot of a6/sp
        movem.l (sp),d2-d3      get back snapshotted a6/sp
        sub.l   d2,d3           this is the stack a6 offset
        addq.l  #4,d3           we won't touch the out-of-memory return
        sub.l   bv_ssbas(a6),d3 this is the distance to get to top (-ve)
        sub.l   d3,sp           so put stack pointer up there
        add.l   d1,d3           this is the distance to copy from

copystk
        move.w  6(sp,d3.l),-(sp) copy requested stack depth up to top
        subq.w  #2,d1
        bne.s   copystk

        clr.l   bv_sssav(a6)    this can't be valid anymore! lwr
*        sf      bv_comln(a6)    neither can this! lwr (new system though...)
        sf      bv_unrvl(a6)    turn off the unravel flag
        st      bv_sing(a6)     set single line on (really? lwr)
        move.l  bv_chbas(a6),a0 base of channels
        move.l  0(a6,a0.l),a0   actual console channel id
        moveq   #err.pf,d0
        jsr     ut_err(pc)      tell user we're clearing out
nxt_un
        move.l  bv_rtp(a6),a1   now then, top of return table
        cmp.l   bv_rtbas(a6),a1 anything on stack?
        ble.s   rts8
        move.b  -rt.rsrtt(a6,a1.l),d5
        beq.s   gosub_0         yes, and it's a GOSUB
        bsr.l   undo_ret        unravel the return
        sub.w   #rt.lenpr,a1
gosub_0
        subq.l  #rt.lentl-rt.lenpr,a1
        move.l  a1,bv_rtp(a6)   set the return stack pointer down a level
        subq.b  #x.bfn,d5
        blt.s   nxt_un          GOSUB or PROCedure, do next
        move.l  bv_ntp(a6),a5
        subq.l  #8,a5           function, remove return value entry
nxt_exp
        moveq   #0,d2           unravel entries down to 1st non-internal
        jsr     ca_undo(pc)
        bne.s   nxt_exp
        move.l  a5,bv_ntp(a6)   reset the name table pointer
        bra.s   nxt_un

        end
