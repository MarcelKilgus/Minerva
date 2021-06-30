* Read or set the display mode
        xdef    mt_dmode

        xref    ss_jobc,ss_noer
        xref    ip_dspm
        xref    sd_fresh

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'
        include 'dev7_m_inc_ra'
        include 'dev7_m_inc_mc'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_assert'

bs      equ     1<<mc..scrn
bm      equ     1<<mc..m256
bb      equ     1<<mc..blnk

        section mt_dmode

* This performs two disparate functions. The one sets either 256 or 512
* pixel mode. The other tells any software that is interested whether a
* monitor or tv is in use. In the latter case, a distinction between a
* 525 line and 625 TV is made. The initialisation code will select the
* correct sort of TV. Selecting 525 lines on a European ROM may not
* produce useful results. 

* The enhanced set of options now available needs to operate on up to six bits
* of information. These are the 4/8 colour and visible states of each of two
* screens (4 bits), which screen is currently displayed and which screen is
* the current default for this job. They may all be read, en mass, but there
* is a need to be able to selectively set them, which means 12+ bits!

* In order to maintain compatibility, even with people who send the wrong
* parameters, the new options have bits 7/6 of d1.b differring. Also for
* compatibility, old style calls clear the msbs of d1.l even though it is
* contrary to the documentation.

* The primary needs are to be able to change the default screen and make it
* blank or visible. Being able to force which screen is on display is rather
* undesirable for too many programs to try doing simultaneously!
* With these in mind, we define the options available from d1 bits as follows:

*       0       visible/blank on other screen
*       1       visible/blank on default screen mc..blnk
*       2       mode4/mode8 on other screen
*       3       mode4/mode8 on default screen   mc..m256
*       4       display scr0/scr1
*       5       default scr0/scr1 (n.b. takes effect before all other options)
*       6       clear - use d1.w. set - use d1.b (same as d1.w msb all ones).
*       7       opposite to bit six, i.e. 7/6 = 0/1 or 1/0 always
*       8-15    ignored if bit 6 set. otherwise ...
*       8-13    associated with bits 0-5 (clear=toggle, set=absolute)
*       14      clear - force redraw of other screen
*       15      clear - force redraw of default screen

* If bits 6 and "x" + 8 are clear, use bit "x" to force absolute selection.
* Otherwise, toggle settings as per bit "x". ("x" = 0..5)
* If bits 6 and "x" are clear, invoke that screen redraw. ("x" = 14..15)
* The original -1/0/8 options are equivalent to $40 (or -128), $7780 and $7788.

* The "default screen" is initially inherited from the parent job.
* It is the screen on which newly opened con/scr channels will appear.
* It is also the screen affected/reported on by d1.b = 0/8/-1.
* A change to this takes effect before the rest of the above is looked at.
* It then remains changed for the job, until the job does another change to it.

* The "mode4/mode8" selection in this extended system does not operate the
* same as the basic d1.b = 0/8 options. It only changes the physical display
* mode. Redrawing of the windows is independant. It is also not forced by d2.b
* being positive, except on d1 = 0/8/-1 calls.

* The "displayed screen" is the one currently on display.

* The system variable "sv_mcsta" records the selection that is on display.
* A new system extension variable, "sx_dspm", records what is really going on.
* It holds the following bits:

*       bit     0       1
*       0       visible blank   scr0
*       1       visible blank   scr1            mc..blnk
*       2       mode4   mode8   scr0
*       3       mode4   mode8   scr1            mc..m256
*       4                       reserved
*       5                       reserved
*       6                       will always be zero
*       7       scr0    scr1    display         mc..scrn

* The least significant bit of the jb_rela6 variable in a jobs header is where
* its "default screen" is recorded. 0=scr0, 1=scr1.

* The returned value in d1.b for the extended calls is as follows:

*       bit     0       1
*       0       visible blank   other
*       1       visible blank   default         mc..blnk
*       2       mode4   mode8   other
*       3       mode4   mode8   default         mc..m256
*       4       scr0    scr1    display
*       5       scr0    scr1    default
*       6                       ???
*       7       single  dual    available       mc..scrn

* d0 -  o- 0
* d1 -i o- mode key (-1 read, 0 set 512, 8 set 256)
* d2 -i o- tv key   (-1 read, 0 set monitor, 1 set tv/625, 2 set tv/525)
* a6 -ip - base of system variables

reg_on1 reg    d1-d2            put on after lsb's are set
reglist reg    d1-d5/a0-a5      restore most registers (even a4 now!)

mt_dmode
        movem.l reglist,-(sp)
        jsr     ip_dspm(pc)     leaves a4 pointing at sysvar extension
        movem.l (sp)+,reg_on1
        jsr     ss_jobc(pc)     find current job

        move.w  d1,d3           working copy of d1.w
        moveq   #64,d0          this will give the new equivalent of -1
        add.b   d1,d1           is it old style call?
        svs     d1              no - set mask as $ff ...
        bvs.s   d1new           ... and we are ready for next bit
        bcs.s   oldflag         carry means it was the -1 option
        moveq   #bm,d0
        and.b   d3,d0           keep old 0/8 bit
        add.w   #(255-bs-bm)<<8+128,d0 make new equivalent
oldflag
        move.w  d0,d3           use prepared equivalent call
        moveq   #bm,d1          clear msbs, for compatibility
