* Print or input something, including arrays. Also the buffer read routine.
        xdef    bp_input,bp_print,bp_rdbuf

        xref    bp_arend,bp_arind,bp_arnxt,bp_arset,bp_chan,bp_let,bp_rdchk
        xref    bv_chbfx,bv_chri
        xref    ca_gtin1,ca_putss
        xref    cn_dtoi,cn_dtof,cn_ftod,cn_0tod
        xref    mm_mrtor

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_choff'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_token'

* By default, I/O is to channel #1, but #<channel number> is accepted at any
* time, allowing output to several channels.

* Separators have the following effect:

* Comma         Tab to next 8 char position. If this is < 8 from end of edge
*                       of window or over edge of window, then do a line feed.
* Semicolon     Take no action.
* Backslash     Move to a new line.
* Exclamation   Ignored if at the start of a line. Otherwise, if there is room
*               on the line for a space and the next arg, print a space,
*               otherwise throw a line.
* TO <posn>     Space to the given position provided it's between here & end.
*                       (Any separator after <posn> will do, and is ignored.)

* A separator (except to) after an array will be appended to each element of
* the array. No separator after an array is taken to be new line.

* A substring is taken to be a small string rather than a set of characters
* E.g. 'print alphabet(2 TO 4),' gives bcd      not b       c       d

* Register usage:
* d0-d3 general
* d4.msw length left on line when actioning !, undefined otherwise
* d4.bits15..1 various irrelevent values
* d4.bit0 set if prior separator was !, and not at the start of a line
* d5.lsb separator type (0..5) * 16
* d5.bit15: clear for to<null> or final arg is followed by to (input/edit)
* d5.msw: -1
* d6 -ve or vv offset to index counter block (bp_arxxx routines)
* d7.bits31..16 destroyed, but could easily be saved/used
* d7.bits16..8 zero, not used at present
* d7.bit7 clear for input, set for print
* d7.bit6..1 must be kept 0
* d7.bit0 set if chenq fails, i.e. not a scr/con
* a0 channel id
* a1 general
* a2 ch channel descriptor
* a3 nt argument
* a4 vv array descriptor, etc
* a5 nt top, not used a great deal
* (sp) remaining argument count

        section bp_print

bp_print
        tas     d7              set flag to say print in progress
bp_input
        jsr     bv_chri(pc)     make space on ri stack, in case of int/fp
        bra.s   restart

steparg
        addq.l  #8,a3
        move.l  (sp)+,a5
        add.l   a3,a5
        tst.l   d0              any errors?
        bne.s   rts0            yes - get out now
        cmp.l   a3,a5           end of args yet?
        bgt.s   getarg          no - pick up next one
rts0
        rts

sendnwl
        bsr.s   nwlinle         no args between channels, insert a newline
restart
        jsr     bp_chan(pc)     get channel
        bne.s   rts0
        moveq   #-128,d4        no pending ! seps (bit0 = 0)
        and.b   d4,d7
        blt.s   chkemp          if print, wade in
        bsr.l   chenq           check for readonly
chkemp
        cmp.l   a3,a5
nwlinle
        ble.l   nwlin           no args after channel, finish with newline
        tst.b   1(a6,a3.l)
        bmi.s   sendnwl         imediately following #<chan>, so newline here
getarg
        moveq   #-16,d5         no to<null> if bits 15..8 are set
        and.b   1(a6,a3.l),d5   get hash and seps
        bmi.s   restart         allow embedded channel selection!
        sub.l   a3,a5
        subq.l  #8,a5
        move.l  a5,-(sp)        save remaining arg count * 8, after this one
        sub.l   bv_chbas(a6),a2 ch is above vv, so we must be careful
        jsr     bp_arset(pc)    set up in case we need an array
        add.l   bv_chbas(a6),a2 put ch pointer back straight
        clr.w   d2              make null arg look like a zero length string
        move.w  #$ff0f,d3       set up mask for null arguments
        and.w   d3,0(a6,a3.l)   lose seps
        beq.s   picked1         null argument
        move.b  d7,d1           check if print ...
        or.b    2(a6,a3.l),d1   ... or an expression
        blt.s   pr_elt          if so, no funny to<null> allowed
        cmp.b   #b.septo<<4,d5  is it to?
        bne.s   pr_elt          no, forget this bit
        and.w   8(a6,a3.l),d3   is it followed by a null argument?
        bne.s   tonullw         no, but have a look for no arguments left 
        move.w  8(a6,a3.l),d5   leapfrog to next seps/type (syntax->hash=0)
tonullw
        tst.l   (sp)            was there another argument at all?
        bne.s   pr_elt          yes, so this is all OK
        clr.w   d5              show as to<null> and no separator
