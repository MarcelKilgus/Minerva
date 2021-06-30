* Set text cursor using graphics coords
        xdef    gw_gcur

        xref    gw_psorg,gw_pscal,gw_asp
        xref    ri_abexb
        xref    sd_setc

        include 'dev7_m_inc_ri'
        include 'dev7_m_inc_sd'

* Stack offsets for use by interpreter:
        offset  -6*6
yorg    ds.w    3
xorg    ds.w    3
gx      ds.w    3
gy      ds.w    3
px      ds.w    3
py      ds.w    3

        section gw_gcur

gw_gcur
        lea     -gx(a1),a4      point to bottom of stack
        jsr     gw_psorg(pc)    push the window origin
        jsr     gw_asp(pc)      get the aspect ratio
        jsr     gw_pscal(pc)    push the window size and scale
        lea     main,a3         the main interpreter block
        bsr.s   abexb           -, -, -, -, px', py'
        lea     px(a4),a1       point to the answers: px', py'
        subq.l  #main-nint,a3   the little interpreter block
        bsr.s   abexb
        move.w  (a1)+,d1        x = int(px)
        bsr.s   abexb
        move.w  (a1)+,d2        y = int(py)
        bset    #sd..gchr,sd_cattr(a0) set graphics positioned char flag
        jmp     sd_setc(pc)     set the text cursor

abexb
        jmp     ri_abexb(pc)

nint
 dc.b ri.nint,ri.term
main
* scale, height-1, aspect, yorg, xorg, gx, gy, px, py
 dc.b ri.over,ri.swap,ri.div            (height-1)/scale
* (height-1)/scale, height-1, aspect, yorg, xorg, gx, gy, px, py
 dc.b yorg,gy,ri.sub,ri.over,ri.mult
 dc.b ri.roll,ri.add                    y' = (height-1)*(1-(y-yorg)/scale)
* y', (height-1)/scale, aspect, -, xorg, gx, -, px, py
 dc.b py,ri.add,ri.store+yorg           t = py + y'
* (height-1)/scale, aspect, py', xorg, gx, -, px, py
 dc.b gx,xorg,ri.sub,ri.mult,ri.mult    x' = (x-xorg)*aspect*(height-1)/scale
* x', py', -, -, -, px, py
 dc.b px,ri.add,ri.store+px             px' = px + x'
* py', -, -, -, px', py
 dc.b ri.store+py                       py' = t
* -, -, -, -, px', py'
 dc.b ri.term

* N.B. The above is all arranged so that errors in scaling the graphics
* coordinates will effectively result in px, py being unchanged.

        end