;       addq.b  #bm,d1          only want to return the m256 bit
d1new
        moveq   #$3f,d4
        and.b   d3,d4           copy d1.b, but ensure 2 msb's are clear
        ror.w   #8,d3           fetch down d1.w (msb)
        bmi.s   setdef          if d1.b was negative, "default" is ready
        st      d3              set all the d1.w (msb)
setdef

* In the following, the bits floating about are labelled as follows:
* d - dual screens available
* j - job default screen
* c - currently displayed screen
*       redraw  mode8   blank
*       s       m       b       - screen 1
*       s       m       b       - screen 0
*       r       l       a       - job default screen
*       r       l       a       - job other screen

        moveq   #-1-$70,d5      1111111110001111
        and.b   sx_dspm(a4),d5  11111111c000mmbb
        bset    #0,jb_rela6(a3) test current job default screen and set scr1
        sne     d0              ????????jjjjjjjj remember old state
        and.b   d3,d0           keep "default" as per msb, then flip lsb...
        eor.b   d4,d0           ??????????j????? new default screen
        lsl.b   #3,d0           ?????????????000 carry set if scr1 is right
        bcs.s   jbd1            if it was one, skip swaps and flag clearing
        bclr    d0,jb_rela6(a3) job default screen is now scr0
        bsr.s   munge           go swap bits
jbd1
        moveq   #5,d0           j bit no
        bset    d0,d3           keep new j
        bclr    d0,d4           don't toggle new j
        add.w   d5,d5           111111jc000llaa0
        asl.b   #3,d5           111111jcllaa0000
        asr.w   #4,d5           1111111111jcllaa
        and.b   d3,d5           keep "default" as per msb, then flip lsb...
        eor.b   d4,d5           11111111rrjcllaa
        moveq   #-64,d4         1111111111000000
        or.b    d5,d4           1111111111jcllaa
        rol.w   #8,d4           11jcllaa11111111
        add.w   a6,d4           d1jcllaa11111111
        ror.w   #8,d4           11111111d1jcllaa

        tst.b   d2
        blt.s   no_tvchg        jump if no tv change.
        move.b  d2,sv_tvmod(a6) set tv mode system variable
        moveq   #$7f,d0         in case we want a redraw ...
        or.b    d1,d0           ... new style call will set d0.b = $ff
        and.b   d0,d5           argh, if old and d2.b >= 0, must force redraw
no_tvchg

        and.b   d4,d1           use mask old/extended return value
        move.b  sv_tvmod(a6),d2 pick tv mode back up
        movem.l reg_on1,-(sp)   d1.b and d2.b are now ready for return

        rol.b   #3,d5           11111111cllaarrj
        asr.b   #1,d5           11111111ccllaarr
        bcs.s   njd0            if j set, we have d5 right
        bsr.s   munge           11111110c0mmbbss
njd0
        move.l  #ra_bot,a5
        asr.b   #1,d5           1111111?cc?mmbbs
        bsr.s   redraw          check/do redraw of screen 0
        sub.w   #-ra_ssize,a5   point to base of second screen
        asr.b   #1,d5           ????????ccc?mmbb
        btst    #mc..scrn,d4    are there really two screens?
        beq.s   rddone          no - then we're done
        bsr.s   redraw          check/do redraw of screen 1
rddone
        moveq   #-1-$70,d0      1111111110001111
        and.b   d5,d0           ????????c000mmbb
        move.b  d0,sx_dspm(a4)  save new state
        bmi.s   isscr1
        add.b   d5,d5           ????????000mmbb0
isscr1
        bsr.s   setmc           set sv_mcsta
        move.b  d0,mc_stat      yipee! finally, we set the display hardware!

        movem.l (sp)+,reglist
        jmp     ss_noer(pc)

* This routine swaps bit pairs 5/4, 3/2 and 1/0 in d5. bits 8 and 6 are
* cleared and the rest (f-9 and 7) are copied unchanged. d0 is zapped.
* The comments show the original bit numbers, z=zero and w=one.
munge
        moveq   #$15,d0         zzzzzzzzzzzwzwzw
        and.b   d5,d0           zzzzzzzzzzz4z2z0
        add.b   d0,d0           zzzzzzzzzz4z2z0z
        asr.b   #1,d5           fedcba9877654321
        and.w   #$fe95,d5       fdecba9z7zz5z3z1
        or.b    d0,d5           fedcba9z7z452301
        rts

* check / redraw of a screen
redraw
        bcs.s   ret             if inhibit flag was set, no redraw wanted
        ; this bit is to see if it's nice to blank screen while redrawing
        ext.w   d5
        add.w   a5,d5
        bmi.s   noblnk          skip if not the visible screen
        move.b  #bb,mc_stat
noblnk
        ; end of that fringle. cost: 18 bytes
        bsr.s   setmc           set up for utilities being called
        jmp     sd_fresh(pc)    go do total redraw of a screen

* This sets the hardware bits in sv_mcsta as needed by other routines
setmc
        moveq   #bs+bm+bb-256,d0
        and.b   d5,d0
        moveq   #1<<1,d1
        and.b   sv_tvmod(a6),d1 treat tvmod bit 1 set as ntsc (2,3,6,7,...)
        lsl.b   #mc..ntsc-1,d1
        or.b    d1,d0
        move.b  d0,sv_mcsta(a6)
ret
        rts
        
        end
