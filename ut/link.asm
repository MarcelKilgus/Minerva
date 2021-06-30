* Add/remove item in linked list
        xdef   ut_link,ut_unlnk

        section ut_link

* a0 cr  pointer to item to be added or removed
* a1 cr  pointer to start of linked list / pointer to previous item

ut_link
        move.l  (a1),(a0)       put pointer to next in this item
        move.l  a0,(a1)         and link it in
        rts

nxt_link
        move.l  (a1),a1         get next link
ut_unlnk
        tst.l   (a1)
        beq.s   end_unlk        give up at end of list
        cmp.l   (a1),a0
        bne.s   nxt_link        loop until we find pointer to item
        move.l  (a0),(a1)       move link pointer back in list
end_unlk
        rts

        end
