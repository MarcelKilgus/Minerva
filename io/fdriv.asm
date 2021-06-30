* Finds driver information from a filename
        xdef    io_fdriv

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_ch'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_assert'

        section io_fdriv

* Note: this routine now imposes the following two constraints on directory
* device driver names, failing which, they will always result in err.nf.

* Firstly, they must be longer than one character (and less than 32768!). The
* exclusion of zero length names is needed as nfs_use in tk2 "hides" it's
* dd entry as a zero length name when it is not in use.

* Secondly, they must have bit 5 clear in all bytes. This excludes lowercase
* 'a' to 'z', uppercase ' ' to '«', digits and various other characters.

* When matching, the caller's characters have bit 5 cleared before the
* comparison, so the net result is a case insensitive match, but with various
* other characters treated as matching. A digit in the range '1' to '8' after
* the first character of the caller's name will invariably be expected to mark
* the exact end of the dd name part, and must be followed by an underscore.

* This syntax does allow in a few obscurities, but so far nobody has tried to
* produce a driver whose name contains anything but uppercase 'a' to 'z'.

* The original code had various bugs, including the fact that if one driver on
* the list was preceeded by one with a shorter name, it was never found!
* The above bug detected by Tony Tebby, when he got the network driver in front
* of another driver starting with an 'n'

* d0 -  o- negative error code
* d1 -  o- drive number
* d4 -  o- physical definition slot number
* d5 -  o- first vacant physical slot number
* a0 -ip - pointer to name
* a1 -  o- contents of physical definition slot
* a2 -  o- pointer to driver
* a4 -  o- address of physical definition slot

* Condition codes on return define the results:
* n: err.nf no driver found (d0 = err.nf, other regs above undefined)
* z: existing physical definition found (d0=0, d5 undefined, rest as above)
* ~n&~z: no physical definition yet present and:
*    d5=err.no if there is no free space for one (d0=0, d1/a2 set, rest undef)
*    d5=vacant slot number (d0=0, d1/a2 set, a4 is slot 0 address!, rest undef)

err_nf
        moveq   #err.nf,d0
        rts

io_fdriv
        moveq   #'_',d0         the requisit underscore and zero to msw
        moveq   #1,d4           driver name must be at least one char
* nb. nfs_use in tk2 hides as zero length name! so nobody else can. (lwr)
under
        addq.w  #1,d4           don't bother with 1st char, as that can't work
        cmp.w   (a0),d4         check offset against length of their name
        bge.s   err_nf          we've run out of name
        cmp.b   2(a0,d4.w),d0   have we found an underscore?
        bne.s   under           no - carry on looking
        subq.w  #1,d4           this is now the char count of the dd name

        moveq   #'8',d1         dd name must be followed by a digit '1' to '8'
        sub.b   2(a0,d4.w),d1   should be 7 to 0 for char '1' to '8'
        subq.b  #8,d1           now -1 to -8 for char '1' to '8'
        bcc.s   err_nf          wasn't '1' to '8' - can't use this name!
        neg.b   d1              make it into a proper drive number 1 to 8

        lea     sv_ddlst(a6),a2 get start of directory driver list
nxt_driv
        assert  0,ch_next
        move.l  (a2),d5         check for a next driver
        beq.s   err_nf          none left - not found
        move.l  d5,a2
        move.w  ch_drnam(a2),d0 this is the length of this dd name
        cmp.w   d0,d4           must match caller's number of characters
        bne.s   nxt_driv        name not right length, so skip it
nxt_char
        moveq   #-1-1<<5,d5     force upper case
        and.b   2-1(a0,d0.w),d5 next character
        cmp.b   2-1+ch_drnam(a2,d0.w),d5 is it the same
        bne.s   nxt_driv        no - try next driver
        subq.w  #1,d0           check next character if any left
        bne.s   nxt_char
* Note: we have d0.l = 0 from this point on, ready for ok return

* We now know the drive type (pointed to by a2) and the number (d1)

        moveq   #16-1,d4        check list of sixteen drives
        moveq   #err.no,d5      no hole yet
        lea     sv_fsdef+16*4(a6),a4 get address of top end of list

chk_driv
        tst.l   -(a4)           address of physical definition
        beq.s   set_hole
        move.l  (a4),a1
        cmp.b   fs_drivn(a1),d1 compare drive number
        bne.s   end_driv
        cmp.l   fs_drivr(a1),a2 compare driver
        bne.s   end_driv        all ok, everything is ready and slot found
        rts

set_hole
        move.l  d4,d5           save slot of hole
end_driv
        subq.l  #1,d4
        bpl.s   chk_driv
        moveq   #1,d4           say we didn't find an existing slot
        rts

        end
