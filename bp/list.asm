* List (or delete) part or all of a program
        xdef    bp_list,bp_list2,bp_listd,bp_liste,bp_listf,bp_listr
        xdef    bp_chkls,bp_dline,bp_detok,bp_gsep,bp_gint,bp_lsqzp,bp_lszap

* bp_listf is provided for a quicker entry point for tk2's ed.

        xref    bp_chand,bp_chunr
        xref    bv_chri,bv_chbfx,bv_chlnx,bv_clrt
        xref    ca_etos,ca_cnvrt
        xref    cn_ftod,cn_0tod
        xref    ib_glin0,ib_glin1,ib_nxtk,ib_steof,ib_whdel
        xref    mm_mrtor
        xref    pa_table,pa_tbops,pa_tbmon,pa_tbsep,pa_tbsym

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_choff'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_token'
        include 'dev7_m_inc_assert'

* Note: entry points bp_lista and bp_lists were unused, code moved to pf_relst.
* Also, the vector which is supposed to go to bp_liste gets here via pf_liste.

c.defls equ     2       default listing channel number

        section bp_list

* Gets separator type from name table.
bp_gsep
        addq.l  #8,a3           advance over argument
        move.b  -7(a6,a3.l),d5  get vt and st
        lsr.b   #4,d5           separator only
        and.b   #15,-7(a6,a3.l) wipe it out of argument and set z if no arg
rts0
        rts

* Basic DLINE. Uses a lot of routines shared with LIST.

* a3 -i  - base of args
* a5 -i  - top of args
* d0-d7/a0-a1/a3-a4 destroyed

* d4 lower line to write
* d5 separator type
* d6 upper line to write
* a0 where to write to
* a2 keyword table
* a4 program file

bp_dline
        cmp.l   a5,a3
        beq.s   rts0            refuse to consider no args as delete all!
        st      d7              tell rest of prog we're deleting

* Implements basic keyword LIST

* a0 - l - where to write to
* a2 - l - keyword table
* a3 -i  - base of args
* a4 - l - program file
* a5 -i o- top of args
* d4 - l - lower line to write
* d5 - l - separator type
* d6 - l - upper line to write

bp_list
        moveq   #c.defls,d1     if no # given, use 2
        jsr     bp_chand(pc)
        bne.s   rts0

* Lists a program like bp_list except that it does not set or check the output
* channel - it is used to list to devices. E.g. in SAVE.

* a0 - l - where to write to
* a2 - l - keyword table
* a3 -i  - base of args
* a4 - l - program file
* a5 -i  - top of args
* d4 - l - lower line to write
* d5 - l - separator type
* d6 - l - upper line to write

bp_listd
        tst.b   d7
        beq.s   notdel
        jsr     bp_chunr(pc)    never get caught by delete via list entry point
notdel
        moveq   #0,d4           default from start of program
        move.w  d4,bv_lsfil(a6) turn fill screen flag off
        st      bv_print(a6)    turn print flag on for list, save
        sub.l   a3,a5
        move.l  a5,-(sp)        keep number of bytes of args on top of stack
        ble.s   set_hi          no args at all - this will list all

get_rng
        moveq   #0,d1           default start from zero
        subq.l  #8,(sp)         one less arg remaining
        bsr.s   bp_gsep         gets separator and checks for an argument
        beq.s   set_fst         no arg, d1 is ready
        bsr.s   bp_gint
        bne.s   popret
set_fst
        move.w  d1,d4           first line, and also default last

        cmp.b   #b.septo,d5     is this a range?
        bne.s   set_lst         no - go check end of range
        tst.l   (sp)            any args left?
        ble.s   set_hi          no - default to end of program
        subq.l  #8,(sp)         one less arg remaining
        bsr.s   bp_gsep         get new sep and check for arg
        beq.s   set_hi          if none, go set highest
        bsr.s   bp_gint         get last line number to list
        bne.s   popret
