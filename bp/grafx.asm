* Basic graphics commands
        xdef    bp_arc,bp_arcr,bp_circe,bp_circr,bp_ellie,bp_ellir,bp_gcur
        xdef    bp_line,bp_liner,bp_poinr,bp_point,bp_scale

        xref    bp_chan,bp_gsep
        xref    bv_chrix
        xref    ca_cnvrt,ca_etos,ca_gtfp
        xref    ri_execb,ri_one,ri_roll,ri_swap,ri_zero

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_choff'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_ri'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_token'

        section bp_grafx

etc_1
        add.b   #sd.point,d7    make up the genuine trap code (bits 6..0)
        ror.w   #8,d7           hide in msb, also lastsep = none
        sf      d5              nextsep = none
        move.l  a5,d6           save a5 (smashed by get_fp)
        moveq   #15,d0
        and.b   1(a6,a3.l),d0
        bne.s   notnull         if first param is null then
        jsr     bp_gsep(pc)     skip it, getting separator
        move.b  d5,d7           lastsep = nextsep
        bra.s   nohash          else

notnull
        tst.b   1(a6,a3.l)
        bpl.s   nohash          if there's a hash then
        move.b  1(a6,a3.l),d7   get the separator first
        add.b   d7,d7           only without the hash flag
        lsr.b   #5,d7           and in the right place, too
nohash
        jsr     bp_chan(pc)     get the channel number
        lea     ch.lench(a2),a4 for execution blocks
        move.l  (sp)+,a2        save our return address for looping
        bne.s   rts0            propagate any error
        moveq   #127,d1
        add.w   d1,d1
        jsr     bv_chrix(pc)    allocate some space on the stack (too much?)
        move.l  bv_rip(a6),d4
        sub.l   bv_ribas(a6),d4 save original bv_rip offset
go_loop
        move.l  d4,a1
        add.l   bv_ribas(a6),a1 set pointer to original bv_rip
        move.l  a1,bv_rip(a6)
        jmp     (a2)
        
bp_gcur
        addq.b  #sd.gcur-sd.point,d7 set graphics position
        bsr.s   etc
        jsr     ca_gtfp(pc)     absorb all the parameters
        bne.s   rts0
        move.l  a3,d6           say we've taken them all
* A bug in JS means that people had to call CURSOR with exactly four parameters
* to get here. If there was a #channel at the front, they could only give three
* of the required four parameters and had to hope that the RI stack happened
* to have a zero next! However, in true JS fashion, this seems to have been the
* case... so to cope with people wangling their way around the JS bug, the
* correct check for exactly four parameters has been replaced with this check
* that at least validates there to be no more than four parameters:
        subq.w  #4,d3           did we get just four? (or JS bug three)
        bhi.s   err_bp          nope - that's not our problem
dotrap
        move.w  d7,d0           move trap vector into d0
        ror.w   #8,d0           get it into ls byte
        moveq   #-1,d3
        trap    #4
        trap    #3              draw the figure
loop
        move.b  d5,d7           lastsep = nextsep
        cmp.l   d6,a3
        blt.s   go_loop         if params left then loop
rts0
        rts

bp_scale
        addq.b  #sd.scale-sd.point,d7
        bsr.s   etc     scale (ch#,)
        bsr.s   get2fp          s,x,
        bra.s   g1dotrap                y

etc
        cmp.l   a5,a3
        blt.s   etc_1           continue if there is at least one parameter
        addq.l  #4,sp           drop return address
err_bp
        moveq   #err.bp,d0
        rts

bp_poinr
        tas     d7
bp_point
        bsr.s   etc     point (ch#,)
        bra.s   gcdotrap        x,y

bp_liner
        tas     d7
bp_line
        addq.b  #sd.line-sd.point,d7
        bsr.s   etc     line (ch#,)
        bsr.s   chkto
        beq.s   loop            either: x,y (don't plot)
gcdotrap
        bsr.s   getcords
        bra.s   dotrap          or:     TO x,y (plot)

bp_arcr
        tas     d7
bp_arc
        addq.b  #sd.arc-sd.point,d7
        bsr.s   etc             arc (ch#,)
        bsr.s   chkto                   TO (or) x,y,
        bsr.s   getcords                        x,y, then ang
g1dotrap
        bsr.s   get1fp
dotrap_1
        bra.s   dotrap

bp_circr
bp_ellir
        tas     d7
bp_circe
bp_ellie
        addq.b  #sd.elips-sd.point,d7
        bsr.s   etc             ellipse (ch#,)
        bsr.s   getcords                x,y,
        bsr.s   get1fp                          hgt
        cmp.b   #b.sepcom,d5
        bne.s   notcom
        bsr.s   get2fp                  if comma then:  ,ecc,rot
        bra.s   doswap

notcom
        jsr     ri_one(pc)              ecc=1 (a circle)
        jsr     ri_zero(pc)             rot=0
doswap
        jsr     ri_roll(pc)             x,y,hgt,ecc,rot -> x,y,ecc,rot,hgt
        jsr     ri_swap(pc)             x,y,ecc,rot,hgt -> x,y,ecc,hgt,rot
        bra.s   dotrap_1

get2fp
        bsr.s   get_fp          get floating point parameter
        bne.s   exit_fp
get1fp
        bsr.s   get_fp          get (another) floating point parameter
        bne.s   exit_fp
        rts

chkto
        cmp.b   #b.septo,d7
        bne.s   getcords        if lastsep <> 'TO' then getcoords
        moveq   #getblk-savblk,d0
        bsr.s   execb           else use ccp
        move.l  a1,bv_rip(a6)   update bv_rip, return 'TO' (z clear, as a1<>0)
        rts

getcords
        bsr.s   get_fp          get x coord
        bne.s   exit_fp
        bsr.s   get_fp          get y coord
        bne.s   exit_fp
        tst.w   d7
        bpl.s   execb
        moveq   #relblk-savblk,d0
execb
        move.l  a3,-(sp)
        lea     savblk(pc,d0.w),a3
        jsr     ri_execb(pc)
        move.l  (sp)+,a3
        rts                     return 'not TO' (assume no error)

get_fp
        cmp.l   d6,a3
        bge.l   err_bp          return bad parameter if no args left
        move.l  a4,-(sp)
        move.b  d5,d7           lastsep = nextsep
        jsr     bp_gsep(pc)     get next separator
        move.l  a3,a5
        jsr     ca_etos(pc)     evaluate parameter to top of stack
        bne.s   exit_fp
        moveq   #t.fp,d0
        jsr     ca_cnvrt(pc)    convert to floating point
exit_fp
        move.l  (sp)+,a4
        rts

ccpx    equ     ch.ccpx-ch.lench
ccpy    equ     ch.ccpy-ch.lench

relblk
 dc.b ri.swap,ccpx,ri.add,ri.swap       make relative x absolute
 dc.b ccpy,ri.add                       make relative y absolute
savblk
 dc.b ri.over,ri.store+ccpx             save ccpx
 dc.b ri.dup,ri.store+ccpy,ri.term      save ccpy

getblk
 dc.b ccpx,ccpy,ri.term                 get ccpx, ccpy

        end
