* Trig, arithmetic and other functions
        xdef    bf_abs,bf_acot,bf_atan,bf_beepg,bf_chrs,bf_code,bf_deg,bf_dimn
        xdef    bf_eof,bf_fills,bf_inkes,bf_int,bf_len,bf_peek,bf_peekl
        xdef    bf_peekw,bf_pi,bf_rad,bf_respr,bf_rnd,bf_vers,bp_pause <-- N.B.
* N.B. Various other xdef/xref stuff set in macro below

        xref    ri_arg,ri_div,ri_fllin,ri_k_b,ri_mult,ri_one,ri_renrm
        xref    ri_sss,ri_swap
        xref    ca_gtfp,ca_gtfp1,ca_gtin1,ca_gtint,ca_gtli1,ca_gtst1
        xref    bv_chrix
        xref    bp_chand,bp_data,bp_pepo

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_ri'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'

bf_ri   macro
i       setnum  1
lp      maclab
t       setstr  [.parm([i])]
        xdef    bf_[t]
        xref    ri_[t]
bf_[t]  bsr.s   fn_trig
        dc.w    ri_[t]-*
i       setnum  [i]+1
        ifnum   [i] <= [.nparms] goto lp
        endm

        section bf_most

        bf_ri   sin,cos,tan,cot,asin,acos,exp,ln,log10,sqrt

bf_abs
        bsr.s   gtfp            get args
        jsr     ri_sss(pc)      rountine invented espesially for this
        bra.s   fp_put1

bf_pi
        cmp.l   a3,a5
        bne.s   err_bp0         should be no parameters for pi
        bsr.s   get_ri1         make space
        moveq   #ri.pi,d0
        bsr.s   do_trig
        dc.w    ri_k_b-*

err_bp0
        moveq   #err.bp,d0
        rts

bf_acot
        moveq   #-1,d7
bf_atan
        bsr.s   gtfp            get 1/2 args
        subq.w  #2,d3
        beq.s   arggo
        addq.w  #1,d3
        bne.s   err_bp0
        jsr     ri_one(pc)
arggo
        tst.l   d7
        bpl.s   istan
        jsr     ri_swap(pc)
istan
        bsr.s   do_trig
        dc.w    ri_arg-*

gtfp
        jsr     ca_gtfp(pc)     get all args as floating point
        bne.s   popifne
get_ri1
        bra.l   get_ri0         ensure we have space on stack

deg_rad
        jsr     ca_gtfp1(pc)    get just one argument
        bne.s   popifne
        bsr.s   get_ri1         and get just a little bit more space
        moveq   #ri.pi180,d0
        jsr     ri_k_b(pc)
        bra.s   do_trig

bf_deg
        bsr.s   deg_rad
        dc.w    ri_div-*        divide by pi/180

bf_rad
        bsr.s   deg_rad
        dc.w    ri_mult-*       multiply by pi/180

fn_trig
        jsr     ca_gtfp1(pc)    get one and only one fp arg
popifne
        bne.s   pop_4a
        bsr.s   get_ri1         make sure there's enough room
do_trig
        move.l  (sp)+,a4
        add.w   (a4),a4
        jsr     (a4)            do the trig function
fp_put1
        bra.s   fp_put0

* Random number generator

rndold
* old scheme when lsb of bv_rand is set. we use:
*       x'=a*x mod 2^32, a=89*2^2-1, period 2^30
        mulu    #355,d5
        mulu    #355,d6
        swap    d6
        clr.w   d6
        bra.s   rndadd

bf_rnd
        move.l  bv_rand(a6),d5  get random number
        move.l  d5,d6           save it
        swap    d6
        btst    d7,d5
        bne.s   rndold
* new scheme when lsb of bv_rand is clear. with x=bv_rnd/2, we use:
*       x'=a*x+b mod 2^31 a=2^16+1 b=12517 period 2^31
* the funny number for b is 32768*(3-sqrt(5))/2, which makes the lsw jump
* around in a fairly interesting way.
        move.w  #12517*2,d6
rndadd
        add.l   d6,d5           add together
        move.l  d5,bv_rand(a6)  ... save it
        jsr     ca_gtint(pc)    how many arguments?
        bne.s   rts2
        subq.w  #1,d3
        beq.s   rand_1          ... one
        bgt.s   rand_2          ... two
        bsr.s   get_ri1         none - make space for one argument
        move.l  d5,d1           and mantissa
        lsr.l   #1,d1           make positive
        move.w  #$0800,d0       set exponent
        bsr.s   do_trig
        dc.w    ri_renrm-*      return fp

rand_2
        subq.w  #1,d3
        bne.s   err_bp1
        move.w  0(a6,a1.l),d3   get base of range
        addq.l  #2,a1           lose extra integer on stack
rand_1
        move.w  0(a6,a1.l),d2   get top of range
        sub.w   d3,d2           less base
        blt.s   err_bp1         oops, no good if top<base
        addq.w  #1,d2           add one for total number of possible returns
        beq.s   rndtop          cope with range -32768to 32767!!!
        swap    d5              use most significant end
        mulu    d2,d5           multiply
