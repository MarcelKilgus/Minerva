* Set up color mask
        xdef    cs_color,cs_plain

        include 'dev7_m_inc_sv'

        section cs_color

* d1 c p colour number
* d2   p scratch
* a1 c p pointer to two word colour pattern
* a6 i p system variables

reglist reg     d1-d2

cs_color
        movem.l reglist,-(sp)

        bsr.s   cs_plain        convert d1 3 bits to colour
        move.w  d2,(a1)         save the plain colour (even)
        move.w  d2,2(a1)        save the plain colour (odd)

* Now for the stipple

        lsr.b   #3,d1           shift down the rest of the byte
        beq.s   exit            are there any bits set ?
        bsr.s   cs_plain

        lsr.b   #4,d1           stipple flags: ms in d1, ls in carry
        bcc.s   vertical        check for horizontal component
        beq.s   eorexit         purely horizontal, go eor odd (01 done)
        eor.w   d2,2(a1)        create horizontal part for 11 stipple
vertical
        btst    #3,sv_mcsta(a6) check screen mode
        bne.s   m256_msk
        and.w   #$5555,d2       mask out alternate pixels in 512
eor_vert
        eor.w   d2,(a1)         in even lines
        ;       we have 00 10 and 11 left... just need to test msb
        tst.b   d1              is it single dot stipple ?
        beq.s   exit
eorexit
        eor.w   d2,2(a1)        and modify odd lines
exit
        movem.l (sp)+,reglist
        rts

m256_msk
        and.w   #$3333,d2       mask out alternate pixels in 256
        bra.s   eor_vert

* d1 c p colour number in 3 lsb's
* d2   o color mask (.w) for mode and 3 lsb's of d1
* a6 i p system variables

cs_plain
        btst    #3,sv_mcsta(a6) check mode
        bne.s   m256_col
        moveq   #6,d2           ignoring lsb (blue)
        and.b   d1,d2
        move.w  col512(pc,d2.w),d2
        rts

col512
        dc.w    $0000,$00ff,$ff00,$ffff

m256_col
        moveq   #7,d2
        and.b   d1,d2
        add.b   d2,d2
        move.w  col256(pc,d2.w),d2
        rts

col256
        dc.w    $0000,$0055,$00aa,$00ff,$aa00,$aa55,$aaaa,$aaff

        end
