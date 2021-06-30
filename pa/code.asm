* Coded atom checking and tokenisation
        xdef    pa_cdlno,pa_cdnam,pa_cdnum,pa_cdspc,pa_cdstr,pa_cdsyv,pa_cdtxt
        xdef    pa_cdval,pa_text,pa_tok1 + pa_(cd/tb)(mon/ops/sep) by macros

        xref    bv_chri,bv_chtkx
        xref    cn_dtof,cn_dtoi
        xref    pa_alfnm,pa_chnam,pa_chnlt,pa_chunr
        xref    ri_float,ri_int

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_token'

        section pa_code

* Except where otherwise stated, all the routines operate as follows:
* return immediate if not recognised, or + 2 if sucessfully tokenised.
* a0 -i o- input text pointer (undefined on immediate return)
* a6 -ip - the base of basic
* d0-d6/a1-a3 destroyed

* Tokenise spaces - always suceeds and returns immediate

* a0 -i o- pointer to input text buffer
* a6 -ip - the base of basic
* d0-d5/a3 destroyed

pa_cdspc
        moveq   #' ',d1
        cmp.b   0(a6,a0.l),d1   any spaces at all?
        bne.s   rts0            no - make a quick return... speed
        move.w  a0,d5
nxchr
        addq.l  #1,a0
        cmp.b   0(a6,a0.l),d1   get first non-space
        beq.s   nxchr
        sub.w   a0,d5
        neg.b   d5
        seq     d4
        or.b    d4,d5           ensure we don't code up a zero for 256*n
        moveq   #b.spc,d4       space token
        bra.l   pa_tok1

* Check text and tokenise

pa_cdtxt
        move.l  bv_tkp(a6),a3   user might have typed "rem   ar"
        cmp.b   #b.spc,-2(a6,a3.l) so spaces will have already been tokened
        beq.s   pa_text         that'll be OK
        jsr     pa_alfnm(pc)    is first char alpha-numeric?
        bls.s   rts0            yes, that's no good here
pa_text
        move.l  a0,a2           beginning of text line
        move.l  bv_bfp(a6),a0   end of text line
        subq.l  #1,a0           ..not including the line feed of course..
        move.w  #w.txt,d4       text token and zero fill-in
        move.l  a0,d1           point at line feed
        sub.l   a2,d1           length of text
        bne.s   strlen          not zero, so we have to tokenise it
        addq.l  #2,(sp)         now we're OK
;       bra.s   rts0
;
;* Check system variable name
;
pa_cdsyv
;        cmp.b  #'&',0(a6,a0.l)  start with &?
;        bne.s  rts0
;        addq.l #1,a0
;        moveq  #0,d3
;        jsr    pa_chnlt(pc)     and rest of name
;        bra.s  rts0
;
; must put in a test for existance when we know where they're kept
; -- just save the token for now
;
;        move.w #w.syv,d4        name token and zero fill for now?
;        bra.s  tok2             put in list
rts0
        rts

* Check string & tokenise

pa_cdstr
        move.w  #w.str,d4       string token
        move.b  0(a6,a0.l),d4   move in delimiter
        moveq   #'''',d1        single quote ...
        sub.b   d4,d1
        beq.s   body
        subq.b  #''''-'"',d1    ... or double quotes are OK
        bne.s   rts0
body
        addq.l  #1,a0           skip opening quote
        move.l  a0,a2           this is where body of string starts
        moveq   #10,d5          avoid linefeeds
stnxt
        move.b  0(a6,a0.l),d1   next char
        cmp.b   d5,d1           check it isn't a line feed
        beq.s   rts0            we can't recover from that
        addq.l  #1,a0           space over the byte
        cmp.b   d4,d1           is it the matching quote?
        bne.s   stnxt           ..no, carry on then
* I'm tempted to add the syntax of repeated delim -> single... but it's a
* hassle for listing the program. Also, leaving off final delim as valid?

        move.l  a0,d1
        subq.l  #1,d1           don't include the closing quote
        sub.l   a2,d1           calculate length
strlen
        move.w  d1,d5           save the length
