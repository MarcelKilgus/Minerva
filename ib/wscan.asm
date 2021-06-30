* Scan for when variable entries
        xdef    ib_ewret,ib_wscan,ib_wscnx,ib_wtest

        xref    bv_alvv,bv_frvv
        xref    ca_evalc
        xref    ib_golin,ib_gost,ib_nxnon,ib_stbas,ib_stnxi

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_wv'

wvshft  equ     4
        assert  1<<wvshft,wv.len

        section ib_wscan

* d0 -  o- 0 match found, -1 match not found (n/a if d3 0)
* d1 - l - number of wvtab entries left to look at
* d2 - l - no of active wv entries left to look at
* d3 -i  - +ve look for match on name row
*          -ve look for match on endwhen lno
*            0 look for an empty entry
* d4 -i  - name row, line number or irrelevent depending on d3
* a2 -  o- entry in wv table

empty
        tst.b   d3              did we want an empty slot?
        bne.s   nx_add          no
        rts

ewlno
        cmp.w   wv.ewlno(a6,a2.l),d4 does the endwhen lno match?
        bne.s   ib_wscnx        no, try again
        tst.w   wv.rtlno(a6,a2.l) yes, is it in use?
        blt.s   ib_wscnx        no, curses
match
        moveq   #0,d0
        rts

no_match
        moveq   #-1,d0
        rts

none_set
        tst.b   d3              no entries, do we care?
        bne.s   no_match        no
        tst.b   bv_wvbas(a6)    yes, are there any empty ones?
        bmi.s   expand          no, better make some then

get_base
        move.l  bv_vvbas(a6),a2 base of vv area
        add.l   bv_wvbas(a6),a2 add offset to get base of wv table
get_count
        moveq   #-wv.len-4,d1   take off size and length of 1st entry
        add.l   0(a6,a2.l),d1   size of table (not to be confused with
                ;               the number of active when variable entries)
        lsr.l   #wvshft,d1      d1 is now suitable for a "dbra"
        addq.l  #4,a2           position a2 at 1st entry
        rts

ib_wscan
        move.w  bv_wvnum(a6),d2 number of wv entries
        beq.s   none_set        none
        bsr.s   get_base        get base of table
nx_chk
        move.w  wv.row(a6,a2.l),d0 get next name row
        bmi.s   empty           it's empty
        tst.b   d3              what are we looking for
        blt.s   ewlno           an endwhen line number
        beq.s   nx_add          an empty slot
        cmp.w   d0,d4           a name row, is it this one?
        beq.s   match           yes, good
ib_wscnx
        subq.w  #1,d2           decrement active wv entries left
        beq.s   no_match        none left
nx_add
        add.w   #wv.len,a2      move to next entry
        dbra    d1,nx_chk       (if there is one, that is)

expand
        moveq   #-1,d1          assume current table length is zero
        tst.b   bv_wvbas(a6)    is there a table here?
        bmi.s   get_new         no, we'll make a new one
        bsr.s   get_base        find how many entries already exist
get_new
        moveq   #20+1,d0        extend by 20 entries
        add.l   d0,d1
        lsl.l   #wvshft,d1
        addq.l  #4,d1           don't forget the length word
        jsr     bv_alvv(pc)     get space for new table
        move.l  d1,0(a6,a0.l)   store size of new table
        move.l  a0,-(sp)        save new table address
        move.l  a0,a2
        bsr.s   get_count       work out how many entries the new table has

        tst.b   bv_wvbas(a6)
        bmi.s   nocopy          this is the first allocation, so no copy
        subq.w  #1,d1           dbra for initialising new entries is ...
        move.w  d1,-(sp)        ... (new table dbra - old table dbra - 1)
        bsr.s   get_base        get the old table stuff
        sub.w   d1,(sp)
copynxt
        moveq   #wv.len/4-1,d0
copy4
        move.l  0(a6,a2.l),4(a6,a0.l) copy the next long word
