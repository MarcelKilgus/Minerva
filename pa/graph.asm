* Main parsing routine
        xdef    pa_graph,pa_tbsym

        xref    bv_chbt,bv_chss
        xref    pa_cdlno,pa_cdmon,pa_cdnam,pa_cdnum,pa_cdops,pa_cdsep,pa_cdspc
        xref    pa_cdstr,pa_cdsyv,pa_cdtxt,pa_cdval,pa_kywrd,pa_tok1

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_token'
        include 'dev7_m_inc_vect4000'

* This is now totally changed. The "TG" stack is discarded in favour of a
* simpler scheme.

* Backtracking was only needed in two instances.

* The first instance was the constructs "ON var = expr" and "ON expr GO ...",
* and the second was "var = expr" versus "name(expr)=expr sep ...". By
* suitably augmenting the syntax tables to parse the latter contruct in each
* case as a graph, the need for backtracking of the nature used in the original
* system dissappears!

* The "BT" stack is now organised as follows:

        offset  0
svbf    ds.l    1       saved basic buffer rel a6 long pointer
svtk    ds.l    1       saved token list rel a6 long pointer
svgr    ds.l    1       saved graph absolute long pointer * 2 (lsb is a flag)
elen    ;               entries are 12 bytes
flge    equ     elen-1  flag in lsb of last byte

* The top entry contains the "current" BF/TK pair and the gr entry records
* where the graph was entered from.
* The flag is clear when we first enter a graph. If we see a "possible exit",
* the current BF/TK pair is copied up over the pair above, and the flag is set.
* When we reach an "end of possibilies" the flag is examined. If it has been
* set, the graph is exited with "success". Otherwise, the graph fails. Also,
* should we see a "definate exit", the current BF/TK pointers are also copied
* up, but the flag is ignored and success is always the case.
* The top of the whole parse is recognised by having the gr entry zero.
* although the top level in the ROM tables never uses the "possible exit" code,
* for completeness, the eight bytes of space for an extra BF/TK pair is built
* initially.

        section pa_graph

cd_tab
        dc.w    pa_cdnam-cd_jsr
        dc.w    pa_cdval-cd_jsr
        dc.w    pa_cdnum-cd_jsr
        dc.w    pa_cdsyv-cd_jsr
        dc.w    pa_cdops-cd_jsr
        dc.w    pa_cdmon-cd_jsr
        dc.w    pa_cdsep-cd_jsr
        dc.w    pa_cdstr-cd_jsr
        dc.w    pa_cdtxt-cd_jsr
        dc.w    pa_cdlno-cd_jsr

* d0 -  o- error code: negative parse failed, 0 ok or positive to reqest undo
* a0 -  o- input buffer, on ok return, it will be at the end of parsed text
* a2 -i  - start of graph tables
* a4 -  o- if parse failed, buffer location where we last had any luck
* a6 -ip - pointer to basic area
* d1-d6/a1/a3/a5 destroyed

* As far as is possible (so far) during the code, a2 holds the current
* backtrack stack pointer and a3, the token list pointer.

pa_graph
        move.l  (a2)+,-(sp)     save keyword entry
        move.l  (a2),-(sp)      save graph table entry
        move.l  bv_btbas(a6),bv_btp(a6) reset backtrack pointer
        move.l  bv_tkbas(a6),a3 get start of token list
        move.l  a3,bv_tkp(a6)   reset token list pointer
        jsr     bv_chss(pc)     check enough room on ss for parser
*       moveq   #0,d7           set d7 to zero for ever (it's ok to drop this?)
        jsr     bv_chbt(pc)     a smidgen of space on the BT stack
        subq.l  #8,bv_btp(a6)   set up initial required bytes for top BF/TK
        move.l  bv_btp(a6),a2
        move.l  bv_bfbas(a6),a0 set a0 to start of input buffer
        move.l  a0,a4           set best so far
        moveq   #2,d6           first entry is start point for a line
        sub.l   a5,a5           marker for top of stack
morebt
        jsr     bv_chbt(pc)
        move.l  bv_btp(a6),a2
graf1st
        sub.w   #elen,a2
        cmp.l   bv_btp-4(a6),a2
        blt.s   morebt
        move.l  a2,bv_btp(a6)
        add.l   a5,a5           clear flag
        move.l  a5,svgr(a6,a2.l)
        move.l  (sp),a5         start of graphs
        add.w   -2(a5,d6.w),a5  set new graph offset
        bra.s   newposs

