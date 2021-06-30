* Convert IPC shifts and keyrows to character or special
        xdef    tb_kbenc

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'

        section tb_kbenc

* d1 -i o- 6 lsb are keyrow (5-3 column, 2-0 row), see below for output
* d2 -i  - 3 lsb SHIFT/CTRL/ALT
* a4 -ip - sysvar extension address
* a6 -ip - sysvar
* d0/d2 destroyed

* Direct return, CTRL in combination with one of space, TAB or ENTER:
* d1.w  0..11: bit 0 = ALT, bit 1 = SHIFT, bit 2 = TAB, bit 3 = ENTER

* Return + 2, normal characters:
* d1.w  msb 0 and lsb 8 bit char or ...
*       ... msb 8 bit char and lsb $ff if the ALT prefix ($ff) is required.

* Return + 4, ignore this (compose first char stored or compose aborted)
* d1.w  undefined

do_ste
        asr.b   #1,d1           take SHIFT back out
        bcs.s   qal1            if no SHIFT, we have the keycode now
        move.b  stetab-252(pc,d1.w),d1 space, TAB and ENTER to unshifted
qal1
        bra.s   qalt            go add in the ALT stuff

special
        bsr.s   roll            roll SHIFT into d1 lsb and lose sign
        bpl.s   tryfx           still positive, try function keys
        add.b   d2,d2           do we have CTRL on?
        bcc.s   do_ste          no - go do normal space/TAB/ENTER
        addq.b  #8,d1           make d1 = 0..5, roll in ALT and direct return
roll
        add.b   d2,d2           roll one bit from d2 ...
        addx.b  d1,d1           ... into d1
        rts

tryfx
        bsr.s   roll            transfer CTRL into d1 lsb
        bmi.s   qalt            that's the end for f1-f5
        bsr.s   roll            transfer ALT into d1 lsb
        bmi.s   simp1           the end for cursor keys and CAPSLOCK
        asr.b   #1,d1           oops - it's actually ESC we're doing
        roxr.b  #1,d2           so put the ALT flag back into d2
        move.b  esctab(pc,d1.w),d1 and get the right byte from the table
        bra.s   qlck            go do capslock/ALT

tb_kbenc
        ror.w   #3,d2           tuck away sca bits
        smi     d0              remember SHIFT setting
        move.b  sv_ichar(a6),d2 are we composing?
        beq.s   noshf           no - carry on
        sf      sv_ichar(a6)    drop the compose flag
        lsl.b   #7,d0           make 0 or $80 if SHIFT is on
        or.b    d0,d2           saved or this SHIFT will do for later
        asl.w   #3,d2           this junks SHIFT/CTRL/ALT
        addq.b  #4,d2           and pretend SHIFT only is on
        ror.w   #3,d2           tuck away sca = 100
noshf
        ror.w   #8,d2           save compose in msb
        and.w   #$3f,d1
        move.b  keytab(pc,d1.w),d1
        bmi.s   special
        add.b   d2,d2           was SHIFT on?
        bcc.s   nctrl           no - have a go at CTRL
        bsr.s   toggle          form upper case letters and {|}
        cmp.b   #'`'-32,d1      was that the right thing to do?
        bhi.s   nctrl           yes - can look at CTRL now
        bne.s   notilde         equality means is was a `
        asr.b   #3,d1           turn the $40 into $08 (v. sneaky)
notilde
        move.b  shftab(pc,d1.w),d1
nctrl
        add.b   d2,d2           was CTRL on?
        bcc.s   qlck            no - go sort out capslock/ALT
        sub.b   #$60,d1         try normal CTRL/char
        bpl.s   qalt            ok, go do ALT
        add.b   #$c0,d1         others wanted + $60
qlck
        tst.b   sv_caps(a6)     is capslock set
        beq.s   qalt            no - skip this bit
        moveq   #'z'+1,d0
        bsr.s   togq
        moveq   #$8c-256,d0
        bsr.s   togq
qalt
        not.b   d2              was ALT on?
simp1
        bmi     simple          no - go finish off
        rol.w   #8,d1           put char into msb
        st      d1              put $ff into lsb
        addq.l  #2,(sp)         make a normal + 2 return
        rts

togq
        cmp.b   d0,d1           compare high end of range
        bcc.s   togx            too big - no toggle
        and.b   #$e1,d0         get low end of range
        cmp.b   d0,d1           compare low end of range
        bcs.s   togx            too small - no toggle
toggle
        eor.b   #32,d1          flip upper/lower case bit
togx
        rts

* ESC with optional SHIFT/CTRL
esctab
 dc.b $1b,$80,$7f,$1f {s/}{c/}ESC -> ESC  etc

* Primary key translate... decrypt the keyrow and detect interesting keys.

* Simple keys sort of go direct to their proper unshifted ASCII code.
* Top bits are used to sort out special cases.
keytab equ *-3 first three not used       1   2   4   8  16  32  64  128
 dc.b             $78,$76,$2f,$6e,$2c 7               x   v   /   n   ,
 dc.b $38,$32,$36,$71,$65,$30,$74,$75 6   8   2   6   q   e   0   t   u
 dc.b $39,$77,$69,$fd,$72,$2d,$79,$6f 5   9   w   i  TAB  r   -   y   o
 dc.b $6c,$33,$68,$31,$61,$70,$64,$6a 4   l   3   h   1   a   p   d   j
 dc.b $5b,$9c,$6b,$73,$66,$3d,$67,$3b 3  \{/ cap  k   s   f   =   g   ;
 dc.b $5d,$7a,$2e,$63,$62,$60,$6d,$27 2   ]   z   .   c   b   `   m   '
 dc.b $fe,$98,$9a,$80,$99,$5c,$fc,$9b 1  ent <-- /|\ ESC -->  \  spc \|/
 dc.b $bd,$ba,$35,$bb,$bc,$be,$34,$37 0  f4  f1   5  f2  f3  f5   4   7

