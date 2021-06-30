* Performs area operations
        xdef    cs_fill,cs_over,cs_pan,cs_recol,cs_scrol

        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_sv'

reg_list reg    d0-d7/a0-a6
        offset  0 ; positions on stack
        ds.l    3
spd3    ds.l    1
spd4    ds.l    1

        section cs_area

* d0 c p x origin
* d1 c p y origin
* d2 c p width
* d3 c p height
* d4 c p distance to scroll or pan
* a1 c p pointer to colour masks

* Internal register usage

* d0-d2   scratch
* d3      width in long words -1 (=a5/4)
* d4      left hand edge mask
* d5      right hand edge mask
* d6      one stipple row colour
* d7      the other stipple row colour
* a0      channel definition block (i hope! lwr)
* a1      origin of area / running pointer to destination
* a2      end of area
* a3      increment between lines
* a4      running pointer to source
* a5      width -4 (=d3*4)
* a6      address of operation routine

* Set up the colour masks in d6/d7

set_colm
        move.l  (a1),d6         get even lines in upper, odd in lower word
        move.w  d6,d7
        swap    d7
        move.w  d6,d7           put odd lines in both halves of d7
        move.w  (a1),d6         put even lines in both halves of d6

        btst    #0,d1
        bne.s   set_addr
        exg     d6,d7           if even nline - swap them over

* Set up all the registers for addressing an area

set_addr
        add.w   d0,d2           find rhs

        move.w  sd_linel(a0),a3 get line length
        move.w  a3,d5
        mulu    d5,d1           set y address offset
        move.l  sd_scrb(a0),a1  + base of screen
        add.l   d1,a1
        mulu    d5,d3           find end of screen
        move.l  d3,a2

        move.w  d2,d3
        subq.w  #1,d3
        asr.w   #4,d3           rhs rounded down to long words
        move.w  d0,d4
        lsr.w   #4,d4           x origin in longwords
        sub.w   d4,d3           length less one
        move.w  d3,a5
        add.w   a5,a5
        add.w   a5,a5           set length less one longword in bytes

        lsl.w   #2,d4           x origin in bytes
        add.w   d4,a1           add to base
        add.l   a1,a2           and add base to offset of lower edge

        bsr.s   mask            calc rhs mask
        move.w  d0,d2           next will be lhs mask
        neg.w   d5
        move.w  d5,d0           keep a copy of negated linel for scroll
        move.l  d4,d5           set rhs mask

        not.l   d5              invert rhs mask
        bne.s   mask            if not all outside, go set lhs
        moveq   #-1,d5          make rhs all ones

mask
        moveq   #-1,d4          fill mask
        and.w   #15,d2          use least significant 4 bits of position
        lsr.w   d2,d4           shift to form mask ffab
        move.w  d4,d2           save ab
        lsl.l   #8,d4           mask -> fab0
        move.w  d2,d4           -> faab
        lsl.l   #8,d4           -> aab0
        move.b  d2,d4           -> aabb
        rts

cs_over
        movem.l reg_list,-(sp)
        bsr.s   set_colm        set up colour masks and pointers
        lea     over_op,a6      set up over operation address
        tst.w   d3              longword count minus one
        bne.s   area_c_1        more than one - OK
        and.l   d5,d4           just one - superimpose lhs and rhs masks
        bra.s   area_c_1

set_cm_1
        bra.s   set_colm

cs_recol
        movem.l reg_list,-(sp)
        move.l  a1,a4           save pointer to remap
        bsr.s   set_addr        set scan pointers etc.
        add.w   d3,d3           remap operates on words
        addq.w  #1,d3

        btst    #3,sv_mcsta(a6) check display mode
        lea     rmap4_op,a6     set 4 colour mode
        beq.s   area_c_1
        lea     rmap8_op,a6     set 8 colour mode
area_c_1
        bra.s   area_com

cs_scrol
        movem.l reg_list,-(sp)
        bsr.s   set_cm_1        set up colour masks and pointers
        move.w  spd4+2(sp),d2   get displacement
        muls    d0,d2           scale up by negated line length
        bgt.s   up              scroll pixels down?
        exg     a2,a1           operate the other way
        move.w  d0,a3           use negated line length
        add.l   a3,a1           adjust where we write
        add.l   a3,a2

        btst    #0,spd3+3(sp)   ensure that colour masks are right way
        bne.s   set_dn          odd height is ok
        exg     d6,d7
set_dn
        lea     0(a1,d2.l),a4   set source address
        cmp.l   a4,a2
        bra.s   scroll
