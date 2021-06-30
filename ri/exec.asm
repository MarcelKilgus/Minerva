* Execute RI functions
        xdef    ri_abex,ri_abexb,ri_exec,ri_execb
* Various "xref"'s defined via macro

        include 'dev7_m_inc_ri'

        section ri_exec

tab     macro
        local   i,p
i       setnum  0
loop    maclab
i       setnum  [i]+1
p       setstr  [.parm([i])]
        ifstr   {[p]} = {e} goto dcit
        xref    ri_[p]
dcit    maclab
        dc.w    ri_[p]-ri_e
        ifnum   [i] < [.nparms] goto loop
        endm

exec_tab
 tab e     one   nint  zero  int   n     nlint k     ;00-07
 tab float flong add   cmp   sub   halve mult  doubl ;08-0f
 tab div   recip abs   roll  neg   over  dup   swap  ;10-17
 tab cos   e     sin   e     tan   e     cot   e     ;18-1f
 tab asin  e     acos  e     atan  arg   acot  mod   ;20-27
 tab sqrt  squar ln    e     log10 e     exp   power ;28-2f
 tab powfp                                           ;30

* abex and abexb used to clear d2 on error. They don't now, as gw is sensible.

* d0 -i o- instruction code / error code
* a1 -i o- arithmetic stack pointer
* a3 -ip - pointer to instructions
* a4 -ip - base (high address) of arithmetic load/save area

reglist reg d1-d3/a0/a2-a3/a5

ri_abex
        move.l  a6,-(sp)        absolute a1 and a4 entry for exec
        sub.l   a6,a6
        bsr.s   ri_exec
        bra.s   rst_a6

ri_abexb
        move.l  a6,-(sp)        absolute a1 and a4 entry for execb
        sub.l   a6,a6
        bsr.s   ri_execb
rst_a6
        move.l (sp)+,a6
        rts

ri_exec
        movem.l reglist,-(sp)
        or.w    #-256,d0        make it how we like it
        lea     exec_tab,a5     no operations to follow
        bra.s   exec_do

ri_execb
        movem.l reglist,-(sp)
        move.l  a3,a5           set internal pointer to ops
        bra.s   exec_nxt        enter loop

* Non-command odd d0, store a float in the a4 area

store
        move.w  0(a6,a1.l),0(a6,a4.l) store a floating point number
        move.l  2(a6,a1.l),2(a6,a4.l)
        addq.l  #6,a1           remove operand
        bra.s   rst_a4

not_op
        bclr    #0,d0           test bit 0 of operand
        add.w   d0,a4           move to source / destination
        bne.s   store           choose load or store on bit zero d0

* Non-command even d0, load a float from the a4 area

        subq.l  #6,a1           make room for operand
        move.w  0(a6,a4.l),0(a6,a1.l) load a floating point number
        move.l  2(a6,a4.l),2(a6,a1.l)
rst_a4
        sub.w   d0,a4           restore a4 to base address
exec_nxt
        moveq   #-256+(255),d0  ready for anything!
        move.b  (a5)+,d0        fetch next instruction byte
exec_do
        cmp.b   #ri.maxop,d0    is it an operator?
        bhi.s   not_op          no, load or save
        add.b   d0,d0
        move.w  exec_tab+256(pc,d0.w),d0 get offset from table
        jsr     ri_e(pc,d0.w)   go do it
        beq.s   exec_nxt        loop if no problem detected
        bra.s   exit_b          otherwise, we're finished

ri_e
        addq.l  #4,sp           scrap return address
        moveq   #0,d0           no error
exit_b
        movem.l (sp)+,reglist
        rts

        end
