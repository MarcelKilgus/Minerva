* Add a new line to the program file, modify an existing one or delete one
        xdef    pf_nwlin

        xref    bv_chpfx
        xref    ib_glin0,ib_whdel
        xref    mm_mrtor

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_token'
        include 'dev7_m_inc_vect4000'

* Inserts or deletes a basic program line in program file and sets up basic
* variables for editing/auto edit of next appropriate line.

        section pf_nwlin

* Return is immediate for no line number (just a1 smashed)
* Return is +2 for line number ok

* d0 -  o- if lno present, +ve/0/-ve for line inserted/replaced/deleted
* d2 -  o- line number
* d5 -  o- iff 0.l, no change to program (delete non-exist or modify identical)
* d1/d6/a0-a2 destroyed
* Line replaced includes blank line with non-existing lno.

pf_nwlin
        move.l  bv_tkbas(a6),a1 start of new line
        cmp.b   #b.lno,0(a6,a1.l) is there a line number?
        beq.s   lnopres         yes, do edit, otherwise direct return
        rts

regon   reg     d1-d4/a4
regoff  reg     d0/d2-d4/a4

lnopres
        addq.l  #2,(sp)         set skip return, as we're editing
        move.w  2(a6,a1.l),d2   get the line number
        move.l  bv_tkp(a6),d3   end of new line
        sub.l   a1,d3           length of new line
        subq.w  #6,d3           does user want to wipe out this line?
        ble.s   lenzero         yes, leave length as zero (or force it)
        addq.w  #8,d3           otherwise, allow for pre-word
        bpl.s   lenok           backstop check on line length
lenzero
        moveq   #0,d3           force it into a deletion
lenok
* Doing this should protect against a lunatic bad file line that reads
* something like "1data 1,1,1,1....." with about 16000 ones, which will have
* been tokenised up to 2 or 4 times the line length!
* This is not perfect, but does offer a modicum of protection.
        moveq   #0,d1           preset for flag and msw zero
        movem.l regon,-(sp)     save some registers, flag at top of stack
        moveq   #0,d5           negated length of line being replaced/deleted
        move.l  d5,a2           adjustment for possible subsequent pre-word
        move.w  d2,d4           set line to search for
        jsr     ib_glin0(pc)    position to line (msw d1 was zero)
        move.l  d0,a3           save pfbas for later
        exg     d2,d4           hold pfp in d4 and set d2 back to lno
        exg     a1,a4           make a1 top of unaffected prog, put tkbas in a4
        add.l   d3,a4           move up to tkp plus two if insert
        ble.s   oldrdy          ready now if we're at the top of the file
        cmp.w   4(a6,a1.l),d2   check the line number we've found
        bne.s   oldrdy          if we have no match, we'll make it insert
        subq.l  #1,(sp)         adjust flag on top of stack to delete
        move.w  d2,d6           whdel given d2=d6, and destroys just d0/a0
        jsr     ib_whdel(pc)    tell when handler line is changing
        move.w  0(a6,a1.l),a2   get pre-word, may be adjust for next pre-word
        sub.l   d1,d5
        sub.l   a2,d5           negated disappearing line size
        sub.w   d5,a1           step on to next, source of rest of prog
oldrdy
        move.w  d1,d6           hold onto prior line size
        move.l  bv_pfp+4(a6),d0 get next area address
        sub.l   d4,d0           space available above pfp
        sub.l   a1,d4           size of program above affected line
        move.l  a1,a0           destination may be same as source!
        add.l   d3,d5           prog file size change
        beq.s   nomove          no size change needed, so no move at all!