* Don't bother to validate the length, as the worst possible input we can ever
* get is an unnumbered line with 32767 characters, containing a string with
* it's delimiting quotes and a line feed. I.e. 32764, which is just OK!
        addq.w  #4,d1           string header takes 4 bytes
        bsr.l   move4           do the first four bytes
        bra.s   cent

copy
        move.b  0(a6,a2.l),4(a6,d2.l) copy a character
        addq.l  #1,d2
        addq.l  #1,a2
cent
        dbra    d5,copy
        rol.b   #8,d2           was the length odd or even?
        bcc.s   retur2          even is OK
        clr.b   4(a6,d2.l)      fill any odd byte with a nought
        addq.l  #1,a3           round up tk pointer to even
        bra.s   retur2

* Check value and tokenise it

pa_cdnum
pa_cdval
        lea     cn_dtof(pc),a3  convert decimal to float
        bsr.s   cndto           go do it
        move.l  2(a6,a1.l),d4   get the mantissa
        tst.b   bv_toe(a6)      bit 7 set means no integer tokenisation
        bmi.s   mkfp
        jsr     ri_int(pc)
        bne.s   mkfp
        move.w  0(a6,a1.l),d6   get integer
        jsr     ri_float(pc)    send it back to f.p.
        cmp.l   2(a6,a1.l),d4   is it identically the same?
        bne.s   mkfp
        cmp.w   0(a6,a1.l),d5
        beq.s   mkint
mkfp
        moveq   #6,d1           float takes six bytes
        bsr.s   tkchk
        or.w    #$f000,d5       add the flpnt token
        move.w  d5,-6(a6,a3.l)  put the tok+exponent into toklist
        move.l  d4,-4(a6,a3.l)  followed by the mantissa
retur2
        addq.l  #2,(sp)         OK now
return
        move.l  a3,bv_tkp(a6)   update token list pointer
        rts

* Check for a line number and tokenise

pa_cdlno
        lea     cn_dtoi(pc),a3  convert decimal to integer
        bsr.s   cndto           go do it
        ble.s   rts1            don't allow neg or zero line numbers
        moveq   #4+12,d0        total stack depth for unvr return
        jsr     pa_chunr(pc)    no return if stuck in unravel
        move.w  #w.lno,d4       line number token and zero fill
        bra.s   tok2            put token on list

cndto
        jsr     bv_chri(pc)     reset and check ri stack
        move.l  bv_rip(a6),a1
        move.l  a0,d3
        jsr     (a3)            convert decimal to whatever
        cmp.l   a0,d3
        beq.s   poprts          if it fails or converts nowt, discard return
        move.w  0(a6,a1.l),d5   get exponent/number
        rts

poprts
        addq.l #4,sp            discard top of stack
rts1
        rts

mkint
        move.w  #w.lgi,d4
        move.w  d6,d5
        asl.w   #8,d6           check if we can squash integer in single byte
        bvs.s   tok2            nope - tokenise as lgi
        moveq   #b.shi,d4       wow! yes, -128..127 is popular!
        bra.s   goodtok1

moretk
        move.l  d1,a3
        jsr     bv_chtkx(pc)    get enough room
        move.l  a3,d1
tkchk
        move.l  bv_tkp(a6),a3   get running toklist pointer
        move.l  a3,d2           save it
        add.l   d1,a3           this is where we want to extend to
        cmp.l   bv_tkp+4(a6),a3 check next pointer
        bgt.s   moretk          need more space
* Above arrangement to improve speed of tokenisation
        rts

* Check name and tokenise

pa_cdnam
        move.l  a0,a3           save buffer pointer
        jsr     pa_chnlt(pc)    check next thing in buffer looks like a name
        bra.s   rts1            ..it doesn't...
        move.l  a0,d5           end of name
        sub.l   a3,d5           length of name
        cmp.w   #256,d5         is name too long for a byte length?
        bcc.s   rts1            ..serves user right for trying it on..
        move.l  a0,-(sp)        save buffer pos
* N.B. Dirty tricks in chnam/chunr means we must have stack right here!
        jsr     pa_chnam(pc)    check name in table
        bra.s   poprts          rats - it looks like a keyword
        move.l  (sp)+,a0        restore buffer
        move.w  #w.nam,d4       name token and zero fill

* Put four byte token into the token list

tok2
        moveq   #4,d1           four byte token
        pea     retur2
