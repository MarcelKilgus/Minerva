* Write a character to screen
        xdef    cs_char

        include 'dev7_m_inc_sd'

        section cs_char

* Parameters:
* d0 x position
* d1 y position
* d2 character to display
* d3 attributes byte
* a0 channel control block
* a1 pointer to colour masks
* a2 primary fount pointer
* a3 secondary fount pointer
* all registers are preserved

* Internal usage:
* d0 bit 31 set if dh and even row count / lsw row loop index
* d1 bits 5-0 character shift
* d2 character field mask
* d3 bits 31-25 attributes, 31=dw / lsw character row
* d4 bit 31 dh / bit 30 dh row / bit 29 dh blank / lsw char row masked with ink
* d5 flash mask
* d6 paper colour masks
* d7 ink colour masks
* a1 pointer to screen
* a2 pointer to character in fount
* a3 saved char row for dh
* a4 internal jump address
* a5 underscore line number

reglist reg     d0-d7/a1-a5

cs_char
        movem.l reglist,-(sp)

* Set up the colour patterns

        movem.l (a1),d6-d7      fetch patterns
        btst    #0,d1           odd row?
        bne.s   masks_ok        ... yes - carry on
        swap    d6              ... no - swap the colour masks
        swap    d7
masks_ok

* Set the fount address

        and.w   #$ff,d2         character is eight bit
        sub.b   (a2)+,d2        take away minimum character in first fount
        cmp.b   (a2)+,d2        is it in range?
        bls.s   calc_font       ... yes - use it
        add.b   -2(a2),d2       ... no - restore character value
        move.l  a3,a2           try alternative fount
        sub.b   (a2)+,d2        take away minimum character
        cmp.b   (a2)+,d2        is it in range?
        bhi.s   font_set        ... no - we're already at invalid char pattern
calc_font
        add.w   d2,a2           address is now 9*character value on from base
        lsl.w   #3,d2
        add.w   d2,a2
font_set

* Now find the screen position

        move.l  sd_scrb(a0),a1  base of screen
        mulu    sd_linel(a0),d1 and y * bytes per row
        add.l   d1,a1           gives the row address
        moveq   #7,d1
        and.w   d0,d1           the three ls bits of x form the shift
        lsr.w   #3,d0           and 8 pixels per byte
        add.w   d0,d0           ... or rather per pair of bytes
        add.w   d0,a1           ... finishes off the screen address

* Set up the attributes

        move.w  #-1,a5          underline at line -1!!
        btst    #sd..ulin,d3    is underline required
        beq.s   ul_ok           no - leave that
        addq.l  #2,a5           yes - underline at row 1
ul_ok

        moveq   #16,d4          max field width 16 and clear dh flags
        move.w  sd_xinc(a0),d2
        beq     getout          just in case x-inc was zero!
        sub.w   d2,d4
        bcc.s   inc_ok
        moveq   #0,d4           if x-inc is greater than 16, we stop at 16
        ; This needs a bit more fiddling to stick paper into any further
        ; columns when normal writing is occuring....
inc_ok

        moveq   #0,d2           start field mask
        bset    d4,d2
        neg.w   d2
        ror.l   #8,d2
        ror.l   d1,d2           rotate character mask to position

        moveq   #0,d5           clear flash mask
        ror.l   #sd..dbwd+1,d3  are characters double width
        bpl.s   width_ok        ... no - that's done
        addq.w  #8,d1           set double width shift
        btst    #31-sd..dbwd+sd..flsh,d3 is flash required?
        beq.s   width_ok        ... no - check for extend
        move.w  #$4000,d5       set flash on bit
        bchg    d4,d5           set flash off bit
        ror.l   d1,d5           rotate flash mask to position
width_ok

        moveq   #0,d0
        move.w  sd_yinc(a0),d0
        beq.l   getout          let's not mess with zero height chars!
        subq.w  #1,d0           ready for dbra
        btst    #31-sd..dbwd+sd..dbht,d3 are tall characters required?
        beq.s   hght_ok
        moveq   #-1,d4          set up tall flags
        ror.l   #1,d0           halve row count but save lsb in bit 31
hght_ok

* Now set up the jump address for character writing mode

        lea     normal,a4       assume normal writing
        btst    #31-sd..dbwd+sd..trns,d3 check for transparent strip
        beq.s   col_loop
        subq.l  #normal-transp,a4
        btst    #31-sd..dbwd+sd..xor,d3 check for xor ink
        beq.s   col_loop
        subq.l  #transp-xor,a4

