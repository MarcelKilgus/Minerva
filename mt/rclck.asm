* Reads, adjusts or sets the clock
        xdef    mt_rclck,mt_sclck,mt_aclck

        xref    ss_noer

        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_assert'

        section mt_rclck

* d0 -i o- trap value of d0 / 0
* d1 -i o- time to set or increment / current time
* d2/a0 destroyed

mt_rclck
mt_sclck
mt_aclck
        bsr.s   clock           read the clock
        assert  $13,mt.rclck,mt.sclck-1,mt.aclck-2
        asl.b   #6,d0           type of adjustment required?
        bpl.s   adjset          adjust or set
        move.l  d2,d1           read
exit
        jmp     ss_noer(pc)

adjset
        beq.s   set_ck          set
adjust
        cmp.l   (a0),d2         wait for second to tick over
        beq.s   adjust
        bsr.s   ck_read         read it again until stable
        add.l   d2,d1
set_ck
        sf      (a0)+           clear clock

        moveq   #%11110111-256,d0 start incrementing at ms byte
set_byte
        rol.b   #1,d0
        rol.l   #8,d1
        moveq   #0,d2           can't dbra on byte - have to use word
        move.b  d1,d2           take ls byte of set value
        bra.s   end_inc

inc_byte
        move.b  d0,(a0)         increment specified byte
end_inc
        dbra    d2,inc_byte     count increments

        ror.b   #2,d0           next byte flag
        bmi.s   set_byte        if not just done %11111101, carry on
        bra.s   exit

* d2 -  o- stable reading fom clock
* a0 destroyed

clock
        lea     pc_clock,a0     fetch clock address
ck_read
        move.l  (a0),d2         fetch time
        cmp.l   (a0),d2         has it changed?
        bne.s   ck_read         takes 12 cycles = 1.6 u seconds
        rts

        end
