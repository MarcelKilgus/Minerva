* Check name letters
        xdef    pa_alfnm,pa_chnlt

        section pa_chnlt

* a0 -i o- buffer pointer (unchanged if ret+0 or moved past valid name ret+2)
* d1-d2 destroyed

pa_chnlt
        bsr.s   pa_alfnm
        bcc.s   cdunrec         first char must be a letter
nxchr
        addq.l  #1,a0
        bsr.s   pa_alfnm        is next alphanumeric?
        bls.s   nxchr           yes - keep going
        sub.b   #'$',d1
        lsr.b   #1,d1           note: '$'+1='%'
        bne.s   end_nam
        addq.l  #1,a0           move past a final '$' or '%'
end_nam
        addq.l  #2,(sp)
cdunrec
        rts

* Fetch a character and establish its alphanumeric type.

* d1 -  o- character fetched
* d2 -  o- lsw char type, 0=numeric 1=uppercase 2=other 3=lowercase. msw junk
* a0 -ip - pointer, relative to a6, for character under test
* Flags:
*       z       0     beq for numeric
*       c       1/3   bcs for alpha
*       zvc     0/1/3 bls for alphanumeric

pa_alfnm
        moveq   #0,d1           default is zero
        move.b  0(a6,a0.l),d1   look at initial char
        move.l  d1,d2
        ror.l   #2,d2           d2.w has char/4 - top has bottom bits
        move.b  chtypes(pc,d2.w),d2 gives bits for 4 chars
        swap    d2              byte from type-table in d2 top word
        rol.w   #3,d2           get 2 bottom bits into d2.w bits 1,2
        lsr.l   d2,d2           shift (upper word) right 2n bits
        clr.w   d2              clear lsw
        ror.l   #2,d2           bits 15-14 get char value
        rol.w   #2,d2           bits 1-0 of d2 have char type
        rts

* the table of char types yields the folowing:
*       00 - digits '0' to '9'
*       01 - uppercase 'A' to 'Z', '_' and chars 160-171.
*       11 - lowercase 'a' to 'z' and chars 128-156.
*       10 - non-alphanumeric, i.e. all other characters

* The lowest character code is in the least significant bits of each byte

nnnn equ %00000000
uuuu equ %01010101
xuuu equ %01010110
xxxu equ %01101010
uuux equ %10010101
nnxx equ %10100000
xxxx equ %10101010
lxxx equ %10101011
lllx equ %10111111
xlll equ %11111110
llll equ %11111111

chtypes
 dc.b xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx 0-31
 dc.b xxxx,xxxx,xxxx,xxxx,nnnn,nnnn,nnxx,xxxx space to '?'
 dc.b xuuu,uuuu,uuuu,uuuu,uuuu,uuuu,uuux,xxxu '@' to '_'
 dc.b xlll,llll,llll,llll,llll,llll,lllx,xxxx '`' to del
 dc.b llll,llll,llll,llll,llll,llll,llll,lxxx 128-159
 dc.b uuuu,uuuu,uuuu,xxxx,xxxx,xxxx,xxxx,xxxx 160-191
 dc.b xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx 192-223
 dc.b xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx,xxxx 224-255

        end