up
        lea     0(a1,d2.l),a4   set source address
        cmp.l   a2,a4

scroll
        bge.s   fill            no area left
        lea     scrol_op,a6     set scroll operation address
        sub.l   d2,a2           reduced area
        bsr     area_op
        add.l   d2,a2           restore end address
        bra.s   fill            and fill rest of area

cs_fill
        movem.l reg_list,-(sp)
        bsr.s   set_cm_1        set up colour masks
fill
        lea     fill_op,a6      set up fill operation address
        bra.s   area_com

cs_pan
        movem.l reg_list,-(sp)
        bsr.s   set_cm_1        set up colour masks and pointers
        swap    d3              save width counter in msw
        move.w  #-16,d3         mask for setting shift length
        move.w  #4,a0           pointers go up, maybe
        move.w  spd4+2(sp),d2   get displacement
        bpl.s   right

        neg.w   d2
        or.w    d2,d3           (-displacement) mod 16 - 16
        neg.w   d3              16 - (-displacement) mod 16

        swap    d3              shift to msw
        lsr.w   #4,d2           and horizontal offset in d2
        cmp.w   d2,d3           is there anything left to pan?
        bcs.s   fill            just clear it
        sub.w   d2,d3           else reduce length
pan_go
        lsl.w   #2,d2           back to byte count
        lea     0(a1,d2.w),a4   set the source
        addq.w  #1,d3           adjust long word count
        lea     pan_op,a6
area_com
        bsr.s   area_op
        movem.l (sp)+,reg_list  restore all registers
area_rts
        rts

right
        or.w    d2,d3           displacement mod 16 - 16
        and.w   #$1f,d3         16 + displacement mod 16

        swap    d3              in msw of d3
        lsr.w   #4,d2           find the long word shift
        cmp.w   d2,d3           anything left to pan?
        bcs.s   fill            just clear it
        sub.w   d2,d3           else reduce the length

        exg     a5,d0           negate the length
        neg.l   d0
        exg     d0,a5
        exg     d4,d5           swap the masks
        subq.w  #8,a0           go backwards
        sub.w   a5,a1           from other end
        sub.w   a5,a2
        neg.w   d2              negate shift count
        bra.s   pan_go

* Now for the general area operation

op_retrn
        subq.l  #4,a1           backspace to end of line
op_retx
        move.l  (a1),d0         get the long word written
        and.l   d5,d0           mask it
        move.l  d5,d1           move mask
        not.l   d1              negate
        and.l   (sp)+,d1        mask old contents
        or.l    d1,d0           combine the bits
        move.l  d0,(a1)         and put edge back

* Now restore left hand edge (can save 6 bytes if following code is subroutine)

        sub.l   a5,a1           goto left hand edge
        move.l  (a1),d0         get the long word written
        and.l   d4,d0           mask it
        move.l  d4,d1           get the mask
        not.l   d1
        and.l   (sp)+,d1        negate mask with old contents
        or.l    d1,d0           combine the bits
        move.l  d0,(a1)         and put edge back

        add.l   a3,a1           move to next line
area_op
        cmp.l   a2,a1           is it end?
        beq.s   area_rts
        move.w  d3,d0           set loop count
        bmi.s   area_rts        oops
        exg     d6,d7           next line is next colour
        move.l  (a1),-(sp)      save left hand edge
        move.l  0(a1,a5.w),-(sp) save right hand edge

        jmp     (a6)            do line operation

fill_op
        move.l  d6,(a1)+        put in colour
        dbra    d0,fill_op      until end of op
        bra.s   op_retrn

* Over is treated specially to stop the cursor flickering so much the first and
* last dword are masked before xoring-in.
* This frig is not nearly so simple for the other operations!

over_op
        move.l  d4,d1           do first dword always
        and.l   d6,d1           d1 has exor colour masked with start-window
        eor.l   d1,(a1)+
        subq.w  #1,d0           if only one dword, that's it
        bmi.s   op_retrn
        bra.s   over_skip
over_loop
        eor.l   d6,(a1)+        xor in dwords 2 to n-1 if required
over_skip
        dbra    d0,over_loop
        move.l  d5,d1           do last dword if required
        and.l   d6,d1           mask in start/end mask to colour change word
        eor.l   d1,(a1)+
        bra.s   op_retrn

