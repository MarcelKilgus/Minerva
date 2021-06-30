* Basic beep command
        xdef    bp_beep

        xref    bf_ipcom
        xref    bv_chrix
        xref    ca_gtint

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_ipcmd'
        include 'dev7_m_inc_mt'

* Syntax: BEEP{ duration,pitch{,pitch_2,grad_x,grad_y{,wrap{,fuzzy{,random}}}}}
*                 p3w     p0b     p1b    p2w     p4n    p5n   p7n    p6n

parmcnt equ     8               max no of parameters

        section bp_beep

bp_beep
        st      -(sp)           set for no reply
        subq.l  #1+1+4,sp       no parms on kill, so length word can be garbage
        move.w  #kiso_cmd<<8!0,(sp) kill sound, no parameter bytes
        move.l  a3,d7
        sub.l   a5,d7           - 8 * parameter count
        beq.s   gotrap          none - kill any beeping
        moveq   #parmcnt*2,d1
        jsr     bv_chrix(pc)    make sure of adequate space on ri stack
        asr.l   #3,d7           - parameter count
        moveq   #err.bp,d0      set d0 for possible error return
        addq.l  #parmcnt,d7     count of parameters being defaulted
        bcc.s   exit            too many parameters is invalid
        moveq   #%01001111,d2   reject 1, 3 or 4 parameters as invalid
        btst    d7,d2
        beq.s   exit            reject bad parameter count
        add.l   d7,d7
        sub.l   d7,bv_rip(a6)   register space on stack for defaults
        jsr     ca_gtint(pc)    get non-defaulted parameters
        bne.s   exit
        lea     parmcnt*2(a1),a0 end of parameter area
        add.w   d3,a1
        add.w   d3,a1           step over the non-defaulted parameters
        subq.b  #2,d3           were there just two parameters?
        bne.s   chk_def         no - only pitch_2 defaults to pitch
        move.w  2-parmcnt*2(a6,a0.l),d1 pick up pitch
def_lp
        move.w  d1,0(a6,a1.l)   set default
        addq.l  #2,a1           step on
chk_def
        moveq   #0,d1           rest default to zero
        cmp.l   a1,a0           any more to default?
        bne.s   def_lp          yes - keep going
        movem.w -parmcnt*2(a6,a0.l),d3-d6/a1-a4 pick them all up
        move.w  d3,d7           slot duration into order
        addq.b  #1,d4           pitch needs one added
        addq.b  #1,d5           pitch_2 needs one added
        ror.w   #8,d6           interval word needs bytes reversed
        ror.w   #8,d7           duration word needs bytes reversed
        exg     a3,a4           random and fuzzy need swapping over
        addq.l  #1+1+4,sp       discard the kill command.b/count.b/length.l
        movem.w d4-d7/a1-a4,-(sp) put on the beep init parameters
        move.l  #%00010001000100011010101010011001,-(sp) put on the lengths
                ;  4 - 4 - 4 - 4 - 8 8 8 8 8 - 8 -
                ;  fuz rnd wrp gry dur grx pt2 pt1
        move.w  #inso_cmd<<8+parmcnt*2,-(sp) put on the command/count
gotrap
        lea     bf_ipcom(pc),a2 execute command on stack in supervisor mode
        moveq   #mt.extop,d0
        trap    #1              protected against basic moving
exit
        assert  16,parmcnt*2
        ; Note: parameter count was either zero or sixteen
        moveq   #-32+1+1+4+2,d1
        or.w    (sp),d1         get 16/0 bit to form overall length less 32 
        lea     32(sp,d1.w),sp  discard the entire command
        rts

        end
