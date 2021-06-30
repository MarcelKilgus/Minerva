* Basic turtle graphics commands
        xdef    bp_move,bp_pendn,bp_penup,bp_turn,bp_turno

        xref    bp_chan
        xref    bv_chri
        xref    ca_gtfp1
        xref    ri_execb

        include 'dev7_m_inc_choff'
        include 'dev7_m_inc_ri'
        include 'dev7_m_inc_sd'
        include 'dev7_m_inc_assert'

        section bp_turtl

bp_move
        moveq   #moveblk-turnblk,d7
bp_turn
        subq.w  #trntoblk-turnblk,d7
bp_turno
        jsr     bv_chri(pc)     allocate some space on the stack
        jsr     bp_chan(pc)     get channel number, if any
        bne.s   rts0            propagate any error
        jsr     ca_gtfp1(pc)    get a single floating point parameter
        bne.s   rts0            propagate any error
        lea     trntoblk(pc,d7.w),a3 point to interpreter block
        lea     ch.lench(a2),a4 top of channel definition
        jsr     ri_execb(pc)    execute block
        bne.s   rts0            get out on errors
        tst.w   d7
        ble.s   rts0            only move has anything more to do
        tst.b   ch.pen(a6,a2.l)
        beq.s   rts0            if the pen is up then we're done
        moveq   #sd.line,d0     line ccpx, ccpy, x2, y2
        moveq   #-1,d3
        trap    #4
        trap    #3
rts0
        rts

bp_pendn ; pen = 1
        addq.b  #1,d7
bp_penup ; pen = 0
        jsr     bp_chan(pc)     get channel number, if any
        bne.s   rts0            propagate any error
        move.b  d7,ch.pen(a6,a2.l) set pen status
        rts

ccpy    equ     ch.ccpy-ch.lench
ccpx    equ     ch.ccpx-ch.lench
angle   equ     ch.angle-ch.lench

turnblk ; stack: rel angle
 dc.b angle,ri.add
trntoblk ; stack: abs angle
 dc.b ri.n,90,ri.doubl,ri.doubl         360, ang
 dc.b ri.over,ri.over,ri.div,ri.int     int(ang/360), 360, ang
 dc.b ri.float,ri.mult,ri.sub           ang - 360*float(int(ang/360))
 dc.b angle+ri.store,ri.term            store it away (always 0..360)

        assert  0 > turnblk-trntoblk

moveblk ; stack: distance (d)
 dc.b ccpx,ccpy,ri.roll                 d, ccpy, ccpx
 dc.b angle,ri.k,ri.pi180,ri.mult       a, d, ccpy, ccpx
 dc.b ri.over,ri.over,ri.cos,ri.mult    cos(a)*d, a, d, ccpy, ccpx
 dc.b ccpx,ri.add,ri.dup,ccpx+ri.store  ccpx'(saved), a, d, cpy, ccpx
 dc.b ri.roll,ri.roll,ri.sin,ri.mult    sin(a)*d, ccpx', ccpy, ccpx
 dc.b ccpy,ri.add,ri.dup,ccpy+ri.store  ccpy'(saved), ccpx', ccpy, ccpx
 dc.b ri.term                           ccpy', ccpx', ccpy, ccpx

        assert  0 < moveblk-trntoblk

        end
