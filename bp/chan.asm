* Get channel id if possible
        xdef    bp_chan,bp_chand,bp_chnid,bp_chnew

        xref    ca_gtin1
        xref    bv_chchx

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_choff'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_vect4000'

c.defex equ     1               default channel to use if none specd
* Should really be taken from the bv area depending on what we're doing

        section bp_chan

* Start up a new superbasic channel number.

* d0 -  o- 0 if ok or err.ex if channel already open
* d1 -ip - channel number , 0 - n, n undecided and may exceed max so far
* a0 -ip - new channel id
* a2 -  o- sb channel location
* All other registers preserved

* If the channel was already open, nothing will have been changed
* If the channel table is extended, it is done with all $ff's
* If a good slot is found, the new id will be stored and the rest zero, except
* for filling in 80 as the line width.

extend
        movem.l d1-d2,-(sp)     save channo/?
        moveq   #ch.lench,d1    we need a whole extra slot
        add.l   a2,d1
        sub.l   bv_chp(a6),d1   extra amount needed
        move.l  d1,-(sp)        save it
        jsr     bv_chchx(pc)    make sure there's enough room
        movem.l (sp)+,d0-d2     get back extra/channo/?
fill
        move.l  bv_chp(a6),a2   pick up current pointer
        st      0(a6,a2.l)      wipe all new space to -1 (closed)
        addq.l  #1,bv_chp(a6)   update by extra
        subq.l  #1,d0
        bne.s   fill

bp_chnew
        move.l  a0,-(sp)        save new id
        bsr.s   bp_chnid        where does channel id go?
        move.l  (sp)+,a0        reload new id
        beq.s   err_ex          ouch, channel is already open
        subx.b  d0,d0           is slot there?
        bpl.s   extend          no, so go make more room
        move.l  a0,ch.id(a6,a2.l) insert the new channel id
        moveq   #ch.lench-4,d0  less one long word per channel to be cleared
        add.l   d0,a2
clr_block
        clr.l   0(a6,a2.l)
        subq.l  #4,a2
        subq.l  #4,d0
        bne.s   clr_block
        move.w  #80,ch.width(a6,a2.l) 80 character line
ok_rts
        moveq   #0,d0           and no errors
rts0
        rts

err_ex
        moveq   #err.ex,d0      channel exists
        rts

* Determines whether or not next parameter is a channel number and, if so,
* returns the channel id, else returns default

* d0 - lo- error return
* d1 -i o- channel number (set to c.defex if entry at bp_chan)
* a0 -  o- channel id if one exists
* a2 -  o- position of channel block if channel exists
* a3 -i o- next parameter (o=i if no chan given, o=i+8 else)
* a5 -ilo- top parameter(i,o) parameter to convert(l)
* All other registers preserved

regsav  reg     d2-d3/a5

bp_chan
        moveq   #c.defex,d1     standard default for most things
bp_chand
        cmp.l   a3,a5
        ble.s   bp_chnid
        tst.b   1(a6,a3.l)      check hash flag
        bpl.s   bp_chnid        not set, so this isn't a channel

        movem.l regsav,-(sp)
        lea     8(a3),a5
        jsr     ca_gtin1(pc)    get a single integer
        move.l  a5,a3
        movem.l (sp)+,regsav
        bne.s   rts0
        addq.l  #2,bv_rip(a6)
        moveq   #err.bp,d0      don't like negative channels! (lwr added)
        tst.w   d1
        bmi.s   rts0

* Look up a channel number, return location and, if open, the ID

* d1 -ip - channel number required
* d0 -  o- 0 or err.no
* a0 -i o- if d0=0, the channel id, otherwise input value preserved
* a2 -  o- sb channel location (if d0=err.no and x=0, this is above table)
* x  -  o- if d0=err.no, 0: need more space or 1: closed slot found
* All other registers preserved

bp_chnid
        moveq   #ch.lench,d0    chan length
        mulu    d1,d0
        add.l   bv_chbas(a6),d0 add base of channels
        move.l  d0,a2           save the position
        sub.l   bv_chp(a6),d0   does it exist?
        bcc.s   err_no          note: x=1 iff slot is available
        move.l  ch.id(a6,a2.l),d0 actual id wants to be sent back
        bmi.s   err_no          negative id means it's closed
        move.l  d0,a0           and the id
        bra.s   ok_rts

err_no
        moveq   #err.no,d0
        rts

        vect4000 bp_chan,bp_chand,bp_chnew,bp_chnid

        end
