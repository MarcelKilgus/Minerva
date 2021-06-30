* Check name for entry in table
        xdef    pa_chnam,pa_chunr

        xref    pa_kywrd
        xref    bv_chnlx,bv_vtype
        xref    ca_oldnt

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_mt'

        section pa_chnam

* Note. The scan of the name table has been changed about, hopefully saving a
* considerable amount of time during load's.
* The basic technique being to try to match the length byte and the first
* character before even checking that there is a real, named, entry.

* d5 -i o- length of name in buffer (msb's clear) / no of name in table
* a2 -i o- pointer to keyword table / pointer to name table
* a3 -i  - pointer to start of buffered name to check for (rel a6)
* a6 -ip - area on which bv pointers are indexed

* d0-d3/d6/a0-a1 destroyed

regon   reg     d4/d7/a2-a3/a5
regoff  reg     d4/d7/a0/a3/a5

pa_chnam
        movem.l regon,-(sp)     save a few regs for later (a2->a0 below)
        lea     scanner,a2
        moveq   #mt.extop,d0    increment non-sheduling mode
        trap    #1
        movem.l (sp)+,regoff    put kytab in a0 for now
        tst.b   d6
        beq.s   found           goody! we have found the match

        move.l  a0,a2           set beginning of keyword table
        moveq   #0,d6           must start at zero, as remark follows remainder
kyloop
        addq.b  #1,d6
        cmp.b   (a2),d6         check against all keywords and pairs thereof
        bgt.s   newnam
        move.l  a3,a0           set buffer start
        jsr     pa_kywrd(pc)
        bra.s   kyloop          no match
        rts                     illegal name, better tell user

* Name not in table or keywords. Add it to table in first free slot
newnam
        moveq   #4+8+12,d0      total stack depth at this point
        bsr.s   pa_chunr        check in case we're in an unravel
        move.l  d5,d1
        addq.l  #1,d1           space required is nchars plus one
        jsr     bv_chnlx(pc)    check space in namelist
        exg     a2,a5
        jsr     ca_oldnt(pc)    get a spare/new name table entry built for us
        exg     a2,a5
        subq.l  #8,a2
        assert  bv_nlbas,bv_nlp-4
        movem.l bv_nlbas(a6),d2/a0
        neg.w   d2
        add.w   a0,d2
        move.b  d5,0(a6,a0.l)   put name length into namelist entry
        addq.l  #1,a0
addchar
        move.b  0(a6,a3.l),0(a6,a0.l) put buffer char into namelist
        addq.l  #1,a3
        addq.l  #1,a0
        subq.b  #1,d5           one char gone
        bne.s   addchar
        move.w  d2,2(a6,a2.l)   put namelist offset into nametable entry
        move.l  a0,bv_nlp(a6)   update running namelist pointer
        jsr     bv_vtype(pc)    set up usage and variable type

* Send back entry number in name table
found
        move.l  a2,d5           get position in name table
        sub.l   bv_ntbas(a6),d5
        lsr.l   #3,d5           ..gives 0,1,2,3...etc
        addq.l  #2,(sp)         good exit
        rts

* Return to unvr if we are stuck in an unravel.

* d0 -i o- depth of stack to get back to unvr if we're stuck

pa_chunr
        tst.b   bv_unrvl(a6)    is nt is stuck in an unravel?
        beq.s   rts0            no - that's ok
        add.l   d0,sp           lose stacked data and returns
        moveq   #1,d0           set codition codes postive for unvr
rts0
        rts

scanner
        assert  bv_ntbas,bv_ntp-4,bv_nlbas-8
        movem.l bv_ntbas(a6),d0/d6/a5
        sub.l   d0,d6           nl size
        lsr.l   #3,d6           nl count
        lea     2-8(a6,d0.l),a2 absolute nt base for first nl offset
        add.l   a6,a5           absolute nl base
        add.l   a6,a3           make buffer absolute
        move.b  (a3)+,d7        get first byte out just the once
        moveq   #1,d1           just to improve spare entry test
        moveq   #-1-32,d3       mask to clear lower-case bit, ccr non-z
        bra.s   nment

nmloop
        addq.l  #8,a2
        move.w  (a2),a0
        add.l   a5,a0
        cmp.b   (a0)+,d5        match name length first, even if it's silly
        dbeq    d6,nmloop       gets through bulk of nt as quick as we can
        bne.s   nmexit
        move.b  (a0)+,d0
        eor.b   d7,d0
        and.b   d3,d0           does first char match?
        dbeq    d6,nmloop       no, we're still whizzing along fast
        bne.s   nmexit
* Now it's time to settle into the rest of the tests.
* We have got past to this point quickly, and we now know the length is the
* same and the first byte is also matched.
* We skipped testing for spare/unnamed entries until now to make the scan fast!
* Assuming we will actually normally find a match, and the incidence of unnamed
* entries is low until we get to the top of the table, we should be doing quite
* a bit better on speed at this point.
* The name offset in duff cases will always be zero (spare) or -1 (unnamed),
* so we shouldn't have any problems using it.
* On a typical load, with not many extensions, 30% of the time was spent here!
* A further gain might be made by "cacheing" the most recent four, or maybe a
* few more, matched nt entry numbers, but this could get a bit complex, for
* what should now be a small gain in overall speed.
        tst.b   (a2)            did this entry have a real nl offset?
        bmi.s   nment           negative offset, we wasted a tiny bit of time
        cmp.l   -2(a2),d1       is it an annoying "spare" entry?
        bhi.s   nment           unset sub-string, no less! (nb ccr not z!)

        move.l  a3,a1           copy buffer pointer
        move.w  d5,d4           set length
        subq.w  #1,d4           we've done one character
        beq.s   nmfnd           wow! it was just one char, so we're done
        subq.w  #1,d4           less one to compensate for dbne
nmchr
        move.b  (a1)+,d2        get buffer char
        move.b  (a0)+,d0        get table char
        eor.b   d2,d0           look at differences
        and.b   d3,d0           clear lc bit
        dbne    d4,nmchr        loop round and try again if matched and more
nment
        dbeq    d6,nmloop       drop out if full match or none left
nmfnd
        subq.l  #2,a2           back to base of matched entry
        sub.l   a6,a2           make nt pointer relative
nmexit
        sne     d6
        rte

        end
