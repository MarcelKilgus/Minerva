* Rename a file on a microdrive
        xdef    dd_mdvrn

        xref    ut_cstr
        xref    dd_mdvcd,dd_mdvrr

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_md'

blkbits equ     9

        section dd_mdvrn

* A problem child, this rename call... we have the rename string with the
* "mdvn_" still on the front. This means it's not convenient for ut_cstr.
* I don't think we're able to mess with the name in our channel, as multitask
* operation could screw up. (Well, it can anyway... as we change the name,
* conceivably someone else can change it simultaneously). Also, there's no
* guarantee we could mess with the user's copy, it could even be ROM!

* There are two reasonable courses of action one can take:

* Firstly, we could try nesting down a level, and doing an open.new on the
* user's filename. If it works, we then exchange the names and close the silly
* one. This could be enhanced by a special access code, maybe? Doubtfull.

* Secondly, one could scan the directory here, but keep shuffling the name read
* in to prepend the "mdvn_". This sounds pretty tacky, but it looks like the
* way we'll have to do it. It's only an error check, after all.

* The update date is no longer altered by a rename, per se.

* d0 -  o- error code
* a0 -ip - channel definition
* a1 -i  - requested new name, with byte count word prefix
* a2 -ip - physical definition
* a3 -i  - driver definition
* d1-d3/d5/d7/a4 destroyed

dd_mdvrn
        assert  fs_filnr,fs_nblok-2,fs_nbyte-4,fs_eblok-6,fs_ebyte-8
        lea     fs_filnr(a0),a4
        move.w  (a4),-(sp)      save file number
        clr.w   (a4)+           file number zero is the directory
        move.l  (a4),-(sp)      save current position
        clr.l   (a4)+           current position zero
        move.l  (a4),-(sp)      save end position
        moveq   #fs.hdlen,d2    we want the length of the directory
        move.l  d2,(a4)         just say the directory is a single entry
        lea     ch_end+ch_drnam(a3),a3
        move.w  (a3),d5
        addq.w  #2,d5
        movem.l d5/a0-a1/a6,-(sp) keep extra and caller's new name + cstr regs

* The stack is now loaded up with lots of goodies, start verifying name.

        moveq   #err.bn,d0
        sub.w   (a1)+,d5        is their name too short ...
        add.w   #fs.nmlen,d5    ... or too long?
        bcc.s   done            (note, we don't allow null name length)
        move.w  (a3)+,d5
nloop
        moveq   #-1-32,d1
        and.b   (a1)+,d1
        cmp.b   (a3)+,d1
        bne.s   done            prefix didn't match our driver name
        subq.w  #1,d5
        bne.s   nloop
        moveq   #'0',d1
        add.b   fs_drivn(a2),d1
        sub.b   (a1)+,d1        must match drive number
        bne.s   done
        cmp.b   #'_',(a1)       must match underscore
        bne.s   done

* That's the easy checks over with. Now we must scan the directory.

        bsr.s   rd_ent
        bne.s   done
        move.l  fs_spare(a0),d7
        lsl.l   #16-blkbits,d7
        lsr.w   #16-blkbits,d7
        move.l  d7,(a4)         set true end of directory
        subq.l  #4,a4           point at current location

scan
        moveq   #md_denam,d2    skip a bit
        add.l   d2,(a4)
        moveq   #2,d2           read name length
        bsr.s   rd_ent
        bne.s   done
        movem.l (sp),d5/a0/a3
        add.w   d5,-(a1)        add extra to file name length
        move.w  (a1)+,d1
        cmp.w   (a3)+,d1        it must now match caller's length
        bne.s   tweak           (don't need to be so precise, compare fails)
fillup
        move.b  (a3)+,(a1)+     copy prefix from caller's buffer
        subq.b  #1,d5
        bne.s   fillup
tweak
        moveq   #fs.hdlen-2-md_denam,d2 read rest of entry
        bsr.s   rd_more
        bne.s   done
        movem.l (sp),d5/a0-a1
        moveq   #1,d0           comparison type
        sub.l   a6,a6           base register
        lea     fs_spare(a0),a0
        jsr     ut_cstr(pc)
        movem.l (sp),d5/a0/a3/a6
        beq.s   err_ex
        cmp.l   (a4),d7
        bne.s   scan
        moveq   #0,d0
        bra.s   done

* Routines to read/write data

rd_ent
        lea     fs_spare(a0),a1
rd_more
        moveq   #io.fstrg,d0
mdvrr
        jmp     dd_mdvrr(pc)

* We get here once we have decided what to do. Restore the file header first.

err_ex
        moveq   #err.ex,d0
done
        movem.l (sp)+,d5/a0/a1/a6
        move.l  (sp)+,4(a4)
        move.l  (sp)+,(a4)
        move.w  (sp)+,-2(a4)
        tst.l   d0              did we ok the rename?
        bne.s   rts0            no - return the error

* We're going to (try to) change the name. It's convenient to put it in the
* channel first, as we then only need a single write to send it out.
* This also means we can pad out the entry with nulls, like it should be.
* The drawback is that we might then find we can't write the file! Ho hum. lwr.

        lea     fs_fname+2+fs.nmlen(a0),a3
        moveq   #fs.nmlen/2,d0
zap
        clr.w   -(a3)           wipe out the old name
        dbra    d0,zap

        move.w  (a1)+,d0        get new length
        sub.w   d5,d0           correct length
        add.w   d5,a1           skip drive bit
        move.w  d0,(a3)+        store the new name length
newnam
        move.b  (a1)+,(a3)+     put the new name in the channel
        subq.w  #1,d0
        bne.s   newnam

* Now write it to the file header. we will presrve the file update state.

        move.b  fs_updt(a0),d5  save update flag
        move.l  (a4),d7         pick current back up
        lea     fs_fname(a0),a1
        moveq   #md_denam,d2
        move.l  d2,(a4)         that's the bit we'll alter
        moveq   #2+fs.nmlen,d2
        moveq   #io.sstrg,d0
        bsr.s   mdvrr
        move.l  d7,(a4)         reset current location
        move.b  d5,fs_updt(a0)  restore update flag

        tst.l   d0
        bne.s   rts0            ouch! that's not nice! channel already changed!
        jmp     dd_mdvcd(pc)    this will copy it to the directory

rts0
        rts

        end
