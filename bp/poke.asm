* Puts a byte, word or long into memory. Doesn't care if address is odd.
        xdef    bp_pepo,bp_poke,bp_pokel,bp_pokew

        xref    ca_gtlin

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_mt'

* Syntax is now:
*       POKE{_W|_L} {<delim>{vector}\}<address>{,<value>}...
* They now accept a list of values to be poked at the address, onwards.
* They blithely ignore it if no parameters at all are given.
* If an initial null argument is given, as a temporary measure, they operate
* treating the third argument as the address relative to a6. In this case,
* should there be a non-null second argument, it will be used be used to pick
* up a longword relative to a6 offset to be added to the third argument.

        section bp_poke

bp_pokel
        addq.b  #2,d7           four bytes per value
bp_pokew
        addq.b  #1,d7           two bytes per value
bp_poke
        pea     pkent           entry to loop

* Set up address for peek/poke operations. No return on error.

* There are five variations, so far, on the address specification:
*    name       spec            type            value
*  absolute   address         absolute        address
*  sysvars    !;offset        absolute        sysvars+offset
*  sysvect    !vector;offset  absolute        sysvars(vector).l+offset
*  a6rel      \;offset        rel a6          offset
*  a6vect     \vector;offset  rel a6          0(a6,vector).l+offset
* So far, only the "!"'s are checked explicitly.

* d0 -  o- 0
* d3 -  o- number of remaining parameters (ccr set to this)
* d5 -  o- all zero except ls 4 bits
* d6 -  o- lsb request type: <= 0 a6 relative or >0 for absolute
* a1 -  o- ri stack pointer to four before first additional longword arguments
* a3 -i  - base of args
* a5 -i o- top of args / absolute address or a6 relative offset
* d1-d2/d4/a0 destroyed

bp_pepo
        moveq   #2-1,d6         scan for up to two null args
        move.b  1(a6,a3.l),d4   get first delimiter
nulls
        moveq   #15,d5
        and.b   1(a6,a3.l),d5   is argument null?
        bne.s   notnull
        addq.l  #8,a3           move over one argument
        dbra    d6,nulls        only go for 0, 1 or 2 null params!
notnull
* d6.l=1(no nulls),0(one null),$ffff(two nulls)
        jsr     ca_gtlin(pc)    get arguments (will be happy with a3>a5 even!)
        bne.s   pop             no return if parameters no good
        move.l  0(a6,a1.l),a5
        sub.l   a0,a0
        lsl.b   #2,d4           check for 1st parameter null and delimiter '!'
        bne.s   notsysv
        moveq   #mt.inf,d0
        trap    #1
        lsr.b   #7,d6
notsysv
        tst.b   d6
        bne.s   goback
        addq.l  #4,a1           skip vector
        move.l  a1,bv_rip(a6)   lose it
        subq.w  #1,d3           discount that one
        move.l  0(a6,a1.l),d2   get offset
        exg     d2,a5           swap them over
        bclr    d6,d2           we won't quibble with an odd vector address
        tst.b   d4
        bne.s   isbas
        add.l   0(a0,d2.l),a5   add sysvars vector to offset
        moveq   #1,d6
        bra.s   gota5

isbas
        add.l   0(a6,d2.l),a5   add basic vector to offset
goback
        add.l   a0,a5           if direct sysvars, add base to offset
gota5
        subq.w  #1,d3
        bge.s   rts0
        moveq   #err.bp,d0
pop
        addq.l  #4,sp
rts0
        rts

* Actual code for poke's

pkarg
        addq.l  #4-1,a1
        sub.w   d7,a1
        move.w  d7,d1
pklp
        tst.b   d6
        bgt.s   abs
        move.b  4(a6,a1.l),0(a6,a5.l) poke rel a6
        addq.l  #1,a5
        bra.s   bdone

abs
        move.b  4(a6,a1.l),(a5)+ copy bytes one at a time
bdone
        addq.l  #1,a1
        dbra    d1,pklp
pkent
        dbra    d3,pkarg        any values left to do?
        rts

        end