pr_elt
        jsr     bp_arind(pc)    if need be, index any array element
        clr.w   d2              set length to zero as a starter
        move.b  d7,d1
        bgt.l   input           input from non-edit cannot edit
        or.b    2(a6,a3.l),d1   check for print or expression
        bmi.s   pickup          either needs value to be picked up
        tst.w   d5
        bmi.s   picked          skip unless we had to<null> on editable input
pickup
        move.l  4(a6,a3.l),d1
        bpl.s   valok           if value defined, all is OK
        tst.b   d7
        beq.s   picked          if input to undefined, start with null string
        move.l  bv_bfbas(a6),a1
        move.b  #'*',0(a6,a1.l) if print, make undefined be "*"
        addq.w  #1,d2
picked1
        bra.s   picked

valok
        move.l  bv_vvbas(a6),a1
        cmp.b   #t.arr,0(a6,a3.l) only 1 dim (sub-)string arrays are left
        bne.s   picksimp
        add.l   a1,d1
        movem.l 0(a6,d1.l),d1-d2 get vv offset and possible substring length
picksimp
        add.l   d1,a1
        bsr.s   chktype
        bcs.s   intfp
        bpl.s   picked          =0, substring, length is ready
        move.w  0(a6,a1.l),d2   =1, string, get length
        addq.l  #2,a1           step past length
        bra.s   picked          do it

intfp
        movem.w 0(a6,a1.l),d0-d2 get integer or fp
        move.l  bv_bfbas(a6),a0 where to put string
        bmi.s   itod
        move.l  bv_rip(a6),a1   use ri stack for int, fp
        subq.l  #6,a1           will be reset next time so extra no matter
        movem.w d0-d2,0(a6,a1.l) put on ri stack
        jsr     cn_ftod(pc)     =2, fp, convert float to string
        bra.s   numlen          and write out a number

itod
        jsr     cn_0tod(pc)     =3, integer, convert integer to string
numlen
        move.l  ch.id(a6,a2.l),a0 reload channel id
        move.l  bv_bfbas(a6),a1 start of ascii number
        move.w  d1,d2           length of ascii number
picked
        lsr.b   #1,d4           can I print arg straight away?
        bcc.s   addlen          yes, so do it
        move.l  a1,d3
        bsr.l   excl_do         action a pending ! operation
        move.l  d3,a1
addlen
        tst.w   0(a6,a3.l)
        beq.s   end_arh         null argument requires nothing more
        tst.b   d7
        blt.s   print           if print - go print it
        tst.b   2(a6,a3.l)
        bpl.s   input           non-expression is to be input
        tst.b   d7
        bgt.s   end_arh         ignore expressions on non-edit input
print
        add.w   d2,ch.chpos(a6,a2.l) update the running cursor
        bsr.l   sstrg
end_arh
        bra.l   end_arg

chktype
        move.b  1(a6,a3.l),d3
        rol.b   #7,d3
        rts