move4
        bsr.s   tkchk
        movem.w d4-d5,0(a6,d2.l) (e.g. toktyp byte, delimiter and length)
        rts

* Check for monadic operators, dyadic operators and separators.

* Note. The symbol table follows the call address, after the symbol type byte.
* The type is fetched, then the table must be in the form:

*        (a2).b no of symbols in table starting with 1 (n)
*       r(a2).b offset on a2 of r'th prebyte
*     n+1(a2).b 1st prebyte of the form 0XYh where Y is no of chars and X
*               is zero if no trailing space is required else 1
*   n+1+c(a2).b c'th character of 1st symbol
* n+1+c+1(a2).b pre-byte of 2nd symbol
*         etc

end_sym
        lsl.w   #7,d6           did the prebyte say we need a space
        bpl.s   tok1ok          no space needed, we're OK
        jsr     pa_alfnm(pc)    want a non-alphanumeric
        bls.s   char1           not there, try the next (gets a0 sorted)
tok1ok
        move.w  a3,d5
        sub.w   a2,d5           token number
        lsr.w   #8,d4           fetch down token type
goodtok1
        addq.l  #2,(sp)         good return

* Put two byte token into the token list

* d4 -i  - token type
* d5 -i  - token lsb
* a6 -ip - the base of basic
* d0-d3/a3 destroyed

pa_tok1
        moveq   #2,d1           two byte token
        bsr.s   tkchk           check space and get a3
        move.b  d4,-2(a6,a3.l)  first byte (toktyp)
        move.b  d5,-1(a6,a3.l)  second byte (value)
        bra.l   return

nextchar
        addq.l  #1,a0           move to next buffer character
        sub.b   d5,d6
        beq.s   end_sym         no chars left in symtab symbol
        bsr.s   getchar         and get it
        cmp.b   (a1)+,d1        does it match next table char?
        beq.s   nextchar        no, start again with next symbol
char1
        move.l  d0,a0           get posn of 1st char of buffer
        bsr.s   getchar         get 1st char, converted to single case
nextsym
        subq.b  #1,d4           any symbols left to check?
        bcs.s   rts3            no, don't have a valid symbol then
        move.b  (a3)+,d2        get prebyte offset (n.b. alfnm clears d2 15-8)
        lea     -1(a2,d2.w),a1  point to prebyte
        move.b  (a1)+,d6        read prebyte and move on
        cmp.b   (a1)+,d1        does 1st char match?
        bne.s   nextsym         no, try the next symbol
        lsl.w   #4,d6           put space flag in bit 8
        bra.s   nextchar

getchar
        jsr     pa_alfnm(pc)    find out if char at (a0,a6) is a letter
        bcc.s   rts3            if it's a letter, force to a single case
        bclr    #5,d1           accented, lower case, or normal, upper case
rts3
        rts

chsym
        move.l  (sp)+,a2        get table base off stack
        move.w  (a2)+,d4        get token type and count
        move.l  a2,a3           set running pointer to offsets
        move.l  a0,d0           save where 1st char of buffer is
        moveq   #1<<4,d5        speed up counting
        bra.s   char1

* Generate code/tables for text lexical stuff

alpha setstr ABCDEFGHIJKLMNOPQRSTUVWXYZ

pa_cd macro
        xdef    pa_cd[.lab],pa_tb[.lab]
pa_cd[.lab]
        bsr.s   chsym
        dc.b    b.[.lab]
pa_tb[.lab] dc.b [.nparms]
i setnum 0
l maclab
i setnum [i]+1
 dc.b [.lab][i]-*+[i]
 ifnum [i] < [.nparms] goto l
i setnum 0
m maclab
i setnum [i]+1
j setnum 1-([.instr(alpha,.ucase(.right(.parm([i]),1)))]-1)>>8&1
[.lab][i] dc.b $[j][.len(.parm([i]))],'[.ucase(.parm([i]))]'
 ifnum [i] < [.nparms] goto m
        ds.w    0
 endm

* Generate entry points, code and tables for text lexical objects

sep pa_cd {,} {;} {\} ! to
mon pa_cd - + ~~ not
ops pa_cd + - * / >= > == = <> <= < || && ^^ ^ & or and xor mod div instr

        end