rndtop
        swap    d5              result is in top half
        add.w   d3,d5           ... plus base
put_int
        move.w  d5,0(a6,a1.l)   set result
        moveq   #t.int,d4       result is integer
put_ok
        moveq   #0,d0           if here then good return
put_rip
        move.l  a1,bv_rip(a6)   all results on stack
rts2
        rts

* d0 -  o- 0 (no return on error)
* d1 -  o- long integer parameter
* d3 -  o- 0
* a1 -  o- bv_rip, parameter removed
* d2 destroyed

gtli1
        jsr     ca_gtli1(pc)    get a long integer (returned in d1)
        addq.l  #4,a1           remove from RI stack
        beq.s   rts2
pop_4a
        addq.l  #4,sp
        rts

bf_int
        bsr.s   gtli1           get as a long integer
pushlin0
        jsr     ri_fllin(pc)
fp_put0
        moveq   #t.fp,d4        result is floating point
        bra.s   put_rip

bf_peekl
        moveq   #%10111-1,d7    peek a longword
bf_peekw
        addq.b  #1,d7           peek a word
bf_peek
        jsr     bp_pepo(pc)     get address, same code as poke routines
        addq.l  #4,a1           adjust RI pointer
        beq.s   pkent           should be no params remaining
err_bp1
        moveq   #err.bp,d0
rts3
        rts

peeklp
        rol.l   #8,d5
pkent
        tst.b   d6
        bgt.s   absbn
        move.b  0(a6,a5.l),d5
        addq.l  #1,a5
        bra.s   gotbn

absbn
        move.b  (a5)+,d5        no address constraint
gotbn
        lsr.b   #1,d7           roll out a bit
        bcs.s   peeklp          loop while one bits come out
        beq.s   pushint0        if now zero, it wasn't peek_l
        move.l  d5,d1
        ext.l   d5
        cmp.l   d5,d1           does it fit in an integer?
        bne.s   pushlin0        no - make it into a float
        bra.s   pushint0

bf_respr
        bsr.s   gtli1           get space required into d1
        move.l  a1,a5
        moveq   #mt.alres,d0    allocate space in resident area (or chp!)
        trap    #1
        tst.l   d0
        bne.s   rts3
        move.l  a5,a1
reta0
        move.l  a0,d1
pushlin1
        bra.s   pushlin0

bf_beepg
        cmp.l   a3,a5
        bne.s   err_bp1         should be no parameters for beeping
        moveq   #mt.inf,d0
        trap    #1
        moveq   #1,d5           mask out all but lsb
        and.b   sv_sound(a0),d5 is it happenning?
gtpshint
        bsr.l   get_ri0         reserve space
pushint0
        subq.l  #2,a1
        bra.s   put_int

bf_eof
        cmp.l   a3,a5           is there a parameter?
        bne.s   eof_chan
        jsr     bp_data(pc)     no, so get next data item
        bra.s   set_eof

eof_chan
        bsr.s   chan            check for channel
        bne.s   rts3            error, return same
        moveq   #io.pend,d0     test channel
        clr.w   d3              immediate return
        trap    #3
set_eof
        clr.w   d5              set false
        moveq   #-err.ef,d4     check eof
        add.l   d0,d4
        subq.l  #1,d4           is it eof?
        addx.b  d5,d5           (only zero less one will set x)
        bra.s   gtpshint

bf_vers
        bsr.l   opt_int
        moveq   #mt.inf,d0
        trap    #1              get OS stuff
        addq.w  #2,d7
        beq.s   reta0           -2: system variables address
        bcs.s   pushlin1        -1: current job number
        subq.w  #2+1,d7
        bcs.s   vertop          0: normal version
        bne.s   err_bp2
        subq.l  #6,a1
        move.l  d2,2(a6,a1.l)   1: QDOS OS version
        moveq   #4,d4
        bra.s   len_put

chan
        moveq   #0,d1           default to command screen
        jmp     bp_chand(pc)    get #n

vertop
        moveq   #sx_basic,d7
        move.l  sv_chtop(a0),a0
        add.l   d7,a0
        move.w  (a0),d7
        bsr.s   room_str        get space, and verify length is sensible
        add.l   d1,a0
vercop
        subq.l  #2,a1
        move.w  -(a0),0(a6,a1.l) version letters
        subq.w  #2,d1
        bne.s   vercop
        bra.s   len_put

bp_pause ; sad, but there's no sensible way to avoid this misnomer-ish entry
        moveq   #-1,d7          infinite wait
bf_inkes
        bsr.s   chan            check for channel
        bne.s   noinkch         the channel's no good
        bsr.s   opt_int         get an optional integer
        move.w  d7,d3           set timeout
        move.l  a1,a4           save a1
        moveq   #io.fbyte,d0
        trap    #3
        move.l  a4,a1
        moveq   #0,d4           ready for null string
        addq.l  #-err.nc,d0
        beq.s   len_push        if not complete - return null string
        subq.l  #2,a1
        subq.l  #-err.nc,d0