* Main loop for each word column occupied by character

collist reg     d0/d6-d7/a1-a2
col_loop
        movem.l collist,-(sp)
        move.b  d2,d3           replicate character mask byte
        lsl.w   #8,d2
        move.b  d3,d2
        lsl.w   #8,d5           move flash mask up to ms byte

* Inner loop for each row

row_loop
        cmp.w   #9,d0           row number 9 or greater?
        bge.s   blank_row       if so, jump, to get blank line
        cmp.w   a5,d0           check for underline row
        beq.s   set_under

        clr.w   d3              clear upper byte
        move.b  (a2)+,d3        and fetch next row
        beq.s   blank_row       if zero - ignore all the next rubbish

        tst.l   d3              for double width, spread characters out
        bpl.s   shft_chr
        tst.l   d5              are we setting flash at all?
        beq.s   noflash         no - that's ok
        and.b   #$7f,d3         yes - can't allow first bit to set ink!
noflash
        move.w  d3,d4
        and.b   #15,d4
        lsr.b   #4,d3
        move.b  spread(pc,d3.w),d3
        lsl.w   #8,d3
        move.b  spread(pc,d4.w),d3

shft_chr
        ror.w   d1,d3           shift to position and replicate
        move.b  d3,d4           replicate a byte
        lsl.w   #8,d3
        move.b  d4,d3
        and.w   d2,d3           mask character with field

mask_ink
        move.w  d3,a3           save masked character row in case dh
        move.w  d3,d4
        and.w   d7,d4           mask character with ink
        or.w    d5,d4           put flash in
        jmp     (a4)            jump to code for writing mode

spread
        dc.l    $00030c0f,$30333c3f,$c0c3cccf,$f0f3fcff

set_under
        move.w  d2,d3           full row underline
        addq.l  #1,a2           move fount pointer past ignored byte
        move.w  d3,a3           save masked character row in case dh
        move.w  d3,d4
        and.w   d7,d4           mask character with ink (can't flash)
        jmp     (a4)            jump to code for writing mode

dh_row
        bchg    #30,d4          toggle row bit
        beq.s   next_row        if it was already second row, carry on normal
        tst.l   d0              is it the last row of an odd height?
        beq.s   col_end         yes - then it's finished
        bset    #29,d4          is it 2nd row of a blank character?
        beq.s   blank_2nd       yes - go do that
        move.w  a3,d3           restore the character
        bra.s   mask_ink        go do normal stuff 

blank_row
        bclr    #29,d4          clear flag in case dh
blank_2nd
        btst    #31-sd..dbwd+sd..trns,d3 is it anything but normal writing?
        bne.s   end_row         yes - nothing to do
        move.w  (a1),d4         pick up existing stuff
        eor.w   d6,d4           flip with paper pattern bits
        and.w   d2,d4           keep just the field area we want to affect

xor
        eor.w   d4,(a1)         xor into screen
        bra.s   end_row

transp
        not.w   d3              mask in background not part of character
        and.w   (a1),d3
        bra.s   combine

normal
        eor.w   d2,d3           invert character in field
        and.w   d6,d3           mask inverse character with paper
        or.w    d4,d3           put in ink/flash
        move.w  d2,d4           get inverted field mask in d4
        not.w   d4
        and.w   (a1),d4         blank out character area of screen
combine
        or.w    d3,d4           combine the two
        move.w  d4,(a1)         and put in screen

end_row
        swap    d6              swap colours
        swap    d7
        add.w   sd_linel(a0),a1 take next line
        tst.l   d4              check for double height
        bmi.s   dh_row
next_row
        dbra    d0,row_loop

col_end
        movem.l (sp)+,collist   recover various registers
        clr.w   d2              check for any remaining bits
        rol.l   #8,d2           ... by rotating mask to next byte
        bne.s   nxt_col         if there's more, go do it
getout
        movem.l (sp)+,reglist
        rts

nxt_col
        clr.w   d5              roll in next byte's worth of flash mask
        rol.l   #8,d5
        asr.l   #4,d4           reset dh flags

        eor.b   #8,d1           flip bytes on the rotate
        addq.l  #2,a1           move to next column
        bra.l   col_loop

        end
