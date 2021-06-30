* General basic window operations
        xdef    bp_at,bp_block,bp_bordr,bp_cls,bp_csize,bp_cursr
        xdef    bp_fill,bp_flash,bp_ink,bp_over,bp_pan,bp_paper,bp_recol
        xdef    bp_scrol,bp_strip,bp_under,bp_width,bp_windw

        xref    bp_chan,bp_gcur,bp_lsqzp
        xref    ca_gtint,ca_gtli1

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_choff'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sd'

        section bp_windw

* Colour parameter generator.
* Takes 1 to 3 items from stack and produces a byte containing colour
* information in the standard format. No return on error.

colour
        bsr.s   pickup          get final parameter
        move.w  d2,d1
        subq.w  #1,d3
        beq.s   chk_256         if one parameter then exit
        moveq   #8,d0
        cmp.w   d0,d1
        bcc.s   err_pop         error if not in 0..7
        moveq   #3<<3,d2        default stipple is three
        subq.w  #1,d3
        beq.s   col_2p          only two parameters
        lsl.w   #3,d1           last was actually stipple pattern, shift it
        bsr.s   pickup          get contrast colour
        bcc.s   err_pop         error if not in 0..7
        subq.w  #1,d3
        bne.s   err_pop         error if not 1..3 parameters
col_2p
        or.w    d2,d1           combine stipple and colour
        bsr.s   pickup          get background colour
        bcc.s   err_pop
        eor.w   d2,d1
        lsl.w   #3,d1
        or.w    d2,d1           bodge background in
chk_256
        cmp.w   #256,d1         check single parameter 0..255 or stipple 0..3
        bcs.s   rts0
err_pop
        moveq   #err.bp,d0
pop_ret
        addq.l  #4,sp
rts0
        rts

