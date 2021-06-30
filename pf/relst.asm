* Relist part of a file during edit

        xref    bp_liste,bp_listf

        include 'dev7_m_inc_vect4000'

        section pf_relst

* This is merely a small dummy only to provide for the vector entry points, and
* is not used by the rest of the system at all.

* Note. The bp_liste vector was a pain, so changed it to pf_liste and moved the
* (apparently!) unused bp_lista and bp_lists code here. Cost: 1 word.

        moveq   #0,d4           old (unused?) bp_liste
        move.w  #$7fff,d6       old (unused?) bp_lists
pf_liste
        jmp     bp_liste(pc)    go to the proper code
        jmp     bp_listf(pc)    arghhhh!!!! TK2's ed jumps in here!

* When TK2's ed comes in, a4 has already been made to point at the length
* change word of the line it wants listed into the basic buffer.
* d4 and d6 both contain that line's number.
* d7 and bv_print(a6) are both zero.
* By giving ourselves a new entry point to the bp routine, we can skip into the
* listing code at a more auspicious point, rather than messing about trying to
* set up things that are already established.

        vect4000 pf_liste

        end
