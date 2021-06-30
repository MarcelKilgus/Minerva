* Common routine to draw graphics figures
        xdef    gw_asp,gw_fig,gw_pscal,gw_psorg

        xref    gw_pitt,gw_pixad,gw_pixel,gw_trans
        xref    ri_abex,ri_abexb

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_gw'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_ri'
        include 'dev7_m_inc_sd'
 
* This code is entered with d0 and a1 as follows:
*             (a1) stack: top (low address),   ...,   bottom (high address)
* sd.point                                                      y,        x
* sd.line                        y finish,     x finish,  y start,  x start
* sd.arc      subtended angle,   y finish,     x finish,  y start,  x start
* sd.elips     rotation angle, minor axis, eccentricity, y centre, x centre

        assert  sd.point,sd.line-1,sd.arc-2,sd.elips-3

        offset  -17*6
alpha   ds.w    3       coefficient of x^2
beta    ds.w    3       coefficient of y^2
gamma   ds.w    3       coefficient of x*y
u       ds.w    3       coefficient of y
v       ds.w    3       coefficient of x

asp     ds.w    3       aspect ratio
masp    ds.w    3       aspect ratio, divided by two if mode 8
sc      ds.w    3       scale / (height - 1)
h1      ds.w    3       screen height - 1
yo      ds.w    3       y origin
xo      ds.w    3       x origin

base

sa      ds.w    3       sine(angle)
ca      ds.w    3       cosine(angle)

ax      ds.w    3       axis of ellipse, normally minor with eccentricity >= 1
ec      ds.w    3       eccentricity of ellipse, normally greater than one

        offset  ca
a       ds.w    3       angle
yf      ds.w    3       finish point y-coord
xf      ds.w    3       finish point x-coord
ys      ds.w    3       start point y-coord
xs      ds.w    3       start point x-coord

        assert  0,*

        section gw_fig

gw_fig
        link    a6,#lnk         make data frame
        movem.l sav,-(sp)       save required registers at base of frame
        lea     menu-sd.point(pc,d0.w),a5
        move.b  (a5),d0         pick up pointer byte
        add.w   d0,a5           point to menu list for operation
        move.b  (a5)+,d0        pick up byte that says how many bytes at a1
        lea     0(a1,d0.w),a4   point a4 to base of stack
        move.b  (a5)+,d0        pick up first proc type byte
        moveq   #8,d7           start octant count register (ok for elipse)
        jsr     prep(pc,d0.w)   go to first section of code for operation
        move.l  a4,a1           just in case caller would like it reset
        moveq   #0,d0           always return ok, even if we drew nothing
        movem.l (sp)+,sav       restore a few registers
        unlk    a6              release the data frame
        rts

menu dc.b men_p-*,men_l-*-1,men_a-*-2,men_e-*-3

men_p dc.b -ys,pre_p-prep,sca_p-m,pro_p-proc point
men_l dc.b -yf,pre_l-prep,sca_p-m,pro_l-proc,swa_p-m,sca_p-m,$ec line
men_a dc.b -a,pre_a-prep,octs_a-m,sincos-m,sca_p-m,pro_a-proc
        dc.b swa_p-m,sca_p-m,calc_a-m,opt_x-m,$dc arc
men_e dc.b -a,pre_e-prep,sincos-m,sca_e-m,pro_e-proc
        dc.b calc_e-m,opt_x-m,$3d ellipse
 ds.w 0 note: the type byte need no longer be so obscure.

gw_psorg
        assert  6,sd_xorg-sd_yorg
        move.l  sd_yorg+8(a0),-(a1)
        move.l  sd_yorg+4(a0),-(a1)
        move.l  sd_yorg+0(a0),-(a1)
        rts

gw_pscal
        move.w  sd_ysize(a0),-(a1)
        subq.w  #1,(a1)
        moveq   #ri.float,d0
        jsr     ri_abex(pc)
        move.l  sd_scal+2(a0),-(a1)
        move.w  sd_scal(a0),-(a1)
        rts

* Push screen aspect ratio onto stack
gw_asp
; if ntsc
;       move.l  #$6623b79c,-(a1) 2/(4/3*575/512*51.2/51.95) * 1.173
;       move.w  #$801,-(a1)
; else
*        move.l  #$56b851ec,-(a1) 2 / ( (4/3) * (575/512) * (51.2/51.95) )
*        move.w  #$801,-(a1)      (acually rounded(?) to 1.355)
* The aspect ratio, according to the above, should have been pushing
* $56bbe1ba onto the stack! as we can multiply/divide quicker (now) if the
* least significant half of the mantissa is zero (and keeping as close, one
* part in 32647, to the wrong value, but on the right side of it) ...
        clr.w   -(a1)
        move.l  #$80156b9,-(a1)  2 / ( (4/3) * (575/512) * (51.2/51.95) )
