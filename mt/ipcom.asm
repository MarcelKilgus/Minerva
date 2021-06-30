* Sends a command to the IPC
        xdef    mt_ipcom

        xref    ip_setad,ip_rdwr
        xref    ss_noer

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_ipcmd'

        section mt_ipcom

* Transmit a command block containing:
*       a command (byte, 4 lsb are the command)
*       no of bytes of parameters (byte, 0..16)
*       amount of each byte to send (4 bytes) encoded:
*               x1=0 bits       00=4 bits       10=8 bits
*               1st parameter amount is bits 1-0 of the 4th of these bytes.
*       parameters (bytes)
*       amount of result to return, encoded as above in bits 1-0

* ipcom will employ a linked list of user routines, based at sx_ipcom, which
* is initially zero. ut_link and ut_unlk should be used in supervisor mode to
* attach and remove user code linkage blocks.
* The user routine linkage is in the typical form of two longwords.
* The first longword is the link to the next user routine (zero if none).
* The second longword is the user code entry address.
* The address of the first of these is supplied to the user's code in a0.
* It is also given d0.l=command, d5.l=param lengths, d7.l=param count,
* a6=sysvars and a3 pointing to the parameter bytes and return code byte.
* Interrupts will have been already inhibitted.
* If it does not process the command, it may only destroy a1/d6 and should
* return normally.
* If it processes the command completely, it may destroy d0/d5-d7/a0-a1/a3 and
* must return two on from the normal return, e.g. addq.l #2,(sp).
* Any expected return value must have been put in d1.
* This game is all mainly to allow keyrow calls to be intercepted.

* d0 -  o- 0
* d1 -  o- return parameter from call (undefined if none requested)
* a3 -i p- pointer to command block. (can now be odd. lwr)
 
reglist reg     d5-d6/a0-a1/a3
mt_ipcom
        movem.l reglist,-(sp)
        move    sr,-(sp)        save status register
        or.w    #$700,sr        no interrupts
        moveq   #15,d0
        and.b   (a3)+,d0        get the command (losing msbs, to be clean)
        cmp.b   #inso_cmd,d0
        bne.s   soundok
        st      sv_sound(a6)    ensure that sv_sound is set when a beep starts
soundok
        move.b  (a3)+,d7        get the number of parameters
        moveq   #4,d6
params
        lsl.l   #8,d5
        move.b  (a3)+,d5        get param lengths, not requiring even address
        subq.b  #1,d6
        bne.s   params
        move.l  sv_chtop(a6),a0 get system extension address
        lea     sx_ipcom(a0),a0 get front end link address
lpfront
        move.l  (a0),d6
        beq.s   fronted         zero means there aren't any more
        move.l  d6,a0
        move.l  4(a0),a1
        jsr     (a1)            call user's front end routine
        bra.s   lpfront
        bra.s   exit            user return if they processed the command
fronted
        jsr     ip_setad(pc)    set up IPC addresses
        moveq   #5*4,d1         space for six nibbles, but we baulk at five
* Enter loop pushing the command nibble

four
        lsl.b   #4,d0           lose top nibble and set 4 lsbs zero
        lsl.l   #4,d0           move up single nibble leaving lsb zero
        subq.b  #4,d1           are we full up yet?
check
        bgt.s   zero            still space for a byte, so carry on
        bsr.s   flush           write what we have so far
        moveq   #5*4,d1         set counter for more
zero
        move.b  (a3)+,d0        always get next byte
        subq.b  #1,d7
        bge.s   send_par

        move.b  d0,d7
        st      d0              0..2 nibbles to be read back
        rol.b   #7,d7           last byte is the return requirements
        bmi.s   nonein          get nothing
        bcc.s   nibin
        lsl.l   #4,d0
        subq.b  #4,d1
nibin
        lsl.l   #4,d0
        subq.b  #4,d1
nonein
        bsr.s   flush
        lsr.l   #7,d1           fetch down final read byte
        moveq   #15,d0          ready for nibble
        asr.b   #1,d7
        bmi.s   clrint          there was no return, leave d1 as junk!
        bcc.s   andit
        st      d0
andit
        and.l   d0,d1
* We will clear the interrupt we've caused merely by talking to the IPC
clrint
        moveq   #pc.intri,d7    clear IPC interrupt
        or.b    sv_pcint(a6),d7
        move.b  d7,pc_intr-pc_ipcrd(a0) a0 set by setad
exit
        move    (sp)+,sr        reinstate interrupts
        movem.l (sp)+,reglist
        jmp     ss_noer(pc)

send_par
        ror.l   #2,d5           rotate approriate bit pair to 2 msbs
        btst    #30,d5          check for x1
        bne.s   zero            if bit 0 was set, send nothing
        bpl.s   four            if bit 1 was clear, just send nibble
        lsl.l   #8,d0           put up whole byte and make lsb zero
        subq.b  #8,d1           count two nibbles
        bra.s   check           check how we're doing

flush
        addq.b  #4,d1           form number of bits not in use
        lsl.l   d1,d0           shuffle active nibbles up to top
        or.l    d0,d1           put send nibbles into msb's
        lsr.b   #1,d1           make it into unused nibbles * 2
        sub.b   #6*2,d1         calculate negated active nibble count * 2
        bne.l   ip_rdwr         if non-zero (always?) go do it
        rts

        end