code1st
        bmi.s   symb1st
* Bits 7-5 clear, posibility is a coded atom
        move.l  4(sp),a2        point to keywords as code might be a name
        lsr.b   #3,d6
        add.b   d6,d6
        move.w  cd_tab-2(pc,d6.w),d6 get code offset
cd_jsr
        jsr     cd_jsr(pc,d6.w) go do requested routine
        bra.s   fail1st
        bra.s   ok1st

kywd1st
        lsl.b   #2,d6
        bcc.s   code1st
* Bit 6 set, possibility is a keyword
        move.l  4(sp),a2        start of keywords
        lsr.b   #3,d6           put keyword number straight
        jsr     pa_kywrd(pc)    see if it matches
        bra.s   fail1st         nope - too bad
        moveq   #b.key,d4       keyword token
        move.b  d6,d5           keyword number
        bra.s   tok1st

fail1st
        move.l  bv_btp(a6),a2   get BT pointer
        movem.l svbf(a6,a2.l),a0/a3 move buffer and token pointers back
        move.l  a3,bv_tkp(a6)   set token position, in case it moved...
skp2nd
        addq.l  #1,a5           look at next possibility
get1st
        moveq   #0,d6           clear all of d6
        move.b  (a5)+,d6        put possibility into d6
        beq.s   eoposs          if end of possibilities, go back
        bpl.s   kywd1st
* Bit 7 set, possibility is an exit or graph
        and.b   #$7e,d6         clear bits 7 and 0
        bne.s   graf1st         go do it if it's a real graph
        movem.l a0/a3,svbf+elen(a6,a2.l) record exit buffer and token pointers
        bset    d6,flge(a6,a2.l) mark this as a possible exit
        bra.s   get1st          carry on

symb1st
* Bit 5 set, possibility is a symbol
        lsr.b   #3,d6           get actual symbol number (+16)
        move.b  0(a6,a0.l),d1   next char in buffer
        cmp.b   pa_tbsym-1-16(pc,d6.w),d1 is character the required symbol?
        bne.s   skp2nd          no - just skip it
        addq.l  #1,a0           move past the character
        moveq   #b.sym,d4       symbol token
        moveq   #15,d5
        and.b   d6,d5           symbol number
tok1st
        jsr     pa_tok1(pc)     put the two byte token in the list
ok1st
        move.l  bv_btp(a6),a2
get2nd
        move.b  (a5),d6         look at linked position
        beq.s   isexit          if zero, graph is completed ok
do2nd
        ext.w   d6              make byte 2 into a word offset
        add.w   d6,a5           move to linked position
newposs
        cmp.b   #' ',0(a6,a0.l) are we at a space?
        bne.s   nospace
        jsr     pa_cdspc(pc)    tokenise any preceeding spaces
        move.l  bv_btp(a6),a2   this can have moved... annoying
nospace
        movem.l a0/a3,svbf(a6,a2.l) remember where we are in buffer and tokens
        bra.s   get1st          go work on it

eoposs
        cmp.l   a0,a4
        bgt.s   popout
        move.l  a0,a4           remember best in the buffer we got to
popout
        add.w   #elen,a2
        move.l  a2,bv_btp(a6)   set backtrack stack level 
        movem.l svbf-4(a6,a2.l),d0/a0/a3 pick up saved GR/BF/TK pointers
        move.l  a3,bv_tkp(a6)   reset token list to this point
        lsr.l   #1,d0           have we seen a possible exit?
        move.l  d0,a5
        bcs.s   qdone           yes, steam ahead, if we haven't finished
        bne.s   skp2nd          not at top, go fail this one
        moveq   #-1,d0          we are at the top, so the parse has failed
        bra.s   parsex

isexit
        add.w   #elen,a2        graph matched, so pop return point
        move.l  a2,bv_btp(a6)   set backtrack stack to new position
        move.l  svbf-4(a6,a2.l),d0 pick up old graph position
        lsr.l   #1,d0           is that now zero?
        move.l  d0,a5
qdone
        bne.s   get2nd          no - go down 2nd byte, otherwise completed ok!
parsex
        addq.l  #8,sp
pa_ini ; just so people who call this don't get confused!
        rts

pa_tbsym dc.b '=:#,(){} ',10 symbols including line feed

        vect4000 pa_graph,pa_ini

        end