; endif
        rts

prep

pre_e
        bsr.s   abexm           go convert angle to sine/cosine
        moveq   #ord_e-m,d0
        cmp.w   #$801,ec(a4)    we want major >= minor ...
        bcc.s   eccok           ... so if eccentricity is less than 1.0 ...
        moveq   #inv_e-m,d0     ... first rotate by pi/2 and flip eccentricity
eccok
        bsr.s   abexn           do eccentricity calcs
        bra.s   setoct

pre_a
        bsr.s   abexm           get octants (also halves the angle)
        and.w   (a1),d7         check if int(angle/(pi/4)) bit 3 is set
        beq.s   noflip          not set, it's ok (this works for big angles!)
        not.w   (a1)            if set, invert it all (gets -ve ok)
noflip
        move.w  (a1)+,d7        found number of octants in subtended angle
* This only needs to be a low estimate, as the algorithm understands that arcs
* are a pain, and it will let them search on for a bit to find their end point.
        bsr.s   abexm           convert angle to sine/cosine

pre_l
        and.b   #7,d7           line -> 0, arc -> 0..7

setoct
        move.b  d7,octs(a6)     set the octant count
pre_p

        lea     base(a4),a1     put a1 at standard position
        bsr.s   gw_psorg        copy origins to stack
        bsr.s   gw_pscal        copy scale data to stack
        moveq   #setsc-m,d0     adjust the scale stuff
        bsr.s   abexn

* Set up miscellaneous bits of the frame data

        btst    #sd..xor,sd_cattr(a0)
        sne     over(a6)        flag $ff = "over -1"
        move.b  sd_fmod(a0),fmod(a6) flag <>0 = "fill 1"

        assert  sd_xmin,sd_ymin-2,sd_xsize-4,sd_ysize-6
        assert  xmin,ymin-2,xsize-4,ysize-6
        movem.l sd_xmin(a0),d0-d1
        movem.l d0-d1,xmin(a6)  window top left corner and size

* Set up stuff that's dependent on the current screen mode

        moveq   #mt.dmode,d0
        moveq   #-1,d1
        moveq   #-1,d2
        trap    #1
        asr.b   #4,d1           shift bit 3 into x. x = 0/1, mode 512/256
        subx.w  d0,d0
        bsr.s   gw_asp          put on a copy of the aspect ratio for scaling
        add.w   d0,(a1)         divide scale by factor of two if mode 256
        bsr.s   gw_asp          put on aspect ratio
        neg.w   d0
        addq.w  #1,d0         
        move.w  d0,xinc(a6)     2 for mode 256 or 1 for mode 512

        bsr.s   abexm           scale the start point input params
        lea     x0(a6),a2       where to put start point
        bsr.s   xyext           pick off and adjust start point
        move.b  (a5)+,d0
        jmp     proc(pc,d0.w)   jump to what to do next

abexm
        move.b  (a5)+,d0        use next menu byte to decide what calcs to do
abexn
        ext.w   d0
        beq.s   rts0            dummy entries have d0=0 at this point
        lea     m,a3
        add.w   d0,a3
        jsr     ri_abexb(pc)
        beq.s   rts0
        addq.l  #4,sp           don't accept errors, draw nothing
rts0
        rts

xyext
        move.l  (a1)+,d1        get x/y (doubled)
        asr.w   #1,d1           make y proper, propagating sign
        subx.w  d2,d2           carry = rounding
        sub.w   d2,d1           do y rounding
        swap    d1              put y in msw for now
        move.w  xinc(a6),d0     get x-increment, 1/2
        asr.w   d0,d1           make x near proper, propagating sign
        subx.w  d2,d2           carry = rounding
        sub.w   d2,d1           do x rounding
        subq.w  #1,d0           change shift to 0/1
        lsl.w   d0,d1           put x to final place (lsb=0 for mode 8)
        swap    d1              swap back to right way round
        move.l  d1,(a2)+        store x/y
        rts

proc

* sd.point: call just the bits we need, and forget all the dross.

pro_p
        movem.w x0(a6),d0-d1
        jsr     gw_pixad(pc)
        jmp     gw_pixel(pc)

* Process the ellipse
pro_e
        move.l  d1,(a2)+        repeat start point as end point
        cmp.w   #$800,ax(a4)    is the narrow bit less than one pixel?
        bcs.s   rts0            yes - we'll not bother to draw anything!
* There is the idea of drawing two shallow arcs, but I don't know (lwr)...
* However, eventually it would be a good idea to break an ellipse into
* sections, anyway, so we can draw huge ones without wandering miles offscreen
* in the process.
allset
        bsr.s   abexm           do the main calculations
        bsr.s   abexm           produce the rounding factor
        bra.s   abguv