copent
        addq.l  #4,a2
        addq.l  #4,a0
        dbra    d0,copy4
        dbra    d1,copynxt

        move.w  (sp)+,d1        recover counter for clearing entries
        lea     4(a0),a2        first entry to clear
nocopy

        moveq   #wv.len,d0
        move.l  a2,-(sp)        save first of new, free entries
clear
        st      wv.row(a6,a2.l) empty entries are negative
        add.w   #wv.len,a2
        dbra    d1,clear

        move.l  bv_wvbas(a6),d1 get offset of old table
        blt.s   nofrvv          wasn't one
        move.l  bv_vvbas(a6),a0
        add.l   d1,a0           start of old table
        move.l  0(a6,a0.l),d1   length of old table
        jsr     bv_frvv(pc)     free it
nofrvv

        move.l  (sp)+,a2        first unset entry
        move.l  (sp)+,d1
        sub.l   bv_vvbas(a6),d1 new offset
        move.l  d1,bv_wvbas(a6) store it
        rts

* Tests if an assignment just made to the variable indicated by its
* name row (token value in program file) satisfies some of the current
* when variable conditions, and,if so, resets the parser to take 
* appropriate action.

* d0     o error return
* d4 i s   name row of variable just assigned to
* a4 i   o parser pointer to program file
* Note: apart from a4, any register may be smashed

ib_wtest
        moveq   #1,d3           look for it
        bsr     ib_wscan
        bra.s   chk_cond

nx_load
        movem.w (sp)+,d1-d2/d4
nx_scan
        moveq   #1,d3
        bsr     ib_wscnx        look for another
chk_cond
        bne.s   okrts           not found
        tst.b   wv.rtlno(a6,a2.l) musn't be already in use
        bpl.s   nx_scan         it is

        move.w  bv_linum(a6),wv.rtlno(a6,a2.l)
        move.b  bv_stmnt(a6),wv.rtstm(a6,a2.l)
        move.b  bv_inlin(a6),wv.rtinl(a6,a2.l)
        move.w  bv_index(a6),wv.rtind(a6,a2.l)
        movem.w d1-d2/d4,-(sp)

        assert  wv.wlno,wv.wstm-2
        move.l  wv.wlno(a6,a2.l),d4 get when line/statement number
        tst.b   bv_sing(a6)     is this a command line
        beq.s   golin           no, ok
        jsr     ib_stbas(pc)    yes, find the top
golin
        bsr.s   goto            go to it
        bne.s   pop_6
        jsr     ib_nxnon(pc)    get the when
        lea     2(a4),a0        skip it
        sub.l   bv_vvbas(a6),a2
        move.l  a2,-(sp)
        jsr     ca_evalc(pc)    and evaluate the condition
        move.l  (sp)+,a2
        add.l   bv_vvbas(a6),a2 restore wv entry
        move.l  a0,a4
        ble.s   pop_6           failed
        addq.l  #2,bv_rip(a6)
        tst.w   0(a6,a1.l)      true or false?
        bne.s   gotit           true! we've got work to do
        bsr.s   ib_ewret        return to here
        beq.s   nx_load
pop_6
        addq.l  #6,sp
        rts

gotit
        addq.l  #6,sp
        move.b  wv.inlin(a6,a2.l),bv_inlin(a6)
okrts
        moveq   #0,d0
        rts

ib_ewret
        assert  wv.rtlno,wv.rtstm-2
        move.l  wv.rtlno(a6,a2.l),d4 return line/statement number
        st      wv.rtlno(a6,a2.l) mark as no longer in use
        move.b  wv.rtinl(a6,a2.l),bv_inlin(a6)
        move.w  wv.rtind(a6,a2.l),bv_index(a6)
goto
        swap    d4              line number to lsw, save statement in msb
        tst.w   d4
        seq     bv_sing(a6)     command line?
        jsr     ib_golin(pc)    go to it
        bne.s   err_nf
        jsr     ib_stnxi(pc)    start it off
        rol.l   #8,d4           fetch out statement from msb
        jmp     ib_gost(pc)     go to it

err_nf
        moveq   #err.nf,d0
        rts

        end
