* Keyword checking routine
        xdef    pa_kywrd

        xref    pa_alfnm

        section pa_kywrd

* d6 -ip - keyword number
* a0 -i o- pointer to buffer
* a2 -ip - pointer to kytab
* a6 -ip - pointer to basic area
* d0-d3/a1 destroyed

* The keyword specified is checked, including verifying that it, or it plus
* some valid "follow on" keyword, ends at a non-alphanumeric.

* A direct return will indicate that the keyword did not match. a0 is garbage.
* A return + 2 will have moved a0 to the end of the matched keyword.

pa_kywrd
        moveq   #0,d0           haven't set saved buffer position yet
        moveq   #0,d3
        move.b  0(a2,d6.w),d3   get offset in keytable
        lea     0(a2,d3.w),a1   point at pre-byte of keyword
        move.b  (a1)+,d3        and read it
        ror.l   #4,d3           length in lsw, follow on count in msb's
inner
        subq.w  #1,d3           subtract one from length
        bcs.s   keyend          end of keyword
        move.b  (a1)+,d1        get next keychar
        addq.l  #1,a0           step on buffer
inent
        move.b  -1(a6,a0.l),d2  get next buffer character
        eor.b   d1,d2
        and.b   #-1-32,d2       ignore case
        beq.s   inner           match, repeat
        lsl.b   #2,d1           nomatch, can we skip this char?
        bmi.s   skip            yes - start skipping (n.b. z not set)
* Failed match on an uppercase letter in the keyword
        tst.l   d0
        beq.s   rts0            error on d6 keyword, just return
prebyte
        clr.w   d3              clear char counter
        rol.l   #4,d3           bring in follow on count
        subq.b  #1,d3           check follow on count
        bcs.s   rts0            matched d6+alphanum, but no valid follow on
        move.l  d0,a0           move buffer pointer back to mark
        move.w  d3,d2           start to form next follow on pointer
        add.w   d6,d2           now have the offset
        ror.l   #4,d3           tuck away follow on count
        move.b  1(a2,d2.w),d3   get the offset byte
        lea     0(a2,d3.w),a1   absolute pointer to next follow on prebyte
        move.b  (a1)+,d3        read next prebyte
        lsr.b   #4,d3           just keep the length
        bra.s   inner

sklp
        move.b  (a1)+,d1        get next keychar
        btst    #5,d1           check for lower case
skip
        dbeq    d3,sklp         n.b. when we come in here, z is clear
        beq.s   inent           reenter main loop if lowercase again
        subq.l  #1,a0           end of the keyword, put back buffer
keyend
        jsr     pa_alfnm(pc)    check next buffer char
        bhi.s   endhere         following not alphanumeric: must be keyword
        tst.l   d0              was that the d6 keyword matched?
        bne.s   rts0            no - d6 + follow + a/n = no match 
        move.l  a0,d0           may be a follow on, mark buffer position
        bra.s   prebyte

endhere
        tst.l   d0
        beq.s   goodexit        that was the end of the d6 keyword, so ok.
        move.l  d0,a0           put the buffer pointer back where we want it
goodexit
        addq.l  #2,(sp)
rts0
        rts

        end
