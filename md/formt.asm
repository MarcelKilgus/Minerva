* Formats a microdrive medium
        xdef    md_formt

        xref    mm_alchp,mm_rechp
        xref    md_selec,md_desel,md_wblok,md_write,md_sectr,md_fsect,md_veril
        xref    ss_wser,ss_rser

        include 'dev7_m_inc_delay'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_hp'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_sv'

dvl     equ     5               device length (mdvn_)

nml     equ     10              medium name length

bdl     equ     512             block data length

wdcs macro m,l,n
wd setnum [m]<<8![l]
cs setnum (([m])+([l]))*([n])+$f0f
cs setnum ([cs]&255)<<8![cs]>>8&255
 endm

* Define workspace
        offset  0

shbeg ; sector header
        ds.b    1       $ff
sno     ds.b    1       sector number
        ds.b    nml     medium name
        ds.b    2       randow number
shend

blbeg ; block
        ds.b    1       file number
        ds.b    1       block number
        ds.b    2       checksum
blpre   ds.b    6+2     preamble (6 zeroes and 2 $FF's)
bldata  ds.b    bdl     block data
blcs    ds.b    2       checksum (embedded in the long block we format with)
bx      ds.b    84      extra bytes
blend

map     ds.b    bdl
        ds.b    2       for simpler scan

wsend

* Sector types (recorded as file number)

st_map  equ     $f8     map file number
st_free equ     $fd     verifified ok twice
st_grot equ     $fe     failed one or other of the verifies
st_bad  equ     $ff     not seen, or neighbour was not seen, on either verify

* We have a sum to do here... assume that we could actually have a full 256
* sectors validly written to a tape. This will allow us to create 226 ($E2)
* files, needing 29 directory sectors plus the map sector. Note that this
* implies that the above "special" file numbers are fine.

* A nasty thought: The way the format is done, when sector zero is written, we
* don't even expect the next block to be OK, as it's probably cut in half, so
* our "neighbour" verify wouldn't work, even if we did it.
* We could be just on the splice, meaning that, of all the sectors that might
* be dodgy, the map sector is the only one we don't check very strongly!

* At the risk of offending someone's obscure idea of verification, it might be
* terribly sensible to format 127 to 0, then 254 to 128. As we fail the format
* if we get less than 200 blocks anyway, this'll be fine. We could even decide
* to reject the format should we see any of sectors 127 to 123, because that
* would imply the tape was running far too slow. We'd finish up with tapes that
* always had 200..250 sectors.

        section md_formt

* d0 -  o- error code
* d1 -i o- number of medium to format / number of sectors good
* d2 -i o- number of sectors found (includes dodgy ones...)
* a1 -i  - pointer to medium name

err_iu
        moveq   #err.iu,d0
anrts
        rts

md_formt
        tst.b   sv_mdrun(a6)    is any drive running?
        bne.s   err_iu          yes - say in use
        move.l  d1,d7           save drive number
        move.l  a1,a4           save medium name
        moveq   #(hp_end+wsend+15)>>4,d1
        asl.w   #4,d1           allocate workspace
        jsr     mm_alchp(pc)
        bne.s   anrts
        lea     hp_end(a0),a5   set base of workspace proper

* Preset sector header
* We've gone back to writing sector 255, but we'll actually fail the format
* if we see it, or 254, after verify, as it means the tape's running too slow!
        move.l  a5,a0           set start of sector header
        subq.w  #1,(a0)+        flag ff, sector ff (use ff as format fail, lwr)
        moveq   #-dvl,d3
        add.w   (a4)+,d3        get number of characters after mdvn_
        addq.l  #dvl,a4         skip past device part
        moveq   #nml-1,d1       copy/pad name chars
put_name
        moveq   #' ',d2         pad with blanks
        subq.w  #1,d3
        blt.s   put_char
        move.b  (a4)+,d2        get character of name
put_char
        move.b  d2,(a0)+
        dbra    d1,put_name
        move.w  sv_rand(a6),(a0)+ and random number

* Preset format block
 wdcs st_free 0 1
        move.l  #[wd]<<16![cs],(a0)+ empty / block 0 / checksum
        addq.l  #bldata-blpre-2,a0 preamble mainly zeroes
        subq.w  #1,(a0)+        finishing with 2 bytes of ones for sync
        move.w  #(blend-bldata)/2-1,d1 fill data and extra bytes
 wdcs $aa $55 bdl/2
fil_mem
        move.w  #[wd],(a0)+
        dbra    d1,fil_mem
        move.w  #[cs],blcs(a5)

* Now start the format

        move.w  d7,d1           restore drive number
        lea     pc_mctrl,a3     set address of microdrive control register

        moveq   #pc.mdvmd,d0    set microdrive mode
        jsr     ss_wser(pc)     and wait for RS232 to complete
        move    sr,-(sp)        save current interrupt level
        or.w    #$0700,sr       disable interrupts
        jsr     md_selec(pc)    select drive
        delay   500000          wait half a second

        move.b  #pc.erase,(a3)  erase on
write_lp
        move.l  a5,a1           08    reset pointer
        moveq   #shend-shbeg-1,d1 08  write sector header
        delay   (2840-85)       gap allows for jsr and final wait
        jsr     md_wblok(pc)
        move.w  #blend-blbeg-1,d1 16 write specially long block
        delay   (2840-80)       gap allows for jsr and final wait
        jsr     md_wblok(pc)
        subq.b  #1,sno-map(a1)  24+16 next sector number
        bcc.s   write_lp        12/18 last sector is 0
        move.b  #pc.read,(a3)   erase off

* Now verify

        clr.l   -(sp)           clear counts of sectors
        moveq   #-1,d5          two counts of 255 (reduced by one by lwr)
ver_loop
        subq.b  #1,d5
        bcs.s   err_fmt1
        move.l  a5,a1
        jsr     md_sectr(pc)    find sector
err_fmt1
        bra.s   err_fmt2        no signal
        bra.s   ver_loop        not a sector header

        jsr     md_veril(pc)    verify long block
        bra.s   ver_loop        bad block

        add.w   d7,d7           address of entry in map
        addq.b  #1,0(a1,d7.w)   check sector flag
        blt.s   err_fmt2        horrid if we've already seen it twice! lwr
        subq.b  #2,0(a1,d7.w)   decrement sector flag
        move.l  d7,d2           is this sector 0? (and clear msw of d2)
        bne.s   ver_loop        no - carry on
        lsr.w   #8,d5           was this first time round?
        bne.s   ver_loop        once round again

* All sectors verified up to twice - check the map (a1 is pointing at it)
* Blot out sectors on either side of a bad sector. Pretend 256 is bad (lwr)

        add.w   #bdl-4,a1       point to entries 254 and 255 of map
        tst.l   (a1)+           did we see either of sectors 254 or 255?
        bne.s   err_fmt2        if so, the tape's running disastrously slow!
chk_bad
        swap    d7              roll the previous flag
        move.w  -(a1),d7        is this a bad sector?
        asr.w   #1,d7           remember it as $ffxx if it's ok, $00xx if bad
        and.l   d7,(a1)         zap neigbours of un-seen sectors
        subq.b  #1,d5
        bne.s   chk_bad         test all sectors (note extra 2 bytes on map)

* Now convert to proper flags and count them up

chk_loop
        subq.b  #1,(a1)         make bad sector ff, dodgy fe, good fd
        bcs.s   chk_end         bad
        moveq   #1,d7
        and.b   (a1),d7         which is it? (good:d1=1, dodgy:d1=0)
        add.w   d7,(sp)         good, increment count of good sectors
        move.b  d5,d2           save highest sector number
chk_end
        addq.l  #2,a1           move to next entry in map
        addq.b  #1,d5
        bne.s   chk_loop        beyond 255?

        addq.l  #1,d2           total sectors = highest + 1
        add.l   d2,(sp)         we made sure msw was zero earlier
        cmp.w   #200,(sp)       how many good blocks?
        blt.s   err_fmt2        fail if less than 200

* Check for number of good sectors = total number of sectors, as this implies
* the splice hasn't been seen! (Or by shear coincidence, was just after sector
* zero, which is just about the worst place it could be!)

        cmp.w   (sp),d2         check it
        beq.s   err_fmt2        fail format if no bad 'uns