gotchrs
        bne.s   noinkch
        move.b  d1,0(a6,a1.l)   set return character
        moveq   #1,d4           string length 1
len_push
        subq.l  #2,a1
len_put
        move.w  d4,0(a6,a1.l)   (re)place the length
        moveq   #t.str,d4       set type string
        bra.l   put_ok

noinkch
        tst.l   d7              0 = inkey$/chr$, -1 = pause
        bpl.s   rts5
        moveq   #0,d0           cancel error if pause (compatibility!)
rts5
        rts

err_bp2
        moveq   #err.bp,d0
        rts

* d0 -  o- 0
* d1 -  o- 60
* a1 -  o- RI stack pointer
* d2 destroyed
get_ri0
        moveq   #10*6,d1        same as in bv_chri
chrix
        move.l  d1,a1
        jsr     bv_chrix(pc)
        move.l  a1,d1
        move.l  bv_rip(a6),a1
        rts

* d0 -  o- 0 (no return on error)
* d1 -  o- total length including length word and possible padding byte
* d4 -  o- copy of d7
* d7 -ip - length of string required
* a1 -  o- RI stack pointer
* d2 destroyed
room_str
        move.w  d7,d4           copy length
        move.l  d7,d1
        addq.w  #3,d1
        bcs.s   bp_pop          reject string length $FFFD..$FFFF
        bclr    #0,d1
        bpl.s   chrix           accept string length 0..32764
bp_pop
        moveq   #err.bp,d0
pop_4b
        addq.l  #4,sp
        rts

bf_chrs
        bsr.s   get_ri0         gotta get space, as we will need 2 bytes extra
        jsr     ca_gtin1(pc)    get one integer (value in d1)
        bra.s   gotchrs         store char, if no error

* Skip one parameter, and expect an optional, single, integer (default d7)
* Same as opt_int below, except:
* a3 -i o- base of args / 8 added
opt_2nd
        addq.l  #8,a3

* Reserve 60 bytes on stack, get an optional, single, integer (default d7)
* d0 -  o- 0 (no return on error)
* d3 -  o- 0 if integer parameter was used, else -1
* d7 -i o- default / same, or lsw from present parameter
* a3 -ip - base of args
* a1 -  o- RI stack pointer (optional integer removed, bv_rip same)
* a5 -ip - top of args
* d1-d2 destroyed
opt_int
        bsr.s   get_ri0         check for room on ri
        jsr     ca_gtint(pc)
        bne.s   pop_4b
        subq.l  #1,d3
        blt.s   rts5            no arg, leave default alone
        bne.s   bp_pop          more than one arg, error
        move.w  0(a6,a1.l),d7
popword
        addq.l  #2,a1
        bra.l   put_rip

bf_fills
        subq.l  #8,a5           leave off the second parameter for now
        bsr.s   code_1          this ensures there are two parameters
        subq.w  #1,d3           how long was the string?
        bgt.s   got_pair        >=2, use first 2
        blt.s   err_bp2         null string is no good
        move.w  d5,-(sp)
        move.b  (sp)+,d5        duplicate a single character
got_pair
        addq.l  #8,a5           re-include the second parameter
        bsr.s   opt_2nd         get the required length (must be there now)
        bsr.s   room_str        make room for string
fillit
        subq.l  #2,a1
        move.w  d5,0(a6,a1.l)   copy 2 chars
        subq.w  #2,d1           repeat filling string
        bne.s   fillit
        bra.s   len_put         go put length

* Get a single string (d3=len, d5=0/1/2 chars), leave one word on the stack
code_1
        jsr     ca_gtst1(pc)    get a string
        bne.s   pop_4b
        move.w  d1,d3           get length (returned in d1)
        move.w  2(a6,a1.l),d5   get first characters
        add.l   d3,a1
        btst    d0,d3
        beq.s   popword
        addq.l  #1,a1
        bra.s   popword

bf_len
        bsr.s   code_1
c_null
        move.w  d3,d5
        bra.s   pushint1

bf_code
        bsr.s   code_1
        tst.w   d3
        beq.s   c_null          code('') is zero
        lsr.w   #8,d5           just first character is the value
        bra.s   pushint1

* Get the maximum size of a given dimension n of an array a (x=dimn(a{,n}))

bf_dimn
        moveq   #1,d7           default first dimension
        bsr.s   opt_2nd         get optional dimension parameter
        clr.w   d5              if all else fails, return zero
        moveq   #t.arr,d1       if it's not an array, i'm not interested
        sub.b   -8(a6,a3.l),d1  what sort was the first argument?
        bne.s   pushint1        not an array, so say zero, regardless
        move.l  4-8(a6,a3.l),d1 offset of array descriptor
        bmi.s   pushint1        say zero if not set! (better than error?)
        add.l   bv_vvbas(a6),d1
        cmp.w   4(a6,d1.l),d7   check number of dimensions
        bhi.s   pushint1        too many
        lsl.w   #2,d7           which one?
        beq.s   pushint1        hmmm... there isn't a zero dimension
        add.w   d7,d1
        move.w  2(a6,d1.l),d5   get max size
pushint1
        bra.l   pushint0

        end
