* Evaluate machine code or basic function
        xdef    ca_fun

        xref    bv_upmcf
        xref    ca_carg,ca_garg
        xref    ib_call,ib_st2
        xref    sb_read

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ca_fun

* d0 -i o- input .b 0 = basic or $ff m/c / output err code
* d2 -  o- same as d0
* d4 -i  - name row of function
* a0 -i o- pointer to expression
* a1 -  o- bv_rip(a6)
* a3 -i  - function entry on name table
* a5 -i o- above arg
* d1/a2 destroyed (at least?)

ca_fun
        tst.b   d0
        bne.s   mcf

* Deal with a basic function

        move.l  a3,a2
        move.b  1(a6,a2.l),-7(a6,a5.l) type of return value
        moveq   #3,d5
        bsr.s   gtobr
        bne.s   no_args
        addq.l  #2,a0           step over the bracket
        moveq   #2,d5
no_args
        move.l  a0,a4           call works on a4
        sub.l   bv_bfp+4(a6),a0 wrt just above buffer
        move.l  a0,-(sp)        theory is that this is waiting when we ret
                ;               having been updated to point to endargs
        pea     sb_read(pc)     place to return after erroring in bf
        pea     ib_st2(pc)      place to return after doing...
        jmp     ib_call(pc)     ...this

gtobr
        cmp.b   #b.spc,0(a6,a0.l) is current token a space?
        bne.s   chk_obr
        addq.l  #2,a0
chk_obr
        cmp.w   #w.opar,0(a6,a0.l) is it a ( ?
        rts

* All machine code functions return the result on the RI stack and the type
* of the result in d4

err_xp
        moveq   #err.xp,d0
carg
        add.l   bv_ntbas(a6),a3
        jmp     ca_carg(pc)     (this moves a5 down to a3 for us)

mcf
        move.l  4(a6,a3.l),a2   set the function address
        move.l  a5,a3
        sub.l   bv_ntbas(a6),a3 base of name table
        bsr.s   gtobr           get the open bracket
        bne.s   get_fadd        no open bracket - no arguments
        addq.l  #2,a0           move over the opening bracket
        jsr     ca_garg(pc)     get all the function arguments
        bne.s   carg            summat up
        cmp.w   #w.cpar,d1      finish with a close bracket ?
        bne.s   err_xp
        addq.l  #2,a0           yes, skip it
get_fadd
        move.l  bv_ntbas(a6),a4 base of name table
        sub.l   a4,a5           offset of top of args on NT
        sub.l   bv_bfp+4(a6),a0
        move.l  bv_rip(a6),a1
        sub.l   bv_ribas(a6),a1 save where ri stack is
        movem.l d5-d7/a0-a1/a3/a5,-(sp) save stuff
        moveq   #0,d7           absolute guarantee of d7.l zero
        add.l   a4,a3
        add.l   a4,a5
        tst.b   bv_uproc(a6)    is there a user trace procedure?
        bpl.s   noup
        jsr     bv_upmcf(pc)    yes - go do it
noup
        jsr     (a2)            do the function
        movem.l (sp)+,d5-d7/a0-a1/a3/a5
        add.l   bv_bfp+4(a6),a0
        add.l   bv_ntbas(a6),a5
        bsr.s   carg            clear the args
        bne.s   error
        move.b  d4,-7(a6,a5.l)  set the type of the result
        addq.b  #t.intern,-8(a6,a5.l) set to internal (was zero)
        move.l  bv_rip(a6),a1   relax requirement for functions to get a1 right
tstd0
        move.l  d0,d2
        rts

error
        add.l   bv_ribas(a6),a1
        move.l  a1,bv_rip(a6)   restore RI stack pointer if rubbish around
        bra.s   tstd0

        end