input
        jsr     bp_rdchk(pc)
        bne.s   end_arh         can't read into this, so get out
        sub.l   bv_chbas(a6),a2 keep ch entry as offset for now
        move.w  d2,a4           save length and extend it to long
        move.l  a4,d1           space required in buffer
        bsr.s   chktype         have we just done a number
        bcs.s   inpnow          yes - initial text is already in basic buffer
        sub.l   a3,a1           offset
        sub.l   bv_ntbas(a6),a3 offset
        jsr     bv_chbfx(pc)    ensure buffer has space for current string
        add.l   bv_ntbas(a6),a3 proper
        add.l   a3,a1           proper
        move.l  a4,d1           put back length
        move.l  a0,a4           save channel id
        move.l  bv_bfbas(a6),a0 trundle it off to the basic bf area
        jsr     mm_mrtor(pc)    using fast copy (purely 'cos of code saving)
        move.l  a4,a0           restore channel id
inpnow
        move.w  d1,d3           initial cursor at end of string
        add.l   bv_bfbas(a6),d1
        move.l  d1,bv_bfp(a6)   set buffer top
        move.b  d7,d0           whether user can edit this input
        sub.l   bv_ntbas(a6),a3 keep arg offset
        bsr.l   bp_rdbuf        read a line
        add.l   bv_ntbas(a6),a3 reset arg
        bne.s   rderrd0
        subq.l  #1,a1           discard the terminator
        assert  -1,err.nc
        moveq   #-1,d3
        cmp.b   #27,0(a6,a1.l)  was it terminated by an esc?
        beq.s   rderrd3         yes - give back a "not complete" error
        move.w  d7,-(sp)
        move.l  a1,d7           save end of buffer
        moveq   #sd.pcol,d0     remove the line feed from the screen
        trap    #3
        moveq   #sd.ncol,d0
        trap    #3
        move.l  bv_bfbas(a6),a4 source in a4
        bsr.s   chktype
        bcc.s   putss
        exg     a0,a4           save channel and get source in a0
        move.l  bv_rip(a6),a1   get ri pointer
        bmi.s   dtoi
        jsr     cn_dtof(pc)
        bra.s   chkri

putss
        sub.w   a4,d7           data length read
        move.w  d7,d1
        jsr     ca_putss(pc)
        bra.s   ritovv

dtoi
        jsr     cn_dtoi(pc)
chkri
        move.l  a4,a0           restore channel
        bne.s   restd7
        move.l  a1,bv_rip(a6)
ritovv
        jsr     bp_let(pc)
restd7
        move.w  (sp)+,d7        reload d7
rderrd0
        move.l  d0,d3
        beq.s   resta2
        moveq   #sd.curs,d0     suppress the cursor
        bsr.s   trap3
rderrd3
        move.l  d3,d0
resta2
        add.l   bv_chbas(a6),a2 reset a2
end_arg
        bsr.s   sepmost         if no error, action null and !,\ separators
        bne.s   droparr         if any error, go clean up any array
        jsr     bp_arnxt(pc)    scan any array elements
        bgt.l   pr_elt          there were some left, so loop
droparr
        jsr     bp_arend(pc)    discard any array index block
        bne.s   notto           some error about
        tst.w   d5              look at our to<null> flag
        bmi.s   notonul         if we haven't been using to<null>, no prob
        addq.l  #8,a3
        subq.l  #8,(sp)         get rid of the <null> (possible overrun is OK)
notonul
        cmp.b   #b.septo<<4,d5  are we on for a to?
        bne.s   notto           no - skip this
        subq.l  #8,(sp)         using up another argument
        bsr.s   septo           action the to
notto
        bra.l   steparg         go back up to the top

oddsep
        subq.b  #b.back>>1,d0
        bne.s   okrts5
nwlin
        tst.b   d7              is this input only?
        bgt.s   okrts5
        moveq   #10,d1
        clr.w   ch.chpos(a6,a2.l)
print_1
        moveq   #io.sbyte,d0
trap3
        move.l  d3,-(sp)        save d3
        moveq   #-1,d3          infinite timeout
        trap    #3
        move.l  (sp)+,d3        restore d3
        bra.s   tstrts

excl_do
        swap    d4              arg preceded by an !
        cmp.w   d2,d4           how much room is there left on the line?
nwlinlt
        ble.s   nwlin           not enough, so do a new line
prints
        tst.b   d7
        bgt.s   okrts5          if input from read only, write nothing
        moveq   #' ',d1
        addq.w  #1,ch.chpos(a6,a2.l) one more character
        bra.s   print_1

sepmost
        move.l  d0,d4           has an error occurred? (also set d4.bit0=0)
        bne.s   rts5            yes - get out straight away
        moveq   #err.nc,d0
        tst.b   bv_brk(a6)      has a "break" keypress happened?
        bpl.s   tstrts          yes - stop here
        move.b  d5,d0
        beq.s   nwlin           treat no separator same as backslash
        assert  1,b.sepcom,b.back&1,(b.excl-1)&1
        lsr.b   #5,d0
        beq.s   comma
        bcs.s   oddsep
        subq.b  #b.excl>>1,d0
        bne.s   okrts5          get out if not exclamation mark
        bsr.s   where           do nothing now but get space left
        sub.w   d1,d3
        move.w  d3,d4
        swap    d4              save space left in msw
        tst.w   d1              check for beginning of a line
        sne     d4              if not at start of line, flag pending !
okrts5
        moveq   #0,d0
rts5
        rts

comma
        bsr.s   where           where am i
        moveq   #-8,d2
        and.w   d1,d2           round down to multiple of eight
        addq.w  #8,d2           move on eight to where we want to finish
        subq.w  #8,d3           remainder must be >=8 as well
        bra.s   tab_to

sstrg
        moveq   #io.sstrg,d0    write out a string
trap43
        trap    #4
        bra.s   trap3

septo
        addq.l  #8,a3           step past current arg
        move.l  a3,a5           set upper limit
        blt.s   gtin1           force error if there were no arguments left!
*       tst.b   1(a6,a3.l)
*       bmi.s   gtin1           force error if to #<arg> - may use this later
        addq.l  #8,a5           pretend there's only one arg
gtin1
        jsr     ca_gtin1(pc)
        bne.s   rts5
        move.w  d1,d2           where they want to go to
        addq.l  #2,bv_rip(a6)
        bsr.s   where           where we are now
tab_to
        cmp.w   d2,d3           what's left on line?
        blt.s   nwlinlt         not enough, so get out
        sub.w   d1,d2           print at least one, up to this many spaces
re_spac
        bsr.s   prints
        subq.w  #1,d2
        bgt.s   re_spac
tstrts
        tst.l   d0
        rts

* Note: we only ever do this the once (per channel)
flagro
        addq.b  #1,d7           input $00->$01, print $80->$81
where
        assert  ch.chpos,ch.width-2
        movem.w ch.chpos(a6,a2.l),d1/d3
        rol.b   #8,d7           have we set bit 0 yet?
        bcs.s   okrts5          yes - then we know it's a read only channel
chenq
        moveq   #sd.chenq,d0
        move.l  bv_bfbas(a6),a1
        bsr.s   trap43          if it's read only, we'll get an error
        bne.s   flagro          so go flag it
        move.w  4(a6,a1.l),d1   position of cursor
        move.w  0(a6,a1.l),d3   length of line
        rts

* Fetches string to or edits string in basic buffer. Routine that is used by
* basic to input command or program lines from the keyboard or other devices.

* d0 -i o- zero if input may be editted, output error code
* d3 -i o- lsw cursor position (msw preserved)
* a0 -ip - where to read from
* a1 -  o- where buffer has been filled to
* d1-d2 destroyed

bp_rdbuf
        move.l  d0,-(sp)        save edit or not
        bne.s   goedit          can't edit, so leave out write
        bsr.s   params          get parameters for the operation
        move.w  d3,d2           use cursor position for initial display
sendit
        bsr.s   sstrg
goedit
        bsr.s   params          get parameters (again)
        add.w   d1,a1           set up current position
        moveq   #io.edlin,d0    set to edit a line
        tst.l   (sp)            allow edit?
        beq.s   trp_set
        moveq   #io.fline,d0    no, fetch a line
        sub.w   d1,d2           or rather, a continuation of same!!
trp_set
        bsr.s   trap43
        moveq   #err.bo,d2
        cmp.l   d0,d2
        beq.s   edmore          extend buffer if it overflows
        tst.l   (sp)+           check and discard saved edit flag
        bne.s   positit         we weren't editing, so no device check
        moveq   #err.bp,d2
        sub.l   d0,d2
        beq.s   edbpro
        subq.l  #err.bp-err.ro,d2 a pity, but drivers may say bp or ro
        beq.s   edbpro
positit
        move.l  a1,bv_bfp(a6)   save where we've got to
        bra.s   tstrts

edmore
        bsr.s   positit         record where we got to
        swap    d1              cursor into lsw
        move.w  d1,d3           save current cursor position
        moveq   #128-8,d1       want more bytes (will round up as 192 extra)
        jsr     bv_chbfx(pc)    ask for it
        bra.s   goedit

edbpro
* We only get here from reading a command channel line.
* If we were editing a "bad line", the cursor position may have been non-zero.
* If so, we've already sent the chars up to the cursor.
* To make that tidy, we need to send the rest, plus a linefeed.
* As it happens, the linefeed from the parser is still in the buffer!
* If the buffer is empty, we're OK already.
        move.l  d0,-(sp)        if edlin gives err.bp/ro, try without edit
        bsr.s   params
        move.w  d1,d2
        beq.s   goedit          nothing in buffer, so nothing pre-sent
        move.l  a1,bv_bfp(a6)   lose contents of buffer now
        add.w   d3,a1           move past what we've sent
        sub.w   d3,d2           count that off
        addq.w  #1,d2           include the linefeed
        clr.w   d3              forget the cursor now
        bra.s   sendit          go start business
        
params
        assert  bv_bfbas,bv_bfp-4
        movem.l bv_bfbas(a6),d0-d2 buffer base, top and next pointer
        move.w  #$7eff,a1       an arbitrary maximum
        exg     a1,d0
        sub.l   a1,d1           length of buffer so far
        sub.l   a1,d2           maximum length of buffer
        cmp.l   d2,d0           is the current buffer size reasonable?
        bcc.s   max_ok
        move.l  d0,d2           no - truncate it
max_ok
        cmp.l   d1,d2           is the current number of characters now OK?
        bcc.s   off_ok
        moveq   #0,d1           no - discard them - probably a duff file read
off_ok
        cmp.w   d3,d1           does the cursor make some sense?
        bcc.s   cur_ok
        clr.w   d3              no - discard it
cur_ok
        swap    d1
        move.w  d3,d1           put cursor in msw
        swap    d1
        rts

        end