scrol_op
        lea     0(a1,d2.l),a4   set source address
        addq.w  #1,d0           put it back to a simple count
        moveq   #3,d1           speed up by widening loop to 16 bytes at a go
        and.b   d0,d1           pick off two lsb's
        neg.w   d1              negate them
        add.w   d1,d1           and double for entry point to loop
        lsr.w   #2,d0           divide count by four
        jmp     scrol_lp+8(pc,d1.w) enter loop at neat place
scrol_lp
        move.l  (a4)+,(a1)+     move long word
        move.l  (a4)+,(a1)+     move long word
        move.l  (a4)+,(a1)+     move long word
        move.l  (a4)+,(a1)+     move long word
        dbra    d0,scrol_lp     until end of op
op_ret_1
        bra.s   op_retrn

rmap8_op
        move.b  (a1),d6         fetch green and flash bits
        move.b  1(a1),d7        red/blue byte
        lsl.w   #8,d7           in bits 15..8
        swap    d0              save loop count in top of d0
        move.w  #4-1,d0         pixels per word
        moveq   #7,d1           mask for colour index

pix8_lop
        moveq   #0,d2           clear working register
        move.b  d6,d2           get green/flash

        roxr.b  #2,d2           green bit to extend
        move.w  d7,d2           red/blue to d2 bits 9,8
        ror.w   #2,d2           bits 7,6
        roxl.b  #3,d2           grb to d2 bits 2,1,0
        and.w   d1,d2           mask to 0..7
        move.b  0(a4,d2.w),d7   get new colour

        ror.w   #2,d7           shift round red/blue
        ror.b   #1,d6           preserve flash bit
        roxr.b  #1,d7           green bit into extend
        roxr.b  #1,d6           set new green

        dbra    d0,pix8_lop     take next pixel
        swap    d0              get back outer loop count to d0.w

        lsr.w   #8,d7           get green/red into correct word

        move.b  d6,(a1)+        put word back
        move.b  d7,(a1)+
        dbra    d0,rmap8_op     next word
        bra.s   op_ret_1

rmap4_op
        move.b  (a1),d6         fetch word
        move.b  1(a1),d7
        moveq   #8-1,d1         pixels per word

pix4_lop
        moveq   #0,d2           clear working register

        roxr.b  #1,d6           green bit
        addx.b  d2,d2           rotated into d2
        roxr.b  #1,d7
        roxl.b  #2,d2           gr0 in bits 2,1,0

        move.b  0(a4,d2.w),d2   get new colour

        add.b   d7,d7           shift d7 left again by one
        roxr.b  #2,d2           red
        roxr.b  #1,d7           into red
        add.b   d6,d6           shift d6 left again by one
        roxr.b  #1,d2           green
        roxr.b  #1,d6           into green
        dbra    d1,pix4_lop     take next pixel

        move.b  d6,(a1)+        put word back
        move.b  d7,(a1)+
        dbra    d0,rmap4_op     next word
        bra.s   op_ret_1

pan_op
        movem.l d6/a4-a5,-(sp)  save colour, source and width
        add.l   a1,a5           set pointer to rhs
        move.l  (a5),d2         overwrite rhs with background
        and.l   d5,d2           mask in
        move.l  d5,d1           this area
        not.l   d1
        and.l   d6,d1           mask in colour outside
        or.l    d1,d2
        move.l  d2,(a5)

        add.l   a0,a5           move a5 on to form end check
        swap    d3              get shift
        movep.w 0(a4),d1        get the first long word's worth
        movep.w 1(a4),d2
        bra.s   pan_elop

pan_last
        move.l  sp,a4           get last long word off stack
pan_loop
        swap    d1              move existing contents of green
        swap    d2              and red/blue up
        movep.w 0(a4),d1        fetch new long word
        movep.w 1(a4),d2
        move.l  d1,d6           move green to a convenient register
        ror.l   d3,d6           rotate
        movep.w d6,0(a1)        and save it
        move.l  d2,d6           now again for red/blue
        ror.l   d3,d6
        movep.w d6,1(a1)
        add.l   a0,a1           move destination on
pan_elop
        add.l   a0,a4           move source on
        subq.w  #1,d0           decrement counter
        bgt.s   pan_loop
        beq.s   pan_last

        movem.l (sp)+,d6/a4     restore colour and source pointer
        swap    d3              restore loop count
        bra.s   pan_efil

pan_fill
        move.l  d6,(a1)         fill with colour
        add.l   a0,a1
pan_efil
        cmp.l   a1,a5           end?
        bne.s   pan_fill
        move.l  (sp)+,a5        restore width
        add.l   a3,a4           move destination to next line
        sub.l   a0,a1           adjust running pointer
        bra     op_retx

        end
