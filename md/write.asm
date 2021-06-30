* All microdrive write bits
        xdef    md_wblok,md_write

        include 'dev7_m_inc_delay'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_vect4000'

        section md_write

* d0   s used by delay
* d1 c s counter of bytes to be read/written (call wblok only)
* d3   s checksum
* d4   s byte to be written
* d5   s inner loop counter
* d6   s bit number of control bit in cont register
* a0   s saved value of a1
* a1 cr  buffer pointer
* a2   s pointer to transmit register
* a3 c   pointer to microdrive control register
* a4   s subroutine return address

tdoff   equ     pc_tdata-pc_mctrl

md_write
        move.b  #pc.erase,(a3)  erase on
        delay   (3600-40)       wait
        move.l  a1,a0           08  save buffer pointer
        lea     4(sp),a1        16  set pointer to header
        moveq   #2-1,d1         08  ... of two bytes
        lea     wr_rec(pc),a4   16  return to write record
        bra.s   wr_init         18  ... when init and written header

wr_rec
        move.l  a0,a1           08  reset buffer pointer
        move.w  #$1ff,d1        16  ... record of 512 bytes
        moveq   #6-1,d5         08  preamble of 6+2 bytes
        lea     end_wr(pc),a4   16  return to exit
        bra.s   wr_inpre        18  ... when record written

end_wr
        moveq   #pc.read,d4     write off / erase off

exit
        delay   120             wait for bytes to go away
        move.b  d4,(a3)         turn off
        rts

md_wblok
        lea     end_wb(pc),a4   16  return to end_wb
        bra.s   wr_init         18  ... when we have initialised and written

end_wb
        moveq   #pc.erase,d4    write off / erase on
        bra.s   exit            after delay

wr_init
        moveq   #pc.write,d0    08  enable write
        move.b  d0,(a3)      12+08
        move.b  d0,(a3)      12+08
        moveq   #pc..txfl,d6    08  buffer full bit in microdrive read register
        lea     tdoff(a3),a2    16  pointer to transmit register

        moveq   #9,d5           08  10 byte preamble
wr_inpre
        moveq   #0,d4           08  ... of zero
wr_pream
        bsr.s   wbyte       102+72  write preamble bytes in a loop
        subq.b  #1,d5           08
        bge.s   wr_pream     12/18
        moveq   #-1,d4          08  two bytes of ff
        bsr.s   wbyte       102+72
        bsr.s   wbyte       102+72

        move.w  #$0f0f,d3       16  initialise checksum
        moveq   #0,d4           08  clear upper part of word
wr_loop
        move.b  (a1)+,d4     12+08  fetch next byte
        add.w   d4,d3           08  accumulate checksum
        bsr.s   wbyte       102+72  146-226 cycles 19.5-30.1 us since preamble
        dbra    d1,wr_loop   26/18  loop is 140-220 cycles 18.7-29.3 us

        move.w  d3,d4           08  write lsb first
        bsr.s   wbyte       102+72  136-208 cycles 18.1-27.7us since last write
        lsr.w   #8,d4           26  now msb
        bsr.s   wbyte       102+72
        jmp     (a4)            16

* Write a byte

wbyte
        btst    d6,(a3)      12+08  is it ready for byte?
        bne.s   wbyte        12/18
        move.b  d4,(a2)      12(08) move byte to transmit register
        rts                  32+32

* Single byte write including bsr (34+32): 102-172 cycles 13.6-22.9 us

* Critical time is write checksum to first byte of record preamble

* In wbyte     32+32
*  jmp (a4)    16
* In wr_rec    66
* In wr_rpet   42+32
* In wbytes    36
*     192+64=256 cycles 34.1 us

        vect4000 md_write

        end