* the results from the table give us:
* miscellany    $27..$3d                $27 to $3d -> need 2nd table if SHIFT
* a..z+         $5b..$7d                $5b to $7a -> eor $20 if SHIFT
* ESC           $80                     $80(c),$7f(s),$1f(cs) or $1b
* cursor keys   $98,$99,$9a,$9b         $c0,$c8,$d0,$d8 + SHIFT/CTRL/ALT
* CAPSLOCK      $9c                     $e0 + SHIFT/CTRL/ALT
* f1-f5         $ba,$bb,$bc,$bd,$be     $e8,$ec,$f0,$f4,$f8 + SHIFT/CTRL
* space         $fc                     $fc(s) or $20 \
* TAB           $fd                     $fd(s) or $09  > leave CTRL in d2 lsb
* ENTER         $fe                     $fe(s) or $0a /

* Unshifted space, TAB and ENTER
stetab equ *+2  overlap with unused entries in shftab

* Miscellany SHIFTed
shftab equ *-7
 dc.b $22 ' -> "
 dc.b $7e ` -> ~ (sneaky translate)
 dc.b $20,$09,$0a (spare 3 bytes in mshift, reused for stetab)
 dc.b $3c,$5f,$3e,$3f ,-./ -> <_>?
 dc.b $29,$21,$40,$23,$24,$25,$5e,$26,$2a,$28 0123456789 -> )!@#$%^&*(
 ds.b 1 unused
 dc.b $3a ; -> :
 ds.b 1 unused
 dc.b $2b = -> +
 ds.w 0

compose
        add.w   d2,d2           put SHIFT into bit 8
        lsr.b   #1,d2           set toggle flag = 0
        addq.l  #2,(sp)         return + 2 if ready, + 4 if scrap or first
        moveq   #compfst-1,d0   table starts after lower case specials
        subq.b  #1,d2           is it our second character?
        beq.s   sing            no - go do the first char lookup
        addq.b  #1,d2

        asl.w   #8,d1           put this char into msb
        move.b  d2,d1
dual
        addq.b  #2,d0
        bmi.s   ret2
chkswap
        rol.w   #8,d1
        cmp.w   comptab-1(pc,d0.w),d1 (n.b. d0 kept permanently odd)
        beq.s   compok
        not.b   d2              alternate swapping chars each time
        bmi.s   chkswap
        bra.s   dual

sing
        addq.b  #1,d0
        bmi.s   ret2            no such char in compose table
        cmp.b   comptab(pc,d0.w),d1
        bne.s   sing
        tst.b   d1
        bpl.s   savec1          non-print (+ESC) are single char compose

compok
        ror.b   #1,d0           we have (cleverly) arranged d0 to be odd
        move.w  d0,d1           (also gets rid of junk in top of d1)
        lsr.w   #1,d2           was SHIFT on for this (or prev) key ...
        or.b    sv_caps(a6),d2  ... or is capslock on?
        bmi.s   ret0            yes - that's ok
        moveq   #$ac-256,d0     is it $a0 to $ab?
        bra     togq            if so, this'll change it

savec1
        asr.w   #1,d2           get out the SHIFT we kept in top of d2
        or.b    d2,d1           incorporate this char
        move.b  d1,sv_ichar(a6) store it, then do an ignore return
ret2
        addq.l  #2,(sp)
ret0
        rts

simple
        asr.w   #8,d2           are we composing?
        bne.s   compose         yes - go do it

        moveq   #12,d2          counter and offset
rdlp
        subq.b  #1,d2
        bcs.s   ret2            end of table, return normal
        cmp.b   sx_kbste(a4,d2.w),d1
        bne.s   rdlp
        move.w  d2,d1           found a match, special return
        rts

* The compose table is byte pairs, which will be matched either way round.
* All entries are the SHIFT'ed characters, as this is forced while composing.
* The twelve entries that have lower case versions are changed back provided
* that capslock is not on and the SHIFT key was not held on either keypress.
 
compfst equ     12*2    the first block (lower case) are not needed
comptab equ     *-compfst
        dc.w    'A?A|A^E:E|E^I:I?I|I^O?O|O^U?U|U^SSC!Y_||'
        dc.w    'A:A~AOE?O:O~O!U:C<N~AEOE' these may be "lower-case'ed"
        dc.w    'AADDTTLLMMPIPH!!??TMPPOX<<>>OO:_',-60,-52,-44,-36

* N.B. Negative values in the above table (other than the convenient $ff, which
* never comes here) must be at odd addresses. They are single char compose.
* These are the space, TAB, ENTER, CAPSLOCK, ESC, function and cursor keys.
* Just the cursor keys are used at the moment (last 4 entries).

* Also, note that the following keys never occur in compose sequences:
*       space, TAB, ENTER, CAPSLOCK, ESC, function keys and "23457890=[]'"
* This makes them abort the compose immediately. Assigning one as the remapped
* compose key makes a lot of sense... though this will lose it's function on
* the keyboard. The neatest ones would be either open or close square bracket.
* one other candidate for the compose key is "`", which isn't used in basic.

* A word of warning... don't assign a 128-191 byte as the compose... you can
* get really stuck...

        end