set_lst

        move.w  d1,d6           check last
        bne.s   lstrdy          ok if it's not zero
        tst.b   d7              do not want to delete the whole file
        bne.s   skip_it         unless they tell us properly
set_hi
        move.w  #32767,d6       highest possible line number
lstrdy

        cmp.w   d4,d6           check first line not greater than last
        blo.s   skip_it         ignore reversed ranges (used to show as error)
        tst.b   d7
        beq.s   goliste         if list, go do it straight away
        cmp.w   bv_lsbef(a6),d6
        bls.s   goliste         range wholely before screen
        cmp.w   bv_lsaft(a6),d4
        bhs.s   goliste         range wholely after screen
        ext.w   d7              remember we've affected the screen, if a delete
goliste
        sub.l   bv_ntp(a6),a3   gotta protect this against basic buffer shifts!
        bsr.l   bp_liste        actually do the listing/deleting!
        add.l   bv_ntp(a6),a3
skip_it

        move.l  (sp),d2         have we run out of arguments?
        ble.s   end_rng         yes, we're all done
        subq.b  #b.sepcom,d5    was sep a comma?
        beq.s   get_rng         yes, go do next range, otherwise it's an error
badret
        moveq   #err.bp,d0
        bra.s   popret

end_rng
        move.w  d7,d3           if this dline affected the screen we relist
        bpl.s   okpop
        bsr.l   bp_chkls        ah! but is this really the list channel?
        bne.s   okpop           no - so forget it! (e.g. DLINE#0 for no relist)
        bsr.s   relist          list from top (d2.w=0), deleted range (d3.b<0)
okpop
        moveq   #0,d0
popret
        addq.l  #4,sp
        rts

* Gets a positive integer on the ri stack from the argument pointed
* to by a3 and a5, converting from f.p. if necessary.

* d0 -  o- error return
* d1 -  o- (.w) 1..32767 result, if all ok
* a1 -  o- ri stack top where d1 was, bv_rip updated past it
* a3 -ip - nt top
* a5 -  o- copy of a3
* d2/a4 destroyed

bp_gint
        move.l  a3,a5
        jsr     ca_etos(pc)     get it on top of stack
        bne.s   rts2
        moveq   #t.int,d0
        jsr     ca_cnvrt(pc)    turn it into an integer
        bne.s   rts2
        addq.l  #2,bv_rip(a6)
        move.w  0(a6,a1.l),d1   have the idiots put in a zero or negative no?
        bgt.s   tstrts
        moveq   #err.bp,d0
tstrts
        tst.l   d0
rts2
        rts

* Note: there does not seem to be any great attempt to leave registers
* in any predictable state on return. May be able to do optimisation...

* Relist the current screen for a renum
bp_listr
        moveq   #0,d2           make line number the special, list all
        moveq   #0,d3           look as if a replaced line has happened
* Relist on list channel if d2/d3 implies screen should change
bp_list2
        bsr.s   pickls          get the list channel
        bmi.s   rts2
        move.l  d0,a0

* d2 -i  - line number in question, 0 for from top to fill
* d3 -ip - +ve for inserted line
*          0   for replaced line
*          -ve for deleted line
* a0 -ip - list channel id
* d0-d1/d4/d6/a1-a2/a4 destroyed

relist
        move.l  bv_lnbas(a6),a1 line number table
        cmp.l   bv_lnp(a6),a1   is there anything on the screen yet?
        beq.s   just_d2         no - go list just d2
* There was an attempt at clearing d0 above, but there's no reason to?
        move.w  0(a6,a1.l),d4   top line number on screen
        tst.w   d2              is current line set?
        bne.s   cur_set
        move.w  d4,d2           no - current line set to top
cur_set
        assert  bv_lsbef,bv_lsbas-2,bv_lsaft-4,bv_maxln-8,bv_totln-10
        movem.w bv_lsbef(a6),d0-d1/d6/a1-a2/a4
        cmp.w   d0,d2           lsbef: is lno before invisible top line?
        bcs.s   rts1            yes, do nothing
        cmp.w   d4,d2           is it between bef and top?
        bcs.s   top             yes, only print if not deleted
        cmp.w   d6,d2           lsaft: if after invisible base line, get out
        bhi.s   rts1
        cmp.w   d6,d2           is it between bas and aft?
        bhi.s   basdel          yes, only print if not deleted
        tst.b   d3
        bpl.s   print1          lsbas: insert/mofify, print top to bas
        bra.s   print6          lsaft: deleted, print top to aft

just_d2
        move.w  d2,d4           set current line as the first in the range
        bne.s   prtod2          fill to the bottom of the window
rts1
        rts

basdel
        tst.b   d3              print top (which will disappear) to lno
        bmi.s   rts1            not interested if a deleted line
prtod2
        move.w  d2,d6
        bra.s   print6

top
        tst.b   d3              not interested if not new or updated
        bmi.s   rts1
        move.w  d2,d4
        cmp.w   a2,a4           maxln/totln
        blt.s   print1          if not yet full, print all the way to bas
        subq.w  #1,d1           print lno to one before bas (should work)
print1
        move.w  d1,d6
print6
        move.w  d2,bv_lsfil(a6) fill the screen at least to this line
        moveq   #sd.pos,d0      put the cursor
        moveq   #0,d2           at the top
        moveq   #0,d1           left hand corner
        bsr.s   trap_3
        st      bv_print(a6)    turn print on
        bsr.l   listp           list from d4 to d6 inclusive
        moveq   #sd.clrrt,d0    clear to right of cursor
        bsr.s   trap_3
; Already done the above, assuming anything was listed at all!
; It is needed if we are called to list a deleted range, and nothing is left
        moveq   #sd.clrbt,d0    clear bottom of screen
trap_3
        bra.l   trap3

* Pick up list channel into d0, return -ve if not present or closed
pickls
        moveq   #-(c.defls+1)*ch.lench,d0
        add.l   bv_chp(a6),d0
        sub.l   bv_chbas(a6),d0 actually check if list channel exists!
        bmi.s   nolstch         if not, d0 should be negative
        move.l  bv_chbas(a6),d0
        move.l  ch.lench*c.defls(a6,d0.l),d0 get listing channel id
nolstch
        rts

* Lists or deletes program lines in range indicated by d4 and d6

* d4 -i  - lower line to write
* d6 -i  - upper line to write
* d7 -ip - if zero, list, else delete lines in range
* a0 -ip - where to write to
* d0-d3/a1-a2/a4 destroyed

* This entry point preserved for vector entry.
bp_liste
        tst.b   d7              listing or deleting?
        beq.s   listp           if list, go there
        jsr     ib_glin0(pc)    go to the line number required
        ble.s   okrts           we won't take the slightest notice if off top
        move.w  4(a6,a4.l),d2   get current lno
        cmp.w   d2,d6           are we deleting a null range?
        blo.s   okrts           amazing, the things people think up
        cmp.w   bv_linum(a6),d2 are we deleting before, or including ourself?
        bhi.s   delok
        jsr     ib_steof(pc)    yes - make sure we don't continue!
delok
        jsr     ib_whdel(pc)    tell when processing which lines are going
* whdel gets d2/d6 and can zap d0/a2, at least, plus a4 is easy to restore
        move.w  d6,d4           set top line to search for
        addq.w  #1,d4           n.b. 32767->32768, but glin1 uses unsigned cmps
        move.w  d1,d6           save prior line length
        move.l  a0,-(sp)        save channel ID
        move.l  a4,a0           where to shift code down to
        jsr     ib_glin1(pc)    position past top line of range
        ble.s   put_pfp         at top of program, so nowt to copy
        sub.w   d6,d1
        add.w   d1,0(a6,a4.l)   correct the line length change word
        move.l  a4,a1           source from remaining program lines
        move.l  d2,d1
        sub.l   a1,d1           length
        jsr     mm_mrtor(pc)    fast copy
        add.l   d1,a0           new top
put_pfp
        st      bv_edit(a6)     this wasn't being done before!
        move.l  a0,bv_pfp(a6)   store new top of program
        move.l  (sp)+,a0        restore channel ID
okrts
        moveq   #0,d0
        rts

* Verify if the current channel id is that of the listing channel (#2)

* d0 -  o- the listing window id, ccr z set if d0=a0, made -ve if no list chan
* a0 -ip - channel id

bp_chkls
        bsr.s   pickls
        bmi.s   notlst
        cmp.l   a0,d0           returns eq if this is the listing window
notlst
        rts

* Check if a0 is list channel, and if so wipe out current list info
* d0 -  o- 0 iff ccr=Z
* a0 -ip - channel id in question
bp_lsqzp
        bsr.s   bp_chkls
        bne.s   notlst
* Zap list info
* d0 -  o- 0
bp_lszap
        moveq   #0,d0
initls
        move.l  bv_lnbas(a6),bv_lnp(a6) empty table
        move.w  d0,bv_lsbef(a6)
        assert  bv_lsbef,bv_lsbas-2
        move.l  d0,bv_lsbas(a6)
        rts

* Detokenise a line

* d4 -i o- line number to detokenise / keyword table pointer
* d6 -  o- as d4 input
* a4 -  o- pre-word of last line examined
* d0-d3/a1-a2 destroyed

bp_detok
        move.w  d4,d6           (also top line)
        sf      bv_print(a6)    turn print off
listp
        jsr     ib_glin0(pc)    go to the line number required
        sub.l   a2,a2           make invisible top line be zero
        cmp.l   a4,d0           check if at first line of program
        beq.s   bp_listf        if so, top line zero is ready if we need it
        move.l  a4,a2
        sub.w   d1,a2
        move.w  4(a6,a2.l),a2   fetch a genuine invisible top line

* d0 -i  - pfbas
* d4 -  o- keyword table pointer
* d6 -ip - line number to stop printing at
* a0 -ip - channel id to print to
* a2 -i  - invisible top line (one before a4)
* a4 -i o- pre-word of first line to print / pre-word of last line examined
* d1-d3/a1 destroyed

bp_listf
        move.l  a0,-(sp)        save channel id
        move.b  bv_print(a6),bv_lsany(a6) see if we are printing at all
        beq.s   lnskip          nope, so don't even think about it
        bsr.s   bp_chkls        is this the list window?
        bne.s   setany          no - go stop table
        moveq   #sd.chenq,d0    get size of listing window
        assert  bv_lenln,bv_maxln-2
        move.w  #bv_lenln,a1    length of a line.w, no of lines.w, hit 2 more
        bsr.s   trap43
setany
        seq     bv_lsany(a6)    if all ok, we'll do line number table
        bne.s   lnskip
        move.w  d0,bv_totln(a6) set no of lines to zero
        move.w  a2,d0           for lsbef and lsaft, lsbas set zero for a mo
        bsr.s   initls
lnskip
        pea     nxtline
        jmp     bv_chri(pc)     make certain we have some ri space for ftod

* End of line code. bv_bfp points at lf, a0 points at lf + 1
preol
        addq.l  #2,a4           space over nl token to pre-word of next line
        tst.b   bv_brk(a6)      check for a break input (don't reset it here!)
end_ok1
        bpl.l   end_ok0         yes, don't do next line
        tst.b   bv_print(a6)    am I to print this ?
        beq.s   end_ok1         no - leave it in the buffer
        sub.l   bv_bfbas(a6),a0 line length including lf
        tst.b   bv_lsany(a6)    check if we have an active line number table
        beq.s   bufprt          no, so now just print it
        moveq   #4,d1
        jsr     bv_chlnx(pc)    ensure space for one line number table entry
        assert  bv_lnbas,bv_lnp-4
        movem.l bv_lnbas(a6),a1-a2 base and running pointer of lno table
        assert  bv_lsaft,bv_lenln-2,bv_maxln-4,bv_totln-6
        movem.w bv_lsaft(a6),d0-d3
        moveq   #-1-1,d4        forget the lf and we will round up
        add.l   a0,d4
        divu    d1,d4
        addq.w  #1,d4           no of lines this will occupy
        cmp.w   d4,d2           is this line bigger than whole screen?
        bge.s   notover         no, so we're not into finicky bits
        move.w  d2,d4           pretend it's just whole screen
notover
        add.w   d4,d3           add to running total
        bra.s   check           now we are guaranteed to leave it in table

trap43
        trap    #4
trap3
        moveq   #-1,d3
        trap    #3
        tst.l   d0
        rts

roll_tab
        sub.w   2(a6,a1.l),d3   take off lines encompassed in top ln
        move.w  0(a6,a1.l),bv_lsbef(a6) update invisible top line
        addq.l  #4,a1           roll the table forward
check
        cmp.w   d2,d3           will we scroll out of window
        ble.s   putlntab        no, just wind it in
        tst.w   bv_lsfil(a6)    are we supposed to just fill window?
        beq.s   roll_tab        no, so keep going
        cmp.w   bv_lsfil(a6),d0 have we done the "fill to" line yet?
        bls.s   roll_tab        no, so also keep going
* We've done the fill to line, we can't fit this, but we must have space left,
* or we wouldn't have come back to do this line at all. (See below)
        sub.w   d2,d3           overflow in window
        sub.w   d3,d4           reduce the space we recorded for this line
        move.w  d2,d3           show screen as filled to the brim
        mulu    d4,d1           do a partial display of extra line at bottom
        move.l  d1,a0           override length
putlntab
        move.w  d3,bv_totln(a6) update the no of lines in the window
        move.l  a1,bv_lnbas(a6) save base of lno table
        movem.w d0/d4,0(a6,a2.l) put in the lno/lines to be printed (lsaft)
        addq.l  #4,bv_lnp(a6)   update the running lno table pointer
bufprt
        move.w  a0,d2           length including lf (or trimmed final line)
        move.l  bv_bfbas(a6),a1
        moveq   #io.sstrg,d0    send a string of bytes
        move.l  (sp),a0         write it to here
        bsr.s   trap43
        bne.s   end_err
        moveq   #sd.clrrt,d0    clear to end of line
        trap    #3
nxtline
        move.w  #32768,d4       dummy next line number
        cmp.l   bv_pfp(a6),a4   reached end of program file yet?
        bge.s   nextset         yes - use dummy lno
        addq.l  #2,a4           skip pre-word
        move.w  2(a6,a4.l),d4   get the proper line number
nextset
        tst.b   bv_lsany(a6)    check if we have an active line number table
        beq.s   skipaft
        jsr     bv_clrt(pc)     shift the lno tab down to butt into rtstk
        ; d0=0, d1-d3/a0-a2 destroyed
        move.w  bv_lsaft(a6),bv_lsbas(a6) promote invisible line after to base
        move.w  d4,bv_lsaft(a6) store invisible line number after screen
skipaft
        move.w  d4,d1
        move.l  pa_table(pc),d4 get keyword table address

* We want to decide what to do with this line.
* If listing, we go operate range checks.
* If tokenising, we've either found the required line, or need to put a dummy.
* When on earth can we get here with print=0 and auto=0?
        tst.b   bv_print(a6)    listing?
        bne.s   tst_rnge        yes, go check range
        tst.b   bv_auto(a6)     detokenising for an auto/edit line?
        beq.s   tst_rnge        no, go check range (happens for TK2?)
        cmp.w   bv_edlin(a6),d1 and is it the one they asked for?
        beq.s   tst_rnge        yes, go continue (irrelevent) check on range
        move.w  bv_edlin(a6),d1 we are tokenising an absent auto/edit lno
        bsr.s   prlno           put line number in buffer
        move.l  a0,bv_bfp(a6)   include the space
end_ok0
        moveq   #0,d0
end_err
        move.l  (sp)+,a0        restore channel id
        rts

* Now... we want to do one of two things:
* If lsfil is set, we absolutely must do that one, but we can then fill the
* screen to our heart's content.
* If lsfil is not set, we want to stop as soon as d6 has been done.
tst_rnge
        cmp.w   d6,d1           is it ok to print?
        bls.s   chk_top         yes, go do it
        tst.b   bv_lsany(a6)    listing to list channel?
        beq.s   end_ok0         no, finished printing
        move.w  bv_lsfil(a6),d0 are we filling the window?
        beq.s   end_ok0         nope, so stop
        cmp.w   d0,d1           have we done the required line yet?
        bls.s   chk_top         not, keep on printing
        move.w  bv_maxln(a6),d0
        cmp.w   bv_totln(a6),d0 do we have any space left on the screen?
        ble.s   end_ok0         no, stop now
chk_top
        tst.w   d1              are we at the end of the program
        ble.s   end_ok0         yes, so this must be the end!
        bsr.s   prlno
        pea     preol           return at w.eol up to print line

* Convert program file line to text in basic buffer
* d0 -  o- 10
* d1 -  o- w.lno
* d3 -  o- 16 
* d4 -ip - keyword table address
* a0 -i o- base of basic buffer / after newline (bv_bfp left with a0-1)
* a1 -  o- pa_tbsym
* a4 -i o- lno token at start of line / newline token at end of line
* d2 destroyed
makeline
        moveq   #16,d3          enough for known tokens + msb clear
        bsr.s   chbf
        jsr     ib_nxtk(pc)     1st byte in d0.l, full word in d1.l (msbs=0)
        pea     makeline
        sub.b   d3,d0           this should sort valid tokens and fp ...
        bvs.s   istok           tokens $80-$8f will go to $70-$7f with v set
        rol.w   #8,d3           make it $1000
        add.w   d1,d3           this should get the exponent ok
        bcc.s   pr_prbad        it wasn't $fxxx, so it isn't really fp!
        move.l  bv_rip(a6),a1
        subq.l  #6,a1
        move.w  d3,0(a6,a1.l)   put corrected exponent
        move.l  2(a6,a4.l),2(a6,a1.l) and mantissa onto arithmetic stack
        jmp     cn_ftod(pc)     do the conversion

istok
        move.b  pr_tab-$70(pc,d0.w),d0 get offset of relevent print routine
        jmp     pr_jmp(pc,d0.w) jump to it (a line feed drops return addr)

prlno
        move.l  bv_bfbas(a6),a0 reset buffer
        bsr.s   itodd1          do conversion
        bra.s   prtsp           tack on a space
pr_tab
pr_tab macro
        assert 16,[.nparms]
i setnum 0
l maclab
i setnum [i]+1
 ifstr [.parm([i])] = bad goto n
        assert  $80+[i]-1,b.[.parm([i])]&$FF
n maclab
        dc.b    (pr_pr[.parm([i])]-pr_jmp)&$FFFF
 ifnum [i] < 16 goto l
 endm
 pr_tab spc key bip bif sym ops mon syv nam shi lgi str txt lno sep bad
        ds.w    0

chbf
        move.l  a0,bv_bfp(a6) set buffer ptr
        add.l   d3,a0
        cmp.l   bv_bfp+4(a6),a0
        sub.l   d3,a0
        blt.s   rts6            allow one extra
        move.l  d3,d1
        addq.l  #1,d1           just to cope with quoted string
        sub.l   bv_pfbas(a6),a4 relative pos of program file pointer
        jsr     bv_chbfx(pc)
        add.l   bv_pfbas(a6),a4 restore
rts6
        rts

pr_jmp ; jump table vectors come here

pr_prshi
        ext.w   d1
itodd1
        move.w  d1,d0
itodd0
        jmp     cn_0tod(pc)

pr_prlgi
        move.w  2(a6,a4.l),d0
        bra.s   itodd0

pr_prnam
        move.w  2(a6,a4.l),d0   get name number
        lsl.l   #3,d0           get byte offset
        move.l  bv_ntbas(a6),a1 base of name table
        add.l   d0,a1           pointer to name
        move.w  2(a6,a1.l),d2   get name list offset
        bpl.s   prnam           must have positive offset
pr_prlno ; shouldn't get these anywhere but at start of line!
pr_prbip
pr_prbif
pr_prsyv
pr_prbad
        moveq   #4,d3
        moveq   #'?',d2
        bra.s   prmult

pr_prkey
        move.l  d4,a1           get the pointer to the keyword table           
        move.b  d1,d3           get which keyword
        move.b  0(a1,d3.w),d3   get offset from start of keywords
        add.w   d3,a1           start of key
        move.b  (a1)+,d3        read pre-byte
        lsr.b   #4,d3           get length
        bsr.s   prabs           print the keyword
        cmp.w   #w.eol,2(a6,a4.l) is this keyword at the eond of the line
        beq.s   rts8            yes, so leave it at that
prtsp
        moveq   #' ',d2
prchr
        move.b  d2,0(a6,a0.l)
        addq.l  #1,a0
rts8
        rts

pr_prspc
        move.b  d1,d3
        bsr.s   chbf            gotta check it'll fit
        moveq   #' ',d2         set space
prmult
        bsr.s   prchr           do the print
        subq.b  #1,d3           finished yet?
        bne.s   prmult          ..no
        rts

pr_prsym
        move.b  d1,d0           which symbol
        lea     pa_tbsym(pc),a1
        move.b  -1(a1,d0.w),d2
* Sneaky trick based on the fact that the value of a line feed is = to its num
        cmp.b   d1,d2
        bne.s   prchr           if not a line feed, just add it to buffer
        addq.l  #4,sp           scrap normal return
        bra.s   prchr           go tack on the newline then return

pr_prstr
        bsr.s   quote           print opening string quote
        bsr.s   pr_prtxt        print the string
quote
        move.b  1(a6,a4.l),d2   string delimiter single/double quotes
        bra.s   prchr

pr_prmon
        lea     pa_tbmon(pc),a1
prky1
        move.b  d1,d3           get which thing
        move.b  0(a1,d3.w),d3   get offset from start of things
        add.w   d3,a1           start of thing
        moveq   #15,d3
        and.b   (a1)+,d3        read pre-byte
prabs
        move.b  (a1)+,0(a6,a0.l)
        addq.l  #1,a0
        subq.w  #1,d3
        bgt.s   prabs
        rts

prnam
        move.l  bv_nlbas(a6),a1 base of name list
        lea     -3(a1,d2.w),a1  start of name, as if it were a text token
        move.b  3(a6,a1.l),d3   name length
        sub.l   a4,a1           relative pos of text/name pointer
rel_chk
        beq.s   rts9            ignore zero length
        bsr.l   chbf
        add.l   a4,a1           restore
prrel
        move.b  4(a6,a1.l),0(a6,a0.l)
        addq.l  #1,a1
        addq.l  #1,a0
        subq.w  #1,d3
        bgt.s   prrel
rts9
        rts

pr_prtxt
        sub.l   a1,a1           set where text token starts
        move.w  2(a6,a4.l),d3   get length of text
        bra.s   rel_chk         print text

pr_prsep
        lea     pa_tbsep(pc),a1
        bra.s   prky1

pr_props
        lea     pa_tbops(pc),a1
        bra.s   prky1

        end
