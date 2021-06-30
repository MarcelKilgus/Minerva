* MultiBasic executeable serial image (for pipep device)
        xdef    tb_multi,tb_multx

ut.con  equ     $c6     open a console
cn.itod equ     $f2     convert integer to decimal string
sb.start equ    $154    vectored entrypoint to start up an interpreter

mt.inf  equ     0       get system information
mt.frjob equ    5       force remove a job

io.open equ     1       open trap #2 code

io.share equ    1       shared input

sv_progd equ    $ac     prog_use default prefix

file    equ     '>'     delimiter at end of command file name
rom     equ     '!'     marker at end of string for forcing original rom names

tables  equ     $18     we'll have our tables at this offset

area    equ     $d00    we can go with just 384, but this is more sensible!

* With a bit of luck:

* Use qx or ex to pass channels and/or command string.
* If the last character of the command string is the "ROM" marker, it is
* removed from the string and the interpretter will start up with only the
* original ROM names, instead of inherited names. 
* The remaining command string is then scanned for the "file" marker, and if
* it's got it, the first part is opened as an input command channel, and the
* rest is shuffled down.
* The command string, what's left of it, becomes CMD$ in the interpreted basic.

* Channels passed:

*       none:   If no file marker in the comman string, a standard set of
*               windows is opened for #0, #1 and #2.

*       one:    Slotted in as both #0 and #1

*       two:    Become #0 and #1

*       more:   First two become #0 and #1, #2 is missed out, and the rest go
*               in as channels #3 onward.

* E.g. a filter to change replace strings in a file:

