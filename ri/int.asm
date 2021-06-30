* Converts floating point to 16/32 bit integer
        xdef    ri_nlint,ri_lint,ri_nint,ri_int

        xref    ri_add,ri_errov,ri_one

        section ri_int

* N.B. On returning err.ov, this routine now also makes the returned value in
* d1 equal to a maximum value of the correct sign. This helps keep things happy
* if one omits to check the error return.

* d0 -  o- error code (ccr set)
* d1 -  o- result (w/l)
* a1 -i o- arithmetic stack (+4/2 for w/l)
* d2 destroyed by n(l)int

nint
        jsr     ri_one(pc)
        sf      1(a6,a1.l)      put .5 on stack
        jsr     ri_add(pc)      round
int
        move.w  #$800,d0        base
        sub.w   0(a6,a1.l),d0   take away exponent
        ble.s   check           is value tiny?
        moveq   #0,d0           set to zero exponent
check
        add.w   #$1f,d0         shift mantissa right
        move.l  2(a6,a1.l),d1   get mantissa
        asr.l   d0,d1
store
        move.l  d1,2(a6,a1.l)   store result
        rts

ri_nint
        bsr.s   nint
        bra.s   wcheck

ri_int
        bsr.s   int             get word
wcheck
        asr.w   #4,d0           was exponent in range ?
        ble.s   err_ret
        addq.l  #2,a1
ok_ret
        moveq   #0,d0
linret
        addq.l  #2,a1
        rts

ri_nlint
        bsr.s   nint
        bra.s   lcheck
ri_lint
        bsr.s   int             get long word
lcheck
        neg.w   d0              exponent in range ?
        ble.s   ok_ret

err_ret
        move.w  d0,-(sp)        save which one we were doing
        jsr     ri_errov(pc)    go make the max value
        neg.w   (sp)+           ok, so which was it?
        bmi.s   linret          finished if it was lint (condition code ok)
        asr.l   #8,d1
        asr.l   #8,d1
        bsr.s   store           go store appropriate max num
        addq.l  #4,a1
        tst.l   d0              make sure condition codes are set
        rts

        end
