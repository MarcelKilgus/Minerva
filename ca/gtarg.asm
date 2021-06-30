* Get a set of arguments
        xdef    ca_gtint,ca_gtin1,ca_gtfp,ca_gtfp1,ca_gtlin,ca_gtli1
        xdef    ca_gtstr,ca_gtst1

        xref    ca_cnvrt,ca_etos
        xref    ri_lint

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_err'

        section ca_gtarg

* Generally, register useage is as follows
* d0 -  o- error code, ccr set
* d3 -  o- number of arguments (zero returned by ca_xxx1)
* a1 -  o- pointer on arithmetic stack to arguments (even if none now! lwr)
* a3 -i o- start of args
* a5 -i o- end of args
* d1-d2 destroyed (could save d2) (wow! used to zap d4/d6/a0/a2! no more - lwr)
* Exceptions are noted below

* d1 -  o- long integer found
* d3 -  o- 0
ca_gtli1
        bsr.s   ca_gtlin        get long integer argument
        move.l  0(a6,a1.l),d1   often useful
        bra.s   tchk_1          and check all alone

* d3 -  o- 0
ca_gtfp1
        bsr.s   ca_gtfp         get floating point argument
        bra.s   chk_1           and check one and only one

* d1 -  o- string length, extended to long
* d3 -  o- 0
ca_gtst1
        bsr.s   ca_gtstr        get string argument
        bra.s   gchk_1          and check just one

* d1 -  o- integer found, extended to long
* d3 -  o- 0
ca_gtin1
        bsr.s   ca_gtint        get integer argument
gchk_1
        move.w  0(a6,a1.l),d1   d1 often useful
        ext.l   d1              extended to long is convenient
tchk_1
        tst.l   d0
chk_1
        bne.s   rts0            was it ok?
        subq.w  #1,d3           how many args?
        beq.s   rts0            good, just the one
        moveq   #err.bp,d0      oh dear! we dinna get the single arg!
rts0
        rts

ca_gtstr
        moveq   #t.str,d0       get strings
        bra.s   get

ca_gtint
        moveq   #t.int,d0       get integers
        bra.s   get

ca_gtfp
        moveq   #t.fp,d0        get floating points
        bra.s   get

ca_gtlin
        moveq   #t.fp-128,d0    get floating points and make them long integers

regon   reg     d0/d4/a4-a5
regoff  reg     d1/d4/a4-a5
get
        moveq   #0,d3
        move.l  bv_rip(a6),a1   just in case we have no arguments
        movem.l regon,-(sp)
        bra.s   nxtarg

arg_loop
        moveq   #15,d4          mask out separator
        and.b   -7(a6,a5.l),d4
        jsr     ca_etos(pc)     evaluate to top of stack
        bne.s   retd0
        move.l  (sp),d0
        jsr     ca_cnvrt(pc)    do the conversion
        move.b  d4,-7(a6,a5.l)  and put original type back (why? unsafe? lwr)
        tst.l   d0              check error return
        bne.s   retd0
        tst.b   (sp)            were we after long integers?
        bpl.s   inc_arg
        jsr     ri_lint(pc)     yes, convert them then
        bne.s   retd0
        move.l  a1,bv_rip(a6)
inc_arg
        addq.l  #1,d3
        subq.l  #8,a5
nxtarg
        cmp.l   a3,a5           finished yet?
        bgt.s   arg_loop
        moveq   #0,d0           good return
retd0
        movem.l (sp)+,regoff    restore regs, discard top by putting in d1
        rts

        end