* d3 length of line to be inserted, including a pre-word that isn't there!
* d4 size of program above affected line
* d5 -ve drop space, +ve add space
* d6 length of line before source area, including pre-word (2=none)
* a0/a1 point at pre-word of first line to be moved (or even = bv_pfp)
* a2 basic adjust for next pre-word (as if for a delete, so far)
* a3 pfbas
* a4 tkp, +2 if new line present

        add.l   d5,a0           actual destination
        cmp.l   d5,d0           what do we want?
        bgt.s   spcok           always try to keep one extra word (fast golin)
        move.l  a0,d1           copy new end of line address
        sub.l   a3,d1           space up to and including new line
        asr.l   #4,d1           6.25% of that
        addx.l  d5,d1           add in essential space, rounding up halves
* We always get d1>d5, as even the very first line must be at least ten bytes.
        jsr     bv_chpfx(pc)    get extra program file space
spcok

        move.l  d4,d1           program size above affected area
        beq.s   modpfp          ahah! nothing to move
* As we are going to move some program, there is obviously a pre-word there.
* We can now update it to its correct value.
* What it has is a "this-prior" value, and we have either changed its prior
* line length with a modify, or we have inserted a totally new line.
        move.w  d3,d0           do we have a new line? 
        beq.s   doadjust        if not, the adjustment is ready
        sub.w   d6,d0           not the overall prior, it's the new line
doadjust
        sub.w   a2,d0           incorporate the matched pre-word, if any
        sub.w   d0,0(a6,a1.l)   adjust the pre-word we're about to move
        jsr     mm_mrtor(pc)    get the heavy mob to move the program
modpfp
        add.l   d5,bv_pfp(a6)   adjust pfp to new value
        add.l   d5,a1           adjust old source to be where it went
        bra.s   qinsert         now go see if we have anything to insert

* no movement required (d5.l=0), so we consider if the prog has changed
nomove
        move.w  d3,d5           get new line size
        beq.s   endline         deletion of non-extant line, so no change
* as we are modifying an identical length line, we know a0=a1
        move.l  a4,a2
cmplp
        subq.l  #2,a0
        subq.l  #2,a2
        subq.w  #2,d5
        beq.s   dupline         all was unchanged, so get out
        move.w  -2(a6,a2.l),d1
        cmp.w   0(a6,a0.l),d1   compare word from token list to prog file
        beq.s   cmplp
        move.l  a1,a0           put back to top, copy some unchanged stuff
qinsert
        move.w  d3,d0           is there anything to put in?
        beq.s   endline         no, we're completely done
        sub.w   d6,d0           this will be the line's offset word
copylp
        subq.l  #2,a0           don't use mrtor, as this will be quicker
        subq.l  #2,a4
        move.w  -2(a6,a4.l),0(a6,a0.l) copy word from token list to prog file
        subq.w  #2,d3           start of line - 2 yet?
        bne.s   copylp          no, keep copying
* Actually just copied rubbish word into offset, but it saves hassle...
        move.w  d0,0(a6,a0.l)   correct offset
dupline
        addq.l  #1,(sp)         change flag to show modify or insert

* d4 size of program above affected line
* d5 flag, 0.l if no change to program (delete non-exist or modify identical)
* d6 length of line before a0
* a0 new line inserted/replaced or the one after a deleted line
* a1 program above affected area (same as a0 on a delete)
* a3 pfbas

endline
        tst.b   bv_arrow(a6)    what do they want to do now?
        beq.s   nwlend          no change
        bgt.s   down_arr        move to next line
        cmp.l   a0,a3           are we at the start?
        bge.s   dropoff         yes, get out
        move.l  a0,a1
        sub.w   d6,a1           point back to prior line
setedlin
        move.w  4(a6,a1.l),bv_edlin(a6)
setauto
        sne     bv_auto(a6)     automatically edit the next line
nwlend
        st      bv_edit(a6)     tell npass we've changed the program
        movem.l (sp)+,regoff    restore registers
        rts

down_arr
        tst.l   d4              was there something up there
        bne.s   setedlin        then we can edit it
dropoff
        clr.w   bv_edinc(a6)    make sure auto properly off
        bra.s   setauto

        vect4000 pf_nwlin

        end
