* Microdrive read/verify facilities
        xdef    md_fsect,md_read,md_sectr,md_veril,md_verin

        xref    md_endgp

        include 'dev7_m_inc_delay'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_vect4000'

* The nominal time for a single byte on a microdrive is 40us. In the read/
* verify routines, we wish to cope with as wide a range of variation in tape
* drive speeds as we can. Two basic scenarios come up: a tape recorded on a
* slow drive being read back on a fast one, and visa versa. A nominal variation
* of 10% is documented, but as it works out, we can cope here with a variation
* in byte timings from 20us to 80us, i.e. a factor of two either way, which
* corresponds to worst case drives being 41% out of spec in opposing senses.

        section md_read

* General register usage
* d0 timer / used by end_gp/delay etc
* d1 counter of bytes to be read/written / file nr read
* d2 sector to be found (fsect)          / block nr read
* d3 checksum
* d4 byte read / checksum compare
* d5 loop counter (fsect)
* d6 bit number for read flag in control register
* d7 sector number
* a0 read / verify entry point
* a1 pointer to data buffer
* a2 pointer to read register
* a3 pointer to microdrive control register
* a4 alternative pointer to read register
* a5 used by fsect only - address for sector header

* Find and read a specified sector header

* d2 -ip - sector to be found (lsb)
* d7 -  o- last sector number found in lsb, rest zero (not if return+0)
* a1 -  o- 14(a5), if all ok
* a3 -ip - pointer to microdrive control register
* a5 -ip - pointer to 14 byte buffer to read sector header into
* d0-d1/d3-d6/a2/a4 destroyed
* return+0 failed, return+2 ok

md_fsect
        moveq   #0,d5           search up to 256 sectors for d2
find_lop
        move.l  a5,a1           put header into (a5)
        bsr.s   md_sectr        get sector
        rts
        bra.s   find_lop        bad sector look for another one
        cmp.b   d7,d2           found?
        beq.s   ret_ok
        addq.b  #1,d5           try next sector
        bcc.s   find_lop
        rts                     can't find sector

* Read next sector header

* d7 -  o- sector number in lsb, rest zero, only on good return
* a3 -ip - pointer to microdrive control register
* d0/d3-d4/d6/a2/a4 destroyed
* return+0 no gap found, return+2 bad sector, return+4 ok

md_sectr
        jsr     md_endgp(pc)    wait for end of gap
        rts
        addq.l  #2,(sp)         ... semi good return
        moveq   #14-1,d1        sector header is 14 bytes
        bsr.s   rblock          and read sector header
        bra.s   bad_sect
        cmp.b   #$ff,-14(a1)    ... but is it a sector header?
        bne.s   bad_sect
        moveq   #0,d7
        move.b  -14+1(a1),d7    get sector number
ret_ok
        addq.l  #2,(sp)         ... good return
bad_sect
        rts

* Read/verify has two returns

* d1 -  o- file number in lsb, rest zero
* d2 -  o- record number in lsb, rest zero
* a1 -i o- 512 byte block data to read or verify, updated past end if ok
* a3 -ip - pointer to microdrive control register
* d0/d3-d4/d6/a0/a2/a4 destroyed
* return+0 bad, return+2 ok

md_read
        lea     rblock(pc),a0
        bra.s   read_ver

md_verin
        lea     vblock(pc),a0
read_ver
        jsr     md_endgp(pc)    wait for end of gap
        rts                     get out if we couldn't find one
        move.l  a1,-(sp)        save block pointer
        clr.w   -(sp)           clean block header on stack
        move.l  sp,a1
        moveq   #2-1,d1         block header is 2 bytes
        bsr.s   rblock          and read block header
        bra.s   bad_blok        failed
        move.b  #pc.read,d1     set up pll reset byte
        move.b  d1,(a3)         reset pll
        delay   25              wait for a zero to clock through
        move.b  d1,(a3)         reset controller
        move.w  #512-1,d1       read 512 byte block
        move.l  2(sp),a1        restore a1
        jsr     (a0)            read / verify
        bra.s   bad_blok        failed - hmmm... why set d1/d2, as undef above
        addq.l  #2,6(sp)        change over to a good return
