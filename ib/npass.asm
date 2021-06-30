* Name pass. Set all name types in file
        xdef    ib_npass,ib_nxcom,ib_nxnam,ib_nxnon,ib_s2non,ib_s4non

        xref    ib_eos,ib_nxtk
        xref    ca_frvar

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ib_npass

* d0-d5/a0/a2 destroyed (did also zap d6... doesn't now)
* ccr not meaningful
* bv_edit used/cleared
* Variable table tidied up, duff values thrown out
* Happens to return d5=0 unless... what was I going to say?

ib_npass
        move.l  a4,-(sp)
* Set mask for interesting keywords
        move.l  #1<<b.for!1<<b.rep!1<<b.def!1<<b.else!1<<b.dim!1<<b.let,d4
        tst.b   bv_sing(a6)     is the single line flag set
        beq.s   doprog          no - skip this bit
        move.l  bv_tkbas(a6),a4 do token list first
        moveq   #0,d5
        bsr.s   doline
doprog
        tst.b   bv_edit(a6)     has program been edited since last npass?
        sf      bv_edit(a6)     ..clear flag anyway
        beq.s   return          no change, pointless going thro' it again
        move.l  bv_pfbas(a6),a4 beg of program file
        bra.s   progent

proglp
        move.w  -2(a6,a4.l),d5  save linum in case this is a def stat
        bsr.s   doline
progent
        addq.l  #6,a4           skip pre-word and line number
        cmp.l   bv_pfp(a6),a4
        blt.s   proglp
return
        move.l  (sp)+,a4
rts0
        rts

is_nam
        move.l  a4,d3           save pointer to name
        bsr.s   ib_s4non        move past it and get next token
        cmp.w   #w.equal,d1
        bne.s   nxstat          only interested in {let} name =
        move.l  d3,a4           go back to name
varnam
        moveq   #t.var,d3       this should be a simple variable
othnam
        bsr.s   fillnam         go make sure we are ok on usage of this name
nxstat
        jsr     ib_eos(pc)      skip to end of this statement
        addq.l  #2,a4           skip whatever that was (:/then/else/nl)
        blt.s   rts0            if end of line, get out
doline
        bsr.s   ib_nxnon        find token at start of this statement
        sub.b   #b.nam,d0
        beq.s   is_nam          a name, so go see about it
        addq.b  #b.nam-b.key,d0
        bne.s   nxstat          not a keyword, so we don't want it
        addq.l  #2,a4           skip the keyword token
* Decide what to do about the keyword, if anything
        btst    d1,d4
        beq.s   nxstat          not interested in this statement at all
        assert  0,b.for-2,b.rep-4,b.def-7,b.else-20,b.dim-25,b.let-27
        subq.b  #b.def,d1
        ble.s   is_frd
        assert  0,(b.else-b.def)&2,(b.dim-b.def)&2-2,(b.let-b.def)&2
        lsr.b   #2,d1           move bit 1 to carry, to distiguish just dim
        bcc.s   doline          note that else can come as statement start
* Also note that we always expect a name after let, so we can ignore it!
        subq.l  #2,a4           backspace to start loop for dim
is_dim
        bsr.s   ib_nxnam        go find a name
        beq.s   nxstat          dim all done, go for next statement
        moveq   #t.arr,d3       want an array name here
        bsr.s   fillnam         go check it out
        bra.s   is_dim

*is_rep
*       bsr.s   ib_nxnon        get token after repeat
*       cmp.b   #b.nam,d0       is it a name (??? what else can it be? lwr)
*       bne.s   nxstat          no - forget it
*       bra.s   varnam          go check it's a simple variable (at least?)
*is_for
is_frd
        beq.s   is_def
        bsr.s   ib_nxnon        get name following for
        bra.s   varnam          it should be a simple variable

is_def
        bsr.s   ib_nxnon        get keyword after define
        move.b  d1,d3           save it
        bsr.s   ib_s2non        skip it and get name token
        assert  b.proc-t.bpr,b.fn-t.bfn
        subq.b  #b.proc-t.bpr,d3
        bra.s   othnam          go verify basic proc/fn here

ib_s4non
        addq.l  #2,a4           move past half of current token
ib_s2non
        addq.l  #2,a4           move past current token
ib_nxnon
        move.b  0(a6,a4.l),d0   look at current token
        cmp.b   #b.spc,d0       space?
        beq.s   ib_s2non        yes, then skip it
        move.w  0(a6,a4.l),d1   get the full token
        rts

fillnam
        moveq   #0,d0
        move.w  2(a6,a4.l),d0   pick up index
        lsl.l   #3,d0
        move.l  bv_ntbas(a6),a2
        add.l   d0,a2           form name table pointer
        move.b  0(a6,a2.l),d0   have a look before we commit ourselves
        cmp.b   d0,d3           are they the same?
        beq.s   set_type        yes - leave well enough alone
        subq.b  #t.var,d0       is it already a simple variable
        blt.s   set_type        unset or internal, so set it
        beq.s   free_set        variable, free and set
        subq.b  #t.arr-t.var,d0
        beq.s   rts1            already an array, so can't reset
        subq.b  #t.bfn-t.arr,d0
        ble.s   proc_fn         basic proc/fn
        subq.b  #t.mcp-t.bfn,d0
        blt.s   free_set        rep/for, free and reset; mcpr/mcfn, check
proc_fn
        cmp.b   #t.bpr,d3
        bge.s   set_type        only reset proc/fn to proc/fn
free_set
        jsr     ca_frvar(pc)    d1/a0 destroyed, d0=error
        bne.s   rts1            couldn't free it so don't reset either
set_type
        move.b  d3,0(a6,a2.l)   replace it
        subq.b  #t.bpr,d3       is this a basic procedure or function?
        blt.s   rts1
        move.w  d5,4(a6,a2.l)   yes, then set the line number
rts1
        rts

* Look next name or comma token, ignoring anything in nested parentheses

* ccr z set if not found
* d1 -i o- msw preserved, lsw zero
* a4 -i o- pointer to tokenised line. 1st token skipped, ends at found or eos
* d0-d3 destroyed

* (d0.lsb only is changed: b.nam if found nxnam, otherwise always b.sym)
* (d2.l set to 2 by nxcom, lsw only set to $03fe by nxnam)
* (d3.l=$ff if found, or not found but 255 levels down!)
* We actually scan over a " ... ) ... ( ... " pairing - maybe we shouldn't?

ib_nxnam
        move.w  #w.nam-w.colon,d2
        bra.s   nxone

ib_nxcom
        moveq   #w.symcom-w.colon,d2
nxone
        moveq   #1,d3           nest level
sub1
        subq.b  #2,d3           decrement nest level
add1
        addq.b  #1,d3           increment nest level
loop
        jsr     ib_nxtk(pc)
        sub.w   #w.eol,d1
        beq.s   rts2            exit at end of line
        addq.w  #w.eol-w.cpar,d1
        beq.s   sub1            pop level on close parenthesis
        addq.w  #w.cpar-w.opar,d1
        beq.s   add1            push level on open parenthesis
        addq.w  #w.opar-w.colon,d1
        beq.s   rts2            exit at colon
        sub.w   d2,d1           is this what we are looking for ?
        bne.s   loop            no, keep going
        subq.b  #1,d3           are we outside sets of brackets?
        bcc.s   add1            no, keep going
rts2
        rts

        end
