* Various odd basic procedures
        xdef    bp_baud,bp_call,bp_mode,bp_net,bp_rande,bp_repot,bp_tra

        xref    bp_chand
*        xref    bv_chri
        xref    ca_gtin1,ca_gtint,ca_gtlin
        xref    ib_errep
*        xref    mm_clrr
        xref    ut_err

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_assert'

        section bp_misc

* report{#chan}{,errno}
repit
        bne.s   err_bp
        move.l  d1,d0
        jsr     ut_err(pc)
        bra.s   okrts

bp_repot
        moveq   #0,d1           if no channel, then use console
        jsr     bp_chand(pc)
        bsr.s   gtlin
        subq.w  #1,d3
        bcc.s   repit
        assert  bv_error,bv_erlin-4
        movem.l bv_error(a6),d0/d3 get error number and line
        move.b  bv_erstm(a6),d3 put in statement
        jsr     ib_errep(pc)    write out the error
okrts
        moveq   #0,d0
        rts

* MODE p1{,p2} sets the display mode
bp_mode
        jsr     ca_gtint(pc)
        bne.s   rts0
        movem.w 0(a6,a1.l),d1-d2
        subq.w  #2,d3
        beq.s   set_it
        addq.w  #1,d3
        bne.s   err_bp
        moveq   #-1,d2          no change to monitor/tv byte
        and.w   #256+8,d1       only check bits corresponding to 8 or 256
        beq.s   set_it          512,4,etc - byte is zero
        moveq   #8,d1           256,8,264 - byte is 08h
set_it
        moveq   #mt.dmode,d0    set mode
        bra.s   trap1

* NET number sets the network station number (1..127)
bp_net
        jsr     ca_gtin1(pc)    one integer
        bne.s   rts0
        move.b  d1,d3           get argument
        ble.s   err_bp
        assert  0,mt.inf
        trap    #1
        move.b  d3,sv_netnr(a0)
        rts

* CALL address(,long)...: longwords put into d1-d7/a0-a5, then "jsr address"
bp_call
* We could force there to be enough zeroes on the stack to complete the call
* parameters with all zeroes. There have to be at most 13 longwords of zero to
* cope with the worst case. We would have to push the whole lot, to make it
* easier in the case that the caller might even give to many parameters.
* However, as CALL gets replaced so often, maybe it's not worth the trouble.
* There is another bonus - call code may be happier with the extra stack space.
* Minimum cost is 22 bytes, and some time, plus switching to sup mode.
* Given the latter two considerations, maybe we'll just forget it!
*        jsr     bv_chri(pc)     this ensure 60 bytes, more than we need
*        moveq   #13*4,d1
*        sub.l   d1,bv_rip(a6)   push extra longwords
*        move.l  bv_rip(a6),a0
*        jsr     mm_clrr(pc)     set the extras to zero
        bsr.s   gtlin           get long integers
        asl.l   #2,d3           remove the parameters from stack
        ble.s   err_bp          if none (or too many!) give up
*        moveq   #13*4,d0        lose our extra longwords
*        add.l   d0,d3
        add.l   d3,bv_rip(a6)
        move.l  d1,-(sp)        set up address
        movem.l 4(a6,a1.l),d1-d7/a0-a5 set up registers
err_bp
        moveq   #err.bp,d0
rts0
        rts

gtlin
        jsr     ca_gtlin(pc)
        movem.l 0(a6,a1.l),d1-d2 enough for some
        beq.s   rts0
        addq.l  #4,sp
        rts

* RANDOMISE{delimiter}{value}: initialises the random number generator.
* Two flavours are now supported. The old one is used if the lsb of bv_rand is
* set to one. The new (better!) one uses an lsb of zero, and is invoked by a
* null first argument.
bp_rande
        moveq   #7,d5
        cmp.l   a3,a5
        beq.s   rndnorm         no parameters, don't set new scheme
        and.b   1(a6,a3.l),d5   otherwise null 1st parameter is new scheme
        bne.s   rndnorm
        addq.l  #8,a3
rndnorm
        bsr.s   gtlin           get a seed
        subq.w  #1,d3           was there one parameter?
        beq.s   get_rand        just one, use it as seed
        bcc.s   err_bp          no parameters uses clock, nowt else allowed
        moveq   #mt.rclck,d0    get time
        trap    #1
get_rand
        tst.b   d5
        bne.s   rndgrot
        add.l   d1,d1           new scheme keeps 31 given bits, plus clear lsb
rndput
        move.l  d1,bv_rand(a6)  put seed and flag into location
        rts

rndgrot
        move.l  d1,d2           make both ends significant
        swap    d1              this wastes a lot of randomisation bits
        add.l   d2,d1           tacky... but can't change it now!
        bset    d0,d1
        bra.s   rndput

* BAUD rate: sets the baud rate for the serial ports
bp_baud
        jsr     ca_gtin1(pc)    get the baud rate to d1
        bne.s   rts0
        moveq   #mt.baud,d0
trap1
        trap    #1              go try to set it
        rts

* specify translation modes

* this basic command has the format :
*       tra  arg1{,arg2}        or      tra  ,arg2
* where arg1 controls the serial i/o translation tables:
*       <= -2   turn on translation
*       = -1    no change
*       = 0     turn off translation
*       = 1     set default i/o tables and turn it on
*       = other set user defined i/o tables and turn it on
* and arg2 controls the message table:
*       <= 0    no change
*       = 1     set default system messages
*       = other set user defined messages

* both user tables must be specified by an even address, at which the first
* word is $4afb.

* the translation tables then contain two words, giving the offset to the
* input and output translation tables. these may be given as zero to turn
* each off, or should point at a 256 byte direct translate list. only 128
* bytes are needed if only 7-bit data is being used.

* the message table continues with a count of the number of messages in the
* table and then their offsets. each message must be on an even address,
* prefixed by its character count word.

bp_tra
        move.l  a5,d5
        sub.l   a3,d5
        ble.s   err_bp          no parameters, we don't like
        asr.l   #3,d5
        subq.l  #2,d5
        bgt.s   err_bp          1 (d5=-1) or 2 (d5=0) parameters we like
        moveq   #15,d1
        and.b   1(a6,a3.l),d1
        bne.s   getem
        addq.l  #8,a3           skip omitted 1st param
getem
        bsr.s   gtlin           get arguments
        moveq   #mt.cntry,d0    set up trap code
        subq.w  #2,d3           how many ?
        beq.s   trap1           two - all must be ready
        moveq   #-1,d2          maybe just 1st param
        cmp.w   d3,d5           did we have 1st param null?
        beq.s   trap1           no - we're there
        exg     d1,d2           swap 'em over
        bra.s   trap1           go to it

        end