*       AUTO
*       i%='/'INSTR CMD$:a$='':if i%:a$=CMD$(i%+1to):CMD$=CMD$(to i%-1)
*       l%=LEN(CMD$)
*       REP lp1
*        IF EOF(#0):EXIT lp1
*        INPUT#3;i$:IF l%
*         REP lp2:i%=CMD$INSTR i$:IF i%: ...
*               ... PRINT i$(to i%-1);a$;:i$=i$(i%+l%to):ELSE EXIT lp2
*         ENDIF:PRINT i$:ENDREP lp1

* With the above as "subs" and this program as "multi", both in the program
* default directory, use:
*       EX multi,infile,outfile;'subs>fred/jim'
* Then all occurrances of "fred" in the source file "infile" will be replaced,
* creating the new file in "outfile", where these files are in the default data
* directory.

* A further tweak is permitted: we may even tell the new interpreter to use a
* specified set of m/c names by giving it a positive value in register a1.
* This option is just a bit wierd and we don't support it at the moment.

* We have to be able to find the tables in an interpretted job, other than job
* zero, so we've invented a system:
*       Word two must have the offset of the tables in it.

* Note: MultiBasics cannot be re-activated, the vector entry sorts this out.

* If no channels or command string at all are passed in, we do a default case
* which is marginally more friendly than always getting the default windows.
* We construct a single window in one of several screen positions dependant on
* the job number. This is made to become both channels #0 and #1.
* The windows are small, but just about give you enough to work with.
* They are such that they do not overlap one another, and they all fit inside
* the TV default channel #1/#2 area; convenient for an unexpanded m/c.
* We let them have an extra pixel row and column versus the exact character
* grid, as this means normal characters do not ever touch the borders.
* With the above constraints, 2*n windows are what we go for; two across, and n
* down the screen.

n       equ     3               windows down the screen (1..15 will work)
* the way thing go, changing n to 1, 2, 3, 4, 6, 8 and 15 windows will give 19,
* 9, 6, 4, 3, 2 and one lines for each window respectively.

* Notes on "hotkey"'ing programs....
* When a program is hotkey'ed, what happens is that the program code is stored
* in a RESPR or common heap area, then when it is required to execute, an
* appropriate area is acquired in the transient area, a long jump to the start
* of the program code is stored taking 6 bytes. This is followed by the job
* name, prefixed by its length, and possible a padding byte to get on an even
* boundary. The remaining transient area is a data area as demanded by the job.
* This code is then initiated in a standard fashion, so that a6 will be a
* pointer to long jump and a4/a5 are the offsets to the bottom/top of the data
* area. The program counter starts at a6, but then immediately jumps off into
* the code stored in the common heap or resident area.
* This code here is very careful not to confuse the meaning of a6 and pc,
* which will differ for shared code as above.

* One warning... to avoid getting really terribly clever, and to make the
* offset from job start to a6 into a neat $80, this code is rather locked into
* not having too long a start job name. Don't use the very clever Qpac2 idea of
* supplying a new job name, unless it's less than 12 chars long!
* You can patch the inbuilt job name to anything between 0 and 4 characters.

        section tb_multi

        ds.b    1               padding
tb_multi
        dc.b    -1              serial channel $ff prefix
        dc.l    tb_multx-multi  length of code
        dc.b    0               access code (unused)
        dc.b    1               executeable
        dc.l    base+area-tb_multx data space
        dc.l    0               extra

multi
        moveq   #mt.inf,d0      get our job number
        trap    #1
        bra.s   base            go start setting up
        dc.w    $4afb,nmex-name
name
        dc.b    'SB.' we append our job number to this
nmex    ds.b    0
        ds.w    0

base
        move.l  sv_progd(a0),a3 we may like to use the prog_use prefix
        moveq   #0,d6
        move.w  d1,d6           we'll use this in case we default setup
        divu    #2*n,d6         job mod possible default windows
        swap    d6
        move.w  #name-multi,a0
        add.w   -2(a6,a0.l),a0
        move.w  #tables-2,a1    we will overwrite our code
        move.w  cn.itod,a2
        move.w  d1,0(a6,a1.l)
* NB. This had better be >= multi+tables now!
        jsr     (a2)            extend job name with job number
        add.w   d1,name-2-multi(a6) a little used fact: d1 returns char count!
        move.l  a1,(a6)         put table offset at start of job + 2

        add.l   a1,a6           push on past base of our transient area
        sub.l   a1,a5           discount it from the data area

        tst.l   (sp)            have we been given anything at all?
        bne.s   useit           yes - they've got TK2 or somesuch

* Zilch being passed in, so let's be nice, and give them some defaults

        moveq   #32,d1
        lsr.w   #1,d6
        bcc.s   xset
        lsl.w   #3,d1 32<<3=256 x position 32(even)/256(odd)
xset
h       equ     (200/n-3)/10*10+3 height of windows, including border
g       equ     (202-h*n)/(n+1) gaps between windows
        mulu    #h+g,d6
        add.w   #16+(200-h*n-g*(n-1))/2,d6 top window y position
        move.w  d6,(sp)         set y
        move.w  d1,-(sp)        set x
        move.l  #222<<16!h,-(sp) set width and height
        move.l  #$ff010207,-(sp) set border colour/width, paper and ink
        move.l  sp,a1
        move.w  ut.con,a2
        jsr     (a2)
        bne.s   err
        addq.l  #8,sp
        move.l  a0,(sp)
        move.w  #1,-(sp)
        bra.s   nochan

useit
        move.l  sp,a4
        moveq   #0,d4
        move.w  (a4)+,d4        pick up channel count
        lsl.l   #2,d4
        add.l   d4,a4           move on past them
        move.l  a4,a2           remember start of command string
        move.w  (a4)+,d4        get command string length
        cmp.b   #rom,-1(a4,d4.w) are we being asked not to do rom names?
        seq     d5
        ext.w   d5
        add.w   d5,d4           no - set a zero
        move.w  d4,(a2)         yes - lose the byte and leave a minus one
sclp
        subq.w  #1,d4
        bcs.s   nochan          didn't find our file marker
        cmp.b   #file,(a4)+     is this our file marker?
        bne.s   sclp            no - keep looking

* File marker found, d4 has remaining string length

        sub.w   d4,(a2)         the filename length plus the file marker
        subq.w  #1,(a2)         so this is the filename length
        move.l  a2,a0           set filename start
        bsr.s   open            try to open plain name
        beq.s   gotit           if ok, go use it
        move.l  a6,a0           fill it in down where out tables will go
        moveq   #127,d2         silly upper limit on file name
        move.w  d2,(a0)+        first put in the limit value
        bsr.s   concat          start with the default prefix
* Upper limit on file name is really (*-base-2), but that's more than 127!
        move.l  a2,a3
        bsr.s   concat          then add the plain name
        move.l  a6,a0
        sub.w   d2,(a0)         this is now the concatenated name length
        bsr.s   open            try to open prefixed name
        bne.s   err             no good, so we'll have to die!
gotit
        move.w  d4,(a2)+        cut string length back to what's left
shlp
        subq.b  #1,d4
        bcs.s   basic
        move.b  (a4)+,(a2)+     copy remaining command string down
        bra.s   shlp

nochan
        sub.l   a0,a0           no command channel
basic
        move.w  d5,a1           set inherit(0) or rom(-ve) names
        move.w  sb.start,a2     get entry vector
        jmp     $4000(a2)       a0/a5-a7 are set, so run off to basic!

open
        moveq   #-1,d1          we'll own it
        moveq   #io.open,d0
        moveq   #io.share,d3
        trap    #2
        move.l  d0,d3           was the file opened ok?
        rts

concat
        move.w  (a3)+,d0        get length
        sub.w   d0,d2
        bge.s   ccent
err
        moveq   #-1,d1          ourself
        moveq   #mt.frjob,d0    force remove job
        trap    #1

pcopy
        move.b  (a3)+,(a0)+
ccent
        dbra    d0,pcopy
        rts
tb_multx

        end