* sd.line: simple one
pro_l
        bsr.s   abexm           swap in end point
        bsr.s   abexm           process end point
        bsr.s   xyext           fetch end point
        moveq   #0,d2           alpha = 0
        moveq   #0,d3           beta = 0
        moveq   #0,d4           gamma = 0
        assert  x0,y0-2,x1-4,y1-6
        movem.w x0(a6),d0-d1/d6-d7 get start and end points (sign extended)
        sub.l   d0,d6
        cmp.b   #2,xinc+1(a6)   mode 512?
        beq.s   uset            (note: 512 mode start/end x already even)
        add.l   d6,d6           u = delta x * 2 / mode
uset
        sub.l   d1,d7
        add.l   d7,d7           v = delta y * 2
        bra.s   trans           go do it!

* Process an arc
pro_a
        bsr.s   abexm           swap in end point
        bsr.s   abexm           process end point
        bsr.s   xyext           fetch end point
        movem.w x0(a6),d0-d4    pick up start and end points
        sub.l   d0,d2           x1 - x0
        sub.l   d1,d3           y1 - y0
        movem.l d2-d3,-(a1)     put them on the stack
        bra.s   allset

* We wish to arrange for the values used in squch and diach to have as many
* significant bits as we can, to keep accuracy.
* Also, in order to have no rounding errors, the values we set up need alpha
* and beta multiples of four and gamma, u and v even.

* Further to the above, the following are the worst case values that we will
* need to cope with signed arithmetic on:

*       alpha + beta + 2*gamma
*       alpha/2 + gamma/2 + u + v
*       beta/2 + gamma/2 + u + v
*       alpha/4 + u/2 + beta/2 + gamma/2 + v
*       beta/4 + v/2 + alpha/2 + gamma/2 + u

* We actually know that alpha, beta and gamma are less than one, except for
* an arc, when alpha and beta are less than two, but gamma is zero.
* The main interest is the values of u and v. If these are less than one, we've
* got a pretty degenerate figure to draw!

* Finally, when the ellipse was set up, it tried to arrange itself a start
* point on the minor axis. However, aspect ratio scaling will disturb this,
* meaning we need an extra guard bit to stop the algorithm screwing up.

* We have already arranged the top of the arithmetic stack to contain:

* abs(u')+abs(v')+8,alpha/2,beta/2,gamma,u,v,...

abguv
        move.w  (a1),d5
        addq.l  #6,a1
        sub.w   #$800+27,d5     dividing power of two

        bsr.s   optim
        add.l   d7,d7
        move.l  d7,d2           alpha
        bsr.s   optim
        add.l   d7,d7
        move.l  d7,d3           beta
        bsr.s   optim
        move.l  d7,d4           gamma
        bsr.s   optim
        move.l  d7,d6           u
        bsr.s   optim           v

        movem.w x0(a6),d0-d1    put start coords them into their registers
trans
        move.b  (a5)+,type(a6)  finally set the call type: l=ec a=dc e=3d

* Now transform from coefficients to pitteway algorithm variables and set up
* the initial values. Also find the starting octant of the figure, the pixel
* address and masks, and rearrange the registers

        jsr     gw_trans(pc)

* Now the figure may be drawn. Call Pitteway!

        jmp     gw_pitt(pc)

optim
        sub.w   d5,(a1)         scale parameters to improve numerics
        bpl.s   goopt           are we getting a tiny value (too tiny!)
        clr.w   (a1)            yes, just zap exponent so nlint is happy
goopt
        moveq   #ri.nlint,d0
        jsr     ri_abex(pc)
        move.l  (a1)+,d7
        add.l   d7,d7           most want to be even
        rts

* Execution blocks for initial arc / elipse parameter arithmetic.

octs_a
* Note: for arc, we are only interested in the half angle.
* a*2, yf, xf, ys, xs
 dc.b ri.halve,ri.dup,ri.k,ri.pi-3,ri.div,ri.int,ri.term
* int(a*2/(pi/4)).w, a, yf, xf, ys, xs

        assert  a,ca,sa+6
sincos
* N.B. We've turned the y-axis upside down!
* a, ...
 dc.b ri.dup,ri.cos,ri.swap       ca = cosine(a)
 dc.b ri.sin,ri.neg,ri.term       sa = -sine(a)
* sa, ca, ...
 
inv_e
* -ca, sa, ax/ec, 1/ec, yc, xc
 dc.b ri.neg,ri.swap                    angle = angle' + pi/2
 dc.b ax,ec,ri.mult,ri.store+ax,ri.term ax = ax' * ec' = minor axis
* sa, ca, ax, -, yc, xc

ord_e
* sa, ca, ax, ec, yc, xc
 dc.b ec,ri.recip,ri.store+ec,ri.term   ec = 1/ec
