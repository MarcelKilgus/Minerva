* Scan free space
        xdef    mm_scafr

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_hp'

        section mm_scafr

* N.B. Changed to do unsigned comparisons of lengths, so as not to be caught
* out by people asking for negative space!

* The outputs are confusing when presented all together, so here they are in
* the differing request/result states:

* If there was no adequate space, ccr is zero and:
*       a0 and a1 are each the pointer to the last free space.
*       a2, d2 and d3 are all zero.
* If d0.w is non-zero and an adequate space is found, ccr is tst.w d0 and:
*       a1 and a2 are each the pointer the pointer to the space.
*       a0 is its base address.
*       d2 and d3 are each its size.
* If d0.w is zero and any adequate spaces have been found, ccr is zero and:
*       a0 and a1 are each the pointer to the last free space.
*       d3 is zero.
*       d2 records the size of largest adequate space that was found.
*       a2 is the pointer to the pointer to the last adequate space.

* d0 -ip - word non-zero exits at first adequate free space, zero scans all
* d1 -i o- free space required / rounded up to allocation multiple
* d2 -i    allocation multiple less one (7..32767, must be 2^n-1)
*       o- length of longest adequate free space, or zero if none
* d3 -  o- if d0=0 and space found, length of free space, otherwise zero
* a0 -i    pointer to pointer to free space
*       o- if d0=0 and found last free space, otherwise same as a1
* a1 -  o- free space preceeding last free space scanned
* a2 -  o- free space preceeding last adequate free space found, zero if none
* CCR-  o- non-zero (tst.w d0) only when a good space is found

mm_scafr
        add.l   d2,d1
        not.w   d2
        and.w   d2,d1           round length up to nearest allocation multiple

        moveq   #0,d2           initialise longest space
        sub.l   a2,a2           initialise pointer to last adequate free space

        subq.l  #hp_next,a0     fiddle the call pointer
fr_loop
        move.l  a0,a1           save pointer to prior free block
        move.l  hp_next(a0),d3  get link
        beq.s   rts0            zero - we've reached the end of the free chain
        add.l   d3,a0           point to next free block

        move.l  hp_len(a0),d3   get length of this block
        cmp.l   d1,d3           is this adquate?
        bcs.s   fr_loop         no - go look at next block

        move.l  a1,a2           save pointer to prior free block

        cmp.l   d3,d2           is this block bigger than the largest so far?
        bcc.s   maxok
        move.l  d3,d2           yes - save new maximum length
maxok

        tst.w   d0              were we asked scan the whole chain?
        beq.s   fr_loop         yes - carry on scanning

rts0
        rts

        end
