* Link in a free space
        xdef    mm_lnkf0,mm_lnkfr

        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_assert'

* The free list is scanned to locate any immediately neighbours of the newly
* supplied space, and if possible, coalesce them with it.
* The returned values are used to decide on reducing the chp/trn areas.

* N.B. Due to a misinterpretation of how heaps should be managed, this was
* wandering down the free chain after the newly linked in block. Wrong!

* The whole point of the heap is to allow the linking in of additional space
* from outside of the original area.

* There is a flaw present in this, should the system heaps be so extended.
* how do we scan a heap?
* Job removal must do a scan of chp to de-allocate blocks owned by dying jobs.

* An idea: require such space to be set up specially, then introduced as a
* small piece which is up the top end, but length zero, so it will never be
* allocated, and finally free up the bulk of the area.
* We will prefer this latter area to have a size of the appropriate multiple,
* otherwise any odd bit will keep hanging about on the free list uselessly.

* E.g. for an extra area built in "len+10" bytes at address "addr":
* 1) set addr:len,0,0 and addr+len:-len
* 2) free zero bytes at addr+len+2 (if sysmon objects, we may need to alter)
* 3) free len bytes at addr

* The presence of zero length free areas on the free chain can be easily
* incorporated in the scan routine for the heap. The negative length preceeding
* such a free area is used to get to the base of the area, and also as a stop
* to recognise the end of the area. Note that the little free trailer will
* never be coalesced. Also note that we need the main area preset to look like
* it is in use and owned by job zero, as it must already be valid for a scan,
* should one occur between the two calls freeing the spaces.

* This still needs one more comment: we can now get a scenario where the base
* link for the free chain is not zero, but the area has top matching bottom.
* this will be important in the case of respr, when we will be able to have
* jobs running in the extra areas, but the trn itself will have its top and
* bottom matching, to show it as empty.
* One final thought... the trn area will work nicely as it is, but the chp does
* first fit, so extend that a.s.a.p... slaving will like it!

        section mm_lnkfr

* d1 -i o- length of new free space / length of final free space
* d2 -  o- offset stored in final free space, zero if end of free chain
* a0 -i o- address of new free space / offset a1-a2 at end
* a1 -i o- pointer to link / pointer to resultant free space
* a2 -  o- pointer to preceeding free space

mm_lnkf0
        clr.l   hp_owner(a0)    for system heaps mark the owner 0
* Should we do something with the rflag as well?
* E.g. setting the top bit of rflag and using the rest for something nice!
mm_lnkfr
        subq.l  #hp_next,a1     fiddle the call pointer

* Loop through free space link pointers and link in new block
* a2 points to previous block, a1 to current block

        move.l  d3,-(sp)        we will preserve d3 here, to be friendly
        sub.l   a2,a2           no previous pointer
fr_loop
        move.l  a2,d3           remember previous pointer
        move.l  a1,a2           get next link pointer
        move.l  hp_next(a1),d2
        beq.s   prelink         is it last link?
        add.l   d2,a1           no - set address of next
        cmp.l   a0,a1           check if pointer past new space
        ble.s   fr_loop

* < 2nd prior > ... < prior free > ... < new freed > ... < next free > ...
* d3:??/??          a2:??/d2           a0:??/??          a1:??/??

        move.l  a1,d2
        sub.l   a0,d2           make intended forward relative link to next
        cmp.l   d1,d2           does next coalesce with the new block?
        bne.s   prelink
        assert  0,hp_len,hp_next-4
        add.l   (a1)+,d1        yes - extend length of freed block
        add.l   (a1),d2         add relative offset to what we have so far

* < 2nd prior > ... < prior free > ... < new freed > ...
* d3:??/??          a2:??/??           a0:??/??, d1=length, d2=offset to next

prelink
        tst.l   d3              is there in fact a 2nd prior?
        beq.s   linkit          no - we were right at the start, so skip this
        move.l  a0,a1
        sub.l   a2,a1
        cmp.l   (a2),a1         does prior join up with free block?
        bne.s   linkit
        move.l  a2,a0           yes - let's shuffle ourselves down there
        move.l  d3,a2           move up 2nd prior to prior now
        add.l   a1,d1           increase length
        add.l   a1,d2           increase relative offset

* < prior free > ... < new freed > ...
* a2:??/??           a0:??/??, d1=length, d2=offset to next

linkit
        move.l  (sp)+,d3        finished with d3 now
        cmp.l   d1,d2           in all the machinations, is this the last free?
        bgt.s   setlnk          no, as the offset is beyond this block
* Note: we don't need to check anything more complex than this. The value of d2
* we get here with may indeed be an offset to a free block that we have
* coalesced, but that'll be fine.
        moveq   #0,d2           yes! make the offset a proper zero
setlnk
        movem.l d1-d2,(a0)      set new area's length and relative link
        move.l  a0,a1           want to return it in a1, for some reason...
        sub.l   a2,a0
        move.l  a0,hp_next(a2)  set prior free's link to the new free area
* Note: setting that one last ensures that the free chain has never been
* in a corrupt state during any of the proceedings. Also, the "movem" ensures
* similarly valid handling when we have coalesced with a preceeding space. In
* this particular case, the final move of a0 is actually redundant!

* < prior free > ... < new freed > ...
* a2:??/a0           a1:d1/d2

        rts

        end