* sa, ca, ax, -, yc, xc

* Execution blocks for scaling

setsc
* scale, h-1, yo, xo, asp, masp,...
 dc.b ri.over,ri.swap,ri.div,ri.term
* (h-1)/scale, h-1, yo, xo, asp, masp,...

* N.B. Note that both start and end point use the same calculation. This
* ensures that sequences of lines and arcs, where the end point of one is the
* start point of the next, will be guaranteed to come up with the same pixel.

sca_e
* ..., sa, ca, ax, -, yc, xc
 dc.b ax,sa,ri.mult,xs,ri.add,ri.store+xs       xs = xc + v
* ..., sa, ca, ax, ec, yc, xs
 dc.b ax,ca,ri.mult,ys,ri.add,ri.store+ys       ys = yc + u (later negation)
 dc.b ax,sc,ri.mult,ri.store+ax                 ax = ax*(h-1)/scale
sca_p
* ..., (h-1)/scale, h-1, yo, xo, asp, masp, ...
 dc.b yo,ys,ri.sub,sc,ri.mult
 dc.b h1,ri.add,ri.doubl,ri.int                 int(2*((y-yf)*(h-1)/scale+h-1))
 dc.b xs,xo,ri.sub,sc,ri.mult
 dc.b asp,ri.mult,ri.doubl,ri.int,ri.term       int(2*(x-xo)*(h-1)/scale*asp)
* int(x').w, int(y').w, ...

swa_p
 dc.b yf,ri.store+ys,xf,ri.store+xs replace start point with end point

m dc.b ri.term
* Execution blocks are referenced byte relative to m. An entry in the menu of
* zero will in fact skip doing any calculations at all. This is used so that we
* can break up the calcuations into convienient bits.

* Execution block for arc arithmetic
calc_a
* int(x1-x0).l, int(y1-y0).l, ...
 dc.b ri.flong,asp,ri.div,ri.store+xf re-incorporate aspect ratio with delta x
 dc.b ri.flong
* yf-ys, ... 
 dc.b ri.dup,ca,ri.mult         (yf - ys) * ca
 dc.b xf,sa,ri.mult             (xf - xs) * sa
 dc.b ri.sub,masp,ri.div                v = ((yf-ys) * ca - (xf-xs) * sa)/masp
 dc.b ri.swap,sa,ri.mult        (yf - ys) * sa
 dc.b xf,ca,ri.mult             (xf - xs) * ca
 dc.b ri.add                            u = (xf-xs) * ca + (yf-ys) * sa
* u, v, ...
 dc.b ri.zero                           gamma = 0
 dc.b sa,masp,ri.squar,ri.div           beta/2 = 2 * sa / 2 / masp^2
 dc.b sa,ri.term                        alpha/2 = 2 * sa / 2
* alpha/2, beta/2, gamma, u, v, ...

opt_x
* alpha/2, beta/2, gamma, u, v, ...
 dc.b u,ri.abs,v,ri.abs,ri.add,ri.n,8,ri.add    abs(u')+abs(v')+8 (for round)
* abs(u')+abs(v')+8, alpha/2, beta/2, gamma, u, v, ...
 dc.b ri.term

* Execution block for ellipse calculations (last, to give m more room)
calc_e
* ...
 dc.b ax,sa,ri.mult,masp,ri.div         v = ax * sa / masp
* v, ...
 dc.b ax,ca,ri.mult                     u = ax * ca
* u, v, ...
 dc.b ri.one,ec,ri.squar,ri.sub         ee = 1 - 1 / ec^2
* ee, u, v, ...
 dc.b ri.dup,sa,ri.mult
* ee*sa, ee, u, v, ...
 dc.b ri.dup,sa,ri.mult
* ee*sa^2, ee*sa, ee, u, v, ...
 dc.b ri.swap,ca,ri.mult,masp,ri.div    gamma = ee * sa * ca / masp
* gamma, ee*sa^2, ee, u, v, ...
 dc.b ri.one,ri.roll,ri.sub,ri.halve    alpha/2 = (1 - ee * sa^2) / 2
* (1-ee*sa^2)/2, gamma, ee, u, v, ...
 dc.b ri.roll,ri.halve,ri.one,ri.swap,ri.sub
* 1-ee/2, (1-ee*sa^2)/2, gamma, u, v, ...
 dc.b ri.over,ri.sub
* (1-ee*ca^2)/2, (1-ee*sa^2)/2, gamma, u, v, ...
 dc.b masp,ri.squar,ri.div              beta/2 = (1-ee*ca^2) / masp^2 / 2
* beta, alpha, gamma, u, v, ...
 dc.b ri.swap,ri.term
* alpha, beta, gamma, u, v, ...

        end