bad_blok
        moveq   #0,d1
        moveq   #0,d2
        move.b  1(sp),d2        funny motorola stack handling
        move.b  (sp)+,d1
        addq.l  #4,sp           remove buffer address
        rts

* d1 -i  - byte count less one
* a1 -i o- buffer address, updated past last byte
* a3 -ip - pointer to microdrive control register
* d0/d3-d4/d6/a2/a4 destroyed
* return+0 bad, return+2 ok

rblock
        moveq   #0,d4           upper part of data word
        bra.s   rvcomm

* Verify long block - has two returns

* a1 -i o- long (512+98) block data to be verified, if ok, updated past end
* a3 -ip - pointer to microdrive control register
* d0-d1/d3-d4/d6/a2/a4 destroyed
* return+0 verify failed, return+2 ok

md_veril
        jsr     md_endgp(pc)    wait for end of gap
        rts                     gap not seen
        move.w  #2+2+8+512+86-1,d1 long block used when formatting
        bsr.s   vblock          verify it
        rts                     verification failed
plustwo
        addq.l  #2,(sp)         good return
        rts

read_byt macro ; min 74, max 674 (d0=21-1, d0 * 30 in loop)
wait[.l]
        btst    d6,(a3)      12 * wait for bit set
        dbne    d0,wait[.l] 18/20 loop/ne or 26 on timeout
        beq.s   rvb_exit  18/12 get out now if we are too far off spec
        move.b  (a2),d4      12 * read byte, at least 44 cycles since flag set
        exg     a2,a4        10 toggle read address
        moveq   #21-1,d0      8 reset read timeout to one byte, half speed
        endm

verif
        cmp.b   (a1)+,d4     12+contention compare byte
        dbne    d1,rvloop 18/26 (or 20 = fall out on bad verify)
        bne.s   rvb_exit  18/12 give up if byte failed to verify

* Read checksum
* Time from last read or verify = 158 cycles 21.1 us max
* Time for the single loop = 126, so on average, 142 should be fine!
* Note d1 is equal to -1
checksum
        read_byt      ; (674)74 wait for next byte
        ror.w   #8,d4        26 move byte round
        addq.w  #1,d1         8 increment counter
        beq.s   checksum  18/12 go for other byte

        cmp.w   d4,d3           is checksum correct?
        beq.s   plustwo         yes, so go do return+2
rvb_exit
        rts

* d1 -i  - byte count less one
* a1 -i o- buffer address, updated past last byte
* a3 -ip - pointer to microdrive control register
* d0/d3-d4/d6/a2/a4 destroyed
* return+0 bad, return+2 ok

vblock
        moveq   #1,d4           upper part of data word
        ror.l   #1,d4           put flag in msb for verify
rvcomm
        move.w  #$0f0f,d3       set up checksum register
        moveq   #pc..rxrd,d6    check for read
        lea     pc_trak1-pc_mctrl(a3),a2 set up read addresses
        lea     pc_trak2-pc_mctrl(a3),a4
        move.w  #257-1,d0       wait for up to 1 ms before giving up 1st byte
rvloop
        read_byt      ; (674)74 get the next byte (7754 on very 1st byte)
        add.w   d4,d3         8 add byte to checksum
        tst.l   d4            8 read or verify
        bmi.s   verif     18/12 branch out for verify, so loop ends match up
        move.b  d4,(a1)+     12+contention store it
        dbra    d1,rvloop 18/26
        bra.s   checksum     18

* Read(verify) loop is >= 132(150) cycles. Bear in mind that the verify really
* must be occurring on the same hardware! It should be near perfect!
* In essense, we should be able to cope with a read data rate which is well
* over twice specification! (17.6us per byte).
* We also tolerate even greater factor slower data rates (97.6us per byte).
* These correspond to worst case drive speeds, in both senses, of over 50%.

* Actually, our worst case may crop up with a block header. If we just miss
* seeing the first data ready flag, and we must take the first checksum byte
* before the second comes up. (Or does buffering mean this is is no problem?)
* This will be 29(late)+132(data)+132(data)+158(1st checksum)=451 cycles, which
* must not exceed 3 byte periods. It is only just over 20us, still OK.

        vect4000 md_read,md_sectr,md_verin

        end