* Write map sector

        moveq   #st_free-256,d1
        lea     map(a5),a1      reset to start of map
        cmp.b   (a1),d1         is sector zero good?
        bne.s   err_fmt2        no - that's a disaster
        subq.b  #st_free-st_map,(a1) set sector zero to special file
        subq.b  #8,d2           leave a little bit of space before directory
        add.w   d2,d2           address table in words
chk_free
        subq.w  #2,d2           down one
        cmp.b   0(a1,d2.w),d1   vacant ?
        bne.s   chk_free
        clr.b   0(a1,d2.w)      set file 0
        move.w  d2,bdl-2(a1)    and say where it is (sector 255 slot)
        lsl.w   #8-1,d2         tuck directory sector number into msb
putit
        jsr     md_fsect(pc)    find the sector
err_fmt2
        bra.s   err_fmt3
        lea     map(a5),a1      reset to start of buffer
        move.w  (a1),-(sp)      first word holds file/block (dir = 0/0)
        jsr     md_write(pc)
        addq.l  #2,sp
        moveq   #0,d7           good return
        lsr.w   #8,d2           have we written the directory yet?
        beq.s   desel           yes - all done

* Write empty directory

clr_dir
        clr.l   -(a1)           clear directory (we should have time for this)
        addq.b  #256*4/bdl,d7
        bne.s   clr_dir
        moveq   #64,d1
        move.l  d1,(a1)         set length
        bra.s   putit           write directory

err_fmt3
        moveq   #err.ff,d7      format failed
desel
        jsr     md_desel(pc)    deselect drive
        lea     -hp_end(a5),a0  return space used
        jsr     mm_rechp(pc)
        jsr     ss_rser(pc)     re-enable rs232
        movem.w (sp)+,d1-d2     get good/total sector counts
        move    (sp)+,sr        reinstate interrupts
        move.l  d7,d0           set error return
        rts

        end
