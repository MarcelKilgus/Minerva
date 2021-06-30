* Convert operands for the evaluator
        xdef    ca_cnvrt

        xref    bv_chrix
        xref    cn_dtof,cn_dtoi,cn_ftod,cn_itod
        xref    ri_float,ri_nint

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_vect4000'

        section ca_cnvrt

* Converts whatever is on top of name table to the requested type.
* The name table is assumed to be describing the value currently on the top
* of the a1 stack.
* Even there is an error, the type conversion will have been done, though the
* result on the RI stack may not be particularly useful.
* The basic buffer is no longer used (lwr).

* d0 -i o- type required / error code
* a1 -i o- stack pointer
* a5 -ip - top of NT stack
* ccr-  o- result of tst.l d0

reglist reg     d1/d3/d7/a0
ca_cnvrt
        move.l  d2,-(sp)        save only one reg, in hope of no conversion
        moveq   #15,d2          minus the mask, if any
        and.l   d2,d0           make sure only lsb's set (see gtarg)
        and.b   -7(a6,a5.l),d2  get the current type of operand
        bne.s   oldok           maybe this always happens?
        moveq   #t.str,d2       don't be fooled by old type = substring
oldok
        move.b  d0,-7(a6,a5.l)  set new type immediately

        sub.b   d2,d0           subtract old from new (d0.l=0)
        beq.s   cnv_ex          they match, so nothing further to do

        movem.l reglist,-(sp)
        subq.b  #t.fp,d2        test old type
        bmi.s   stox            go do string to something
        beq.s   ftox            go do floating point to something

* Required conversion in d0.b is now -2:str -1:fp or 1:log
*itox
        lsr.b   #1,d0           integer to something, find out what
        beq.s   itol            int to log (d0.l=0)
        bcc.s   itos            int to string

*itof
       ;moveq   #6-2,d1         need 4 bytes extra
        bsr.s   chkri
        jsr     ri_float(pc)    int to fp -- can't fail
        bra.s   cnv_end

itol
        move.w  0(a6,a1.l),d1   int to log, just make non-zero into 1
set_log
        beq.s   log_end
        moveq   #1,d1           non-zero becomes one
log_end
        subq.b  #t.log-t.int,-7(a6,a5.l) change new type from t.log to t.int
put_wrd
        move.w  d1,0(a6,a1.l)   store string length, etc
cnv_end
        move.l  a1,bv_rip(a6)   always has been converted to something
        movem.l (sp)+,reglist
cnv_ex
        move.l  (sp)+,d2
        tst.l   d0
        rts

* Required conversion in d0.b is now -1:str 1:int or 2:log 
ftox
        asr.b   #2,d0           what are we converting fp to?
        bmi.s   ftos            string
        bcs.s   ftol            logical (d0.l=0)

*ftoi
       ;moveq   #6,d1           nint needs to add .5 (fp)
        bsr.s   chkri
        jsr     ri_nint(pc)     integer, do it
        bra.s   cnv_end

stof
        jsr     cn_dtof(pc)     convert it to fp
        move.l  2(a6,a1.l),d2   pick up result mantissa, hopefully
        subq.l  #6-2,d7         extra space for fp result
        bsr.s   adjri           set ri stack pointer
        move.l  d2,2(a6,a1.l)   store fp result mantissa
        cmp.b   #t.log,-7(a6,a5.l) were we actually after a logical?
        bne.s   put_wrd         no - that's it then

ftol
        move.l  2(a6,a1.l),d1   get and test mantissa
        addq.l  #6-2,a1         discard float, keep int
        bra.s   set_log

chkri
        moveq   #4*6-2,d1       this is the worst case space needed
        jsr     bv_chrix(pc)    check ri stack
        move.l  bv_rip(a6),a1   reload pointer
        rts

* Required conversion in d0.b is now 1:fp 2:int or 3:log 
stox
       ;moveq   #4*6-2,d1       we may need 4 fp's less the string length
        bsr.s   chkri
        addq.l  #2,a1           discard string length
        move.l  a1,a0           pointer to start of string
        moveq   #0,d7
        move.w  -2(a6,a1.l),d7  get length
        add.l   a1,d7           pointer to end of string
        cmp.b   #t.int,-7(a6,a5.l) are we after a straight integer?
        bne.s   stof            float (or logical)

*stoi
        jsr     cn_dtoi(pc)     convert integer
        bsr.s   adjri           set ri stack pointer and copy integer
put_wd1
        bra.s   put_wrd

itos
       ;moveq   #2+6-2,d1       extra space needed
        bsr.s   chkri
        lea     -(2+6-2)(a1),a0 where string will go
        jsr     cn_itod(pc)     do conversion -- can't fail
stkst
        move.w  d1,d2           copy length
        lsr.w   #1,d2           odd length?
        bcc.s   stent           no - that's ok
        addq.l  #1,a0           yes - allow for final pad byte
stmov
        subq.l  #2,a0
        subq.l  #2,a1
        move.w  0(a6,a0.l),0(a6,a1.l) shuffle string chars up stack
stent
        dbra    d2,stmov
        subq.l  #2,a1
        bra.s   put_wd1

ftos
       ;moveq   #2+14-6,d1      extra needed
        bsr.s   chkri
        lea     -(2+14-6)(a1),a0 where string will go
        jsr     cn_ftod(pc)     do the conversion -- can't fail
        bra.s   stkst           put string on stack

adjri
        move.w  0(a6,a1.l),d1   pick up result int or exponent (hopefully)
        move.l  d7,a1           put end of string into ri pointer
        or.w    #-2,d7          get odd=-1/even=-2
        add.w   d7,a1           adjust ri pointer even with space for integer
        rts

        vect4000 ca_cnvrt

        end