* BLOCK{#chan;}width,height,x,y{,<colour>}
bp_block
        moveq   #sd.fill-sd.bordr,d7     fill a block
* BORDER{#chan;}{border{,<colour>}}
bp_bordr
        subq.b  #sd.wdef-sd.bordr,d7 redefine a border only
* WINDOW{#chan;}width,height,x,y{,border{,<colour>}}
bp_windw
        bsr.s   iparm
        moveq   #0,d2           default width is zero
        moveq   #-128,d1        default colour is transparent (BLOCK=black)
        add.b   #sd.wdef,d7
        bcs.s   brdr
        subq.w  #4,d3
        beq.s   blk_mod
        assert  0,1-1&sd.wdef,1&sd.fill
        btst    d2,d7
        bne.s   brdr
        bsr.s   colour
        bra.s   blk_mod

brdr
        subq.w  #1,d3           correct range for colour parameters
        bcs.s   blk_mod         if no parameters, full default
        beq.s   bord_w          if no colour then 'transparent'
        bsr.s   colour          get colour
bord_w
        bsr.s   pickup          get width
blk_mod
        subq.l  #4*2,a1
        bra.s   trap4d7

pickup
        subq.l  #2,a1
        move.w  0(a6,a1.l),d2   get contrast/background colour
        cmp.w   d0,d2
        rts

* RECOL{#chan;}p0,p1,p2,p3,p4,p5,p6,p7 pn are replacement colours for colour n
bp_recol
        bsr.s   iparm
        subq.w  #8,d3           must have 8 parameters
        bne.s   err_bp
        move.l  a1,a2
        moveq   #8-1,d0
tr_loop
        subq.l  #2,a2
        subq.l  #1,a1
        move.b  1(a6,a2.l),0(a6,a1.l) compress words to bytes
        dbra    d0,tr_loop
        moveq   #sd.recol,d7
trap4d7
        trap    #4              it's rel a6 (all bar BORDER need this)
        bra.s   trap3d7

* WIDTH{#chan;}charsperline
bp_width
        bsr.s   iparm           get integer parameters
        subq.w  #1,d3           ... just one
        bne.s   err_bp
        move.w  d2,ch.width(a6,a2.l) set width
        rts

* PAPER{#chan;}<colour>
bp_paper
        subq.b  #sd.setin-sd.setpa,d7
* INK{#chan;}<colour>
bp_ink
        addq.b  #sd.setin-sd.setst,d7
* STRIP{#chan;}<colour>
bp_strip
        bsr.s   iparm
        bsr.l   colour          turn parameter(s) into colour
setxx
        moveq   #sd.setst,d0    if paper ...
        add.b   d0,d7
        bcc.s   trap3d7
        bsr.s   trap3d0         ... do strip first

* d0 -  o- error code (ccr not set)
* d1 -i o- as per trap action
* d2 -i o- as per trap action
* d3 -  o- -1
* d7 -ip - code for trap #3
* a0 -ip - qdos channel id
* a1 -i  - as per trap action

trap3d7
        move.b  d7,d0           set operation key
trap3d0
        moveq   #-1,d3          infinite timeout
        trap    #3              perform it
        rts

* d0 -  o- error code, with ccr set
* d1 -  o- last but one parameter
* d2 -  o- last parameter
* d3 -  o- number of parameters
* a0 -  o- qdos channel id
* a1 -  o- rel a6 pointer past last parameter
* a2 -  o- rel a6 pointer to channel table entry
* a3 -ip - start of nt entries for integer parameters
* a5 -ip - top of nt entries for integer parameters

iparm
        jsr     bp_chan(pc)     get channel to a0
        bne.s   popretne        error if it doesn't work
        jsr     ca_gtint(pc)    call parameter routine
popretne
        bne.l   pop_ret         error if anything fails
        add.l   d3,a1
        add.l   d3,a1           point past last parameter
        movem.w -4(a6,a1.l),d1-d2 pick up last two parameters
rts1
        rts

* OVER{#chan;}{flag} 0=ink on strip, 1=ink only, -1=ink xor (existing contents)
bp_over
        addq.b  #(sd.setmd-sd.setul)<<1!1,d7
* UNDER{#chan;}flag 0=off, 1=on.
bp_under
        addq.b  #(sd.setul-sd.setfl)<<1,d7
* FLASH{#chan;}flag 0=off, 1=on. ignored in 512 mode.
bp_flash
        addq.b  #(sd.setfl-sd.setst)<<1,d7
        bsr.s   iparm
        move.w  d3,d1
        beq.s   setxx
        subq.w  #1,d3
        bne.s   err_bp
        asr.b   #1,d7
        addx.b  d3,d3
        move.w  d2,d1
        add.w   d3,d2
        addq.w  #2,d3
        sub.w   d3,d2           error if not 0..1 or, for OVER, -1..1
        bcs.s   setxx
err_bp
        moveq   #err.bp,d0
        rts

* FILL{#chan;}parameter
bp_fill
        jsr     bp_chan(pc)     get channel number, if any
        bne.s   rts1
        jsr     ca_gtli1(pc)    get a single long integer to d1
        bne.s   rts1
        moveq   #sd.flood,d0
        bra.s   trap3d0         go do it

* CSIZE{#chan;}width,height width 0..3, height 0..1
* Note: in 256 mode width 0 or 1 will appear as 2 and 3 respectively
bp_csize
        moveq   #(sd.setsz-sd.pos)&255,d7
* AT{#chan;}row,column
bp_at
        subq.b  #(sd.pixp-sd.pos),d7
twopar
        bsr.s   iparm
        subq.w  #2,d3
err_nebp
        bne.s   err_bp          error if not two parameters
        add.b   #sd.pixp,d7     if it's AT ...
        bcc.s   trap3d7
        exg     d1,d2           ... definition is reversed
trap3d7a
        bra.s   trap3d7

* CURSOR{#chan;}{xgraph,ygraph,}xpixel,ypixel
bp_cursr
        lea     4*8(a3),a4      are there less than four params?
        cmp.l   a4,a5           (2 or 3 is what we're after)
        blt.s   twopar          yes - it must be plain pixel position 
        jmp     bp_gcur(pc)     no - go do graphics

* PAN{#chan;}distance{,screen section}
* SCROLL{#chan;}distance{,screen section}
* CLS{#chan;}{screen section}

* distance may be positive or negative
* screen section may be:-
* 0: whole screen (default)
* 1: top of window (not pan)
* 2: bottom of window (not pan)
* 3: cursor line (not scroll)
* 4: right hand end of cursor line (not scroll)

bp_cls
        moveq   #(sd.clear-sd.pan)<<1-1,d7
bp_pan
        addq.b  #(sd.pan-sd.scrol)<<1,d7
bp_scrol
        bsr.s   iparm           get distance to pan or scroll
        exg     d2,d0           get distance or part = last parameter (d2=0)
        sub.w   d3,a1
        sub.w   d3,a1           back up to start of parameters
        add.b   #sd.scrol<<1!1,d7
        lsr.b   #1,d7
        subx.w  d2,d3           insist on at least one parameter for pan/scroll
        bcs.s   err_nebp
        movem.w 0(a6,a1.l),d1/d2 pick up one or two parameters
        subq.w  #1,d3           check if optional part parameter was present
        bcs.s   chkls           ok if no option parameter
        add.b   d0,d7           add option to call byte
chkls
        jsr     bp_lsqzp(pc)    if this is the list window, zap list info
        bra.s   trap3d7a

        end
