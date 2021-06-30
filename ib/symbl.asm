* Symbol at start of line, find an endselect
        xdef    ib_fchk,ib_on,ib_symbl

        xref    ib_chinl,ib_eos,ib_nxnon,ib_nxst,ib_ongo,ib_s4non

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_token'

        section ib_symbl

ib_on
        jsr     ib_nxnon(pc)    get a non-space
        cmp.w   #w.nam,d1       is it a name?
        bne.s   ongo            no, it's not an "ON var =" then
        move.l  a4,d3           remember where we are
        jsr     ib_s4non(pc)    step past name and get next non-space
        cmp.w   #w.equal,d1     is this really an "ON var =" line?
        beq.s   fends           yes, last on exhausted, find the end_sel
        move.l  d3,a4           go back to name, it's part of an "ON <expr> go"
ongo
        jmp     ib_ongo(pc)     go there

* a4 -i o- program file pointer
* d0 -  o- return code
* d1 -i  - 1st word of token

ib_symbl
        cmp.w   #w.equal,d1     if statement doesn't start with "=", ignore it
        bne.s   okrts
        addq.l  #2,a4           skip the "="
fends
        moveq   #-1,d3          nest count
add1
        addq.w  #1,d3
nxstat
        bsr.s   ib_fchk         find next statement and check it
        bne.s   nxstat          not starting with a keyword
        addq.l  #2,a4
        subq.b  #b.sel,d1       SELect?
        beq.s   do_sel
        addq.b  #b.sel-b.end,d1 END?
        bne.s   nxstat
        jsr     ib_nxnon(pc)
        cmp.w   #w.sel,d1       END SEL?
        bne.s   nxstat
        dbra    d3,nxstat       reduce level and carry on if still nested
okrts
        moveq   #0,d0
        rts

do_sel
        tst.b   bv_inlin(a6)    are we already doing an in-line ?
        bne.s   add1            yes, inc nest count
        jsr     ib_chinl(pc)    is it an in-line select
        blt.s   add1            no, inc nest count
skip
        jsr     ib_eos(pc)      get end of statement
        blt.s   nxstat          got there
        addq.l  #2,a4           move over token
        bra.s   skip            and have another go

* Skip return and set d0=0 if at end of possibles
* Otherwise set ccr z iff line starts with a keyword

ib_fchk
        jsr     ib_nxst(pc)
        bne.s   lf              end of file or end of single line
        tst.b   d0              (from nxst) is this a new line?
        beq.s   keytst          ..no
        tst.b   bv_inlin(a6)    is the sel an in-line clause?
        beq.s   keytst          ..no

* New line and in-line clause, so finish what we've got and put PF in
* the right place to continue execution

        subq.l  #8,a4           back over line number,length & line feed
        move.w  2(a6,a4.l),d0   take off length or it gets added twice
        sub.w   d0,bv_lengt(a6) and the whole thing blows up
lf
        tst.b   bv_inlin(a6)
        bgt.s   end_1           don't turn off flag if for/rep
        sf      bv_inlin(a6)    turn off the flag if sel/if
end_1
        addq.l  #4,sp           discard return
        bra.s   okrts

keytst
        jsr     ib_nxnon(pc)
        cmp.b   #b.key,d0       is it a keyword?
        rts

        end
