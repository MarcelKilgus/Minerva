* General routines for file load/save etc.
        xdef    bp_close,bp_copy,bp_copyn,bp_delee,bp_dir,bp_exec,bp_execw
        xdef    bp_formt,bp_fopin,bp_lbyts,bp_open,bp_openn,bp_openw
        xdef    bp_save,bp_sbyts,bp_sexec

        xref    bp_chan,bp_chnew,bp_chnid,bp_listd,bp_rdchk
        xref    ca_etos,ca_gtlin,ca_putss
        xref    cn_itod
        xref    mm_mrtoa
        xref    ut_err

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_io'
        include 'dev7_m_inc_fs'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_md'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_vect4000'

        section bp_files

* Load and start program
* EXEC{_W}<filename>{,#<chan>}...{;<parameter string>}

bp_execw
        moveq   #-1,d7          wait on activation
bp_exec
        moveq   #$70,d1
        and.b   -7(a6,a5.l),d1
        bne.s   err_bpne        mustn't have any trailing delimiter
        tst.b   1(a6,a3.l)
        bmi.s   err_bpne        mustn't have hash before 1st parameter
        addq.l  #8,a3           forget filename for a while
        moveq   #$50,d5         mask for last param and flag no string
        moveq   #0,d6           extra data space needed for parameters
        cmp.l   a3,a5
        blt.s   err_bpne        must have at least one parameter
        move.l  a3,a0
        beq.s   chnent
        tst.b   -7(a6,a5.l)
        bmi.s   chnent          no hash allowed on string
        and.b   -15(a6,a5.l),d5 delimiter before last param a ';'? (no nulls)
        bne.s   chnent          no, so no string
        subq.l  #8,a5           string will be put waiting on stack
        move.l  a5,a3
        bsr.l   bp_fnamx
        bne.s   rts9            ouch! string didn't work out!
        move.w  0(a6,a1.l),d6
        addq.l  #1,d6
        bclr    d0,d6           round up string length
        move.l  a0,a3
        bra.s   chnent

* N.B. As we have already verified that the last delimiter is not a comma...
chnloop
        moveq   #$60,d0         won't find a null delimiter, they don't happen
        and.b   -7(a6,a0.l),d0  must be a comma ($10) before the #<channel>
        bne.s   err_bpne
        addq.l  #4,d6           increase extra data space required
        addq.l  #8,a0           move to next param
chnent
        tst.b   1(a6,a0.l)      check for hash before parameter
        bmi.s   chnloop
        cmp.l   a0,a5           we should have done all the parameters by now
err_bpne
        bne.l   err_bp
        jsr     ca_gtlin(pc)    get them all as long ints (keeps bv_rip nice)
        move.w  d3,a4           save channel count
        beq.s   cvtent
rts9
        rts

cvtloop
*       tst.w   0(a6,a1.l)      (lets no be too pedantic here)
*       bne.s   err_bpne
        move.w  2(a6,a1.l),d1
        jsr     bp_chnid(pc)    convert them all to channel ids
        bne.s   rts9
        move.l  a0,0(a6,a1.l)
        addq.l  #4,a1
cvtent
        dbra    d3,cvtloop
        subq.l  #8,a3           stack data ready, go back to first param
        bsr.s   wantload        open read only and get header (d2=length)
        bne.s   rts9
        moveq   #err.bp,d0
        subq.b  #1,md_detyp(a6,a1.l) is it an executable file?
        bne.s   close_l
        moveq   #mt.cjob,d0     yes, create job
        moveq   #-1,d1          we are the parent
        move.l  md_deinf(a6,a1.l),d3 get length of data space
        add.l   d6,d3           add our extra parameters length
        move.l  a0,a3           save chan
        bsr.s   trap1z          (a1=0, start at beginning)
        move.l  a0,a1           base address in a1 for load
        exg     a0,a3           put back chan, save job base
        bne.s   close_l
        move.l  d1,a2           save job id
        bsr.s   doload          and load file
        bne.s   rjob            did read fail?
        sub.l   d6,jb_a0+7*4-jb_end(a3) adjust the stack pointer
        move.l  jb_a0+7*4-jb_end(a3),a0 get the stack pointer
        move.w  a4,(a0)+        store channel count
        tst.w   d5
        bne.s   lenok           if no string, zero string len already on stack
        addq.l  #2,d6           include string length word in amount to move
lenok
        move.l  bv_rip(a6),a1
        move.w  0(a6,a1.l),d5   we have to skip the device/file name
        addq.l  #3,d5
        bclr    d0,d5
        add.l   d5,a1
        move.l  d6,d1
        jsr     mm_mrtoa(pc)    copy all our info into job's stack
        moveq   #mt.activ,d0    activate job
        move.l  a2,d1           reload job id
        moveq   #32,d2          priority
        move.w  d7,d3           set timeout (0 for exec, -1 for exec_w)
        bsr.s   trap1           any errors?
        bne.s   rjob            yes, remove job
        tst.w   d7              did we wait?
        bne.s   rts0            yes, done
        moveq   #mt.susjb,d0    suspend job
        moveq   #-1,d1          myself
        moveq   #50/2,d3        wait half a sec to give new job a chance
trap1z
        sub.l   a1,a1           clear flag address
trap1
        trap    #1
        tst.l   d0
rts0
        rts

rjob
        move.l  d0,d4
        moveq   #mt.rjob,d0     could not load or activate
        move.l  a2,d1           ... remove the job
        trap    #1
        move.l  d4,d0           restore error key
        rts

* d0 -  o- error code
* d2 -  o- file size
* a0 -  o- channel id
* a3 -i o- start of parameters, eight added
* a5 -ip - end of parameters
* d1/d3-d4/a1 destroyed

wantload
        bsr.l   bp_fopin        open file for loading
        bne.s   rts1
        bsr.s   gethdr          get header and put length in d2
close_l
        bne.s   close_s
rts1
        rts

* d0 -  o- error code
* d2 -  o- file size
* a0 -i  - channel id
* d1/d3/a1 destroyed

gethdr
        moveq   #fs.headr,d0    fetch the header
        moveq   #md_denam,d2
        bsr.l   trp3b           into the buffer
        move.l  bv_bfbas(a6),a1
        move.l  md_delen(a6,a1.l),d2 get file length
        tst.l   d0
        rts

* load bytes: LBYTES<filename>,<address>

bp_lbyts
        moveq   #1,d5           just one parameter wanted
        bsr.s   gtlin           get start address
        bsr.s   wantload        (d2=length)
        move.l  (sp)+,a1        get start address
        bne.s   rts1
doload
        moveq   #fs.load,d0
        bsr.l   trap3
close_s
        bra.s   close

* Get long integers after 1st parameter
* If no error is reported, d1 is also returned on the top of the stack

* d0 -  o- error code
* d1 -  o- 2nd parameter (verified as even)
* d2 -  o- 3rd parameter (default 0)
* d5 -i  - maximum number of parameters required
* d7 -i o- default 6th parameter / 6th parameter
* a0 -  o- 4th parameter (default 0)
* a2 -  o- 5th parameter (default 0)
* a3 -ip - start of parameters
* a5 -i o- end of parameters (output as 8(a3))
* d3-d4/d6/a4 destroyed

gtlin
        move.l  (sp)+,a4
        addq.l  #8,a3           step past 1st parameter
        cmp.l   a5,a3
        bge.s   err_bp1         minimum two parameters
        jsr     ca_gtlin(pc)    get arguments
        bne.s   rts1
        cmp.l   d3,d5
        bcs.s   err_bp1
        lsl.l   #2,d3
        add.l   d3,bv_rip(a6)
        movem.l 0(a6,a1.l),d1-d2/a0/a2/a5 start{,length{,data{,xtra{,type}}}}
        lsr.l   #1,d3
        jmp     zaparg-5*2(pc,d3.w)
        moveq   #0,d2           start,0,0,0,d7
        sub.l   a0,a0           start,length,0,0,d7
        sub.l   a2,a2           start,length,data,0,d7
        move.w  d7,a5           start,length,data,xtra,d7
zaparg                         ;start,length,data,xtra,type
        move.w  a5,d7
        btst    d0,d1
        bne.s   err_bp1
        move.l  a3,a5
        subq.l  #8,a3           return to 1st parameter
        move.l  d1,-(sp)
        jmp     (a4)

err_bp1
        bra.s   err_bp

* Save executable code or bytes:
* SEXEC|SBYTES<filename>,<address>{,<length>{,<data>{,<extra>{,<acc/type>}}}}

bp_sexec
        moveq   #1,d7           file type 1
bp_sbyts
        moveq   #5,d5           at most five arguments
        bsr.s   gtlin           get arguments
        move.l  bv_bfbas(a6),a1
        assert  md_delen,md_deacs-4,md_detyp-5,md_deinf-6
        movem.l d7/a0/a2,md_delen+2(a6,a1.l) access,type,data,xtra
        move.l  d2,md_delen(a6,a1.l) length
        blt.s   bp_pop          don't allow silly lengths (sexec<10 is silly!)
        bsr.s   fopnew
        bne.l   poprts
        moveq   #fs.heads,d0    set header
        bsr.s   trp3b
        move.l  (sp)+,a1
        bne.s   close
        moveq   #fs.save,d0     save file in toto
        bsr.s   trap3
        bra.s   close           close the file

* File delete: DELETE<filename>

bp_delee
        bsr.s   bp_fname
        bne.s   rts2            couldn't get filename parameter
        cmp.l   a3,a5
        bne.s   err_bp          wasn't just one parameter
        moveq   #io.delet,d0
        bra.s   trp2me

* Saves current basic program in ASCII: SAVE<filename>{,<start>{to<end>}}

bp_save
        bsr.s   fopnew          save on a new file only
        bne.s   rts2
        jsr     bp_listd(pc)    and continue just as list
close
        move.l  d0,d4           save error flag
close_n
        moveq   #io.close,d0    and close file
        trap    #2
        move.l  d4,d0
rts2
        rts

fopnew
        moveq   #io.new,d4
        bra.s   fopen

bp_pop
        addq.l  #4,sp           remove return address
err_bp
        moveq   #err.bp,d0
        rts

trp3b
        move.l  bv_bfbas(a6),a1 use basic buffer
trp3r
        trap    #4              next trap is relative a1
trap3
        moveq   #-1,d3
        trap    #3
        bra.s   tstrts3

* Get a file name
* d0 -  o- error code
* a1 -  o- ri pointer to file name string (if d0=0)
* a3 -i o- name table entry to look at (update by 8 if a3<a5)
* a5 -ip - top of name table entries (if <= a3, bad param, skipped by fnamx)

bp_fname
        cmp.l   a5,a3           is there a name
        bge.s   bp_pop          nope, that's silly
bp_fnamx
        movem.l d1-d2/a4-a5,-(sp)
        jsr     bp_rdchk(pc)    could it be given a value?
        movem.w 0(a6,a3.l),d0-d2 grab name table bits
        addq.l  #8,a3           update a3 now
        bne.s   fnam_nam        can't assign, so we certainly need its name
        asl.w   #7,d0           is it unset? (it's never -1 in msb)
        bvc.s   fnam_nam        yes, unset variable, so use its name
        lsl.w   #16-7-2,d0      is it a (sub)string? (bit 2 should have been 0)
        or.w    d2,d0           and does it truly have a value?
        bmi.s   fnam_nam        fp/int or no value offset, so we use its name
        move.l  a3,a5           copy to a5 for ca_etos
        jsr     ca_etos(pc)     force string value onto ri stack
        bra.s   fnam_pop        done

fnam_nam
        moveq   #err.bn,d0
        asl.l   #3,d1           make offset to original nt entry
        bmi.s   fnam_pop        user boobed - nt ref was negative
        add.l   bv_ntbas(a6),d1 original nt entry
        move.l  bv_nlbas(a6),a4 name list base
        add.w   2(a6,d1.l),a4   point at name
        moveq   #0,d1
        move.b  0(a6,a4.l),d1   no of chars in name (byte!)
        addq.l  #1,a4           beg of chars for ca_putss
        jsr     ca_putss(pc)    put the variable's name on the ri stack
fnam_pop
        movem.l (sp)+,d1-d2/a4-a5
        rts

* Open a file

* d0 -  o- error code
* d1 -  o- own job id
* d4 -ip - open type (set to io.share at bp_fopin)
* a0 -  o- channel id
* a3 -i o- start of parameters (8 added)
* a5 -ip - end of parameters
* d3/a1 destroyed

bp_fopin
        moveq   #io.share,d4    open read only file
fopen
        bsr.s   bp_fname
        bne.s   rts3
        move.l  d4,d3           put open key in correct register
trp_open
        moveq   #io.open,d0     open channel
trp2me
        moveq   #-1,d1          for this job
trp2r
        move.l  a1,a0
        trap    #4              a0 relative to a6
        trap    #2
tstrts3
        tst.l   d0
rts3
        rts

* Check for optional #chan followed by filename
* Skips return address on any error, leaving just d0 set to error code
* d0 -  o- 0
* d1 -  o- #chan number
* d5 -  o- #chan channel id (default #1)
* a1 -  o- ri stack pointer to filename string
* a2 -  o- pointer to #chan block
* a3 -i o- start of parameters (16 added)
* a5 -ip - end of parameters

ch_fname
        jsr     bp_chan(pc)     get channel
        bne.s   poprts
        move.l  a0,d5           save id
        bsr.s   bp_fname        get file name
        bne.s   poprts
        cmp.l   a5,a3           that should have been the last parameter
        beq.s   rts3
        moveq   #err.bp,d0
poprts
        addq.l  #4,sp           discard return
        rts

* Directory listing: DIR{#<chan>,}<filename>

bp_dir
        bsr.s   ch_fname        get optional #n and file name
        moveq   #io.dir,d3      open with directory key
        bsr.s   trp_open
        bne.s   rts3
        move.l  a0,a5           save directory channel

        moveq   #fs.mdinf,d0    get information about the medium...
        bsr.l   trp3b           ... into the basic buffer
closene
        bne.l   close
        move.l  d1,-(sp)        save the sector counts
        move.l  bv_bfbas(a6),a1 write out the medium name
        moveq   #10,d2
        bsr.s   w_s_nl
        move.l  (sp)+,d1
        moveq   #0,d4           preset the saved error flag
        bsr.s   sector          write the sector counts
dir_loop
        move.l  a5,a0
        bne.s   closene
        tst.b   bv_brk(a6)      is there a break?
        bpl.l   close           yes - get out now (leaving break set)
        moveq   #io.fstrg,d0    now fetch the directory entries
        moveq   #md_deend,d2
        bsr.l   trp3b           into the basic buffer
        bne.l   close_n
        tst.l   md_delen-md_deend(a6,a1.l)
        beq.s   dir_loop        ignore zero length files
        move.w  md_denam-md_deend(a6,a1.l),d2  set the character count
        lea     md_denam+2-md_deend(a1),a1 go to the start of the name
        bsr.s   w_s_nl          write out with newline
        bra.s   dir_loop

* Format medium: FORMAT{#<chan>,}<filename>

bp_formt
        bsr.s   ch_fname        get optional #n and file name...
        moveq   #io.formt,d0    ... and format
        bsr.s   trp2r
        bne.s   rts4
        swap    d1
        move.w  d2,d1           set up like md.inf
sector
        move.l  bv_bfbas(a6),a1
        move.l  d1,0(a6,a1.l)
        lea     4(a1),a0
        jsr     cn_itod(pc)     convert first one
        move.b  #'/',0(a6,a0.l)
        addq.l  #1,a0
        jsr     cn_itod(pc)     convert second one
        bsr.s   w_strg          write them both out
        moveq   #err.sc,d0
        jsr     ut_err(pc)      now write ' sectors'
        moveq   #0,d0           ensure a correct return
rts4
        rts

w_s_nl
        lea     1(a1,d2.w),a0
        move.b  #10,-1(a6,a0.l) tack a newline on the end of the string
w_strg
        move.w  a0,d2
        sub.w   a1,d2
        moveq   #io.sstrg,d0    write string
        move.l  d5,a0           output channel
trp3r1
        bra.l   trp3r

* Copy file to file (with or without header): COPY{_N}<fromfile>,<tofile>

bp_copyn
        moveq   #-1,d7          set length unknown
bp_copy
        bsr.l   bp_fopin        set source...
        bne.s   rts4
        move.l  a0,d5
        bsr.l   fopnew          ... and destination
        bne.s   close_1
        subq.l  #1,d7           was header required (d7.l now -1 or -2)
        bcc.s   copy_lop        if it went to -2, we're not doing the header
        exg     a0,d5
        bsr.l   gethdr          read header into buffer (d2=length)
        exg     a0,d5
        bne.s   copy_lop        if no header from this device, carry on
        move.l  d2,d7           set length of file...
        moveq   #fs.heads,d0    ... and set header
        bsr.s   trp3r1
copy_lop
        move.l  bv_bfbas(a6),a1 set buffer base address
        move.l  bv_bfbas+8(a6),d2 use next base as top of area
        sub.l   a1,d2           buffer length (*** we assume this is < 65536!)
        exg     a0,d5           get the right file id
        cmp.l   d7,d2           is buffer greater than remaining number
        bls.s   copy_try
        tst.l   d7              is file length known (and greater than 0)
        ble.s   copy_try
        move.l  d7,d2           just fetch the remaining number of bytes
copy_try
        tst.b   bv_brk(a6)      is there a break?
        bpl.s   close_2         yes - get out now (leaving break set)
        moveq   #io.fstrg,d0    fetch as many bytes as possible
        moveq   #err.nc-err.ef,d3 don't hang about long (was 5, now 9)
        trap    #4
        trap    #3
        move.l  d0,d2
        beq.s   copy_w          no problems, go write it out
        addq.l  #-err.nc,d2
        beq.s   copy_w          not complete, go write it out
        add.l   d3,d2
        bne.s   close_2         if not eof, bad error
        moveq   #0,d0           we expected eof eventually
        tst.w   d1              if eof and no bytes read, we've finished
        beq.s   close_2
copy_w
        moveq   #io.sstrg,d0    write as much as we have read
        move.w  d1,d2
        exg     a0,d5
        bsr.l   trp3b
        bne.s   close_2
        sub.l   d2,d7           how many left (top end of d2 is be 0)
        bne.s   copy_lop        if any bytes left, fetch them
close_2
        bsr.s   close_b         close one file...
close_1
        exg     a0,d5           ... and the other
close_b
        bra.l   close

* Close channels: CLOSE{#<chan>{,#<chan>}...}
* No parameters = close all channels above #2

bp_close
        moveq   #3,d1           ready to close #3 and above
        cmp.l   a3,a5           are there any parameters at all?
        beq.s   clall           no, so close #3 and all above
cllist
        bsr.s   opclose         close a channel from the list
        bne.s   rts5            any problem (other than not open) is bad
        cmp.l   a3,a5           check if any more parameters left
        bne.s   cllist          carry on to end of list
        rts

clthis
        bsr.s   clblot          wipe out id in slot and close the channel
clnext
        addq.l  #1,d1
clall
        jsr     bp_chnid(pc)    check this # channel
        beq.s   clthis          a real, open slot, so close it
        subx.l  d0,d0           is there actually a closed slot here?
        bmi.s   clnext          yes, keep going
        rts

opclose
        cmp.l   a3,a5           check for at least one parameter
        ble.s   err_bp2
        tst.b   1(a6,a3.l)      must be preceeded by a hash
        bpl.s   err_bp2
        jsr     bp_chan(pc)     read the channel no & see if it's there
        bne.s   chn_err         wrong number or channel not open
clblot
        moveq   #-1,d2
        move.l  d2,0(a6,a2.l)   blot out the ch id in the list
        bra.s   close_b         and close it in reality

err_bp2
        moveq   #err.bp,d0
chn_err
        addq.l  #-err.no,d0     channel not open is ok
        beq.s   rts5
        subq.l  #-err.no,d0
rts5
        rts

* Open a channel: OPEN|OPEN_IN|OPEN_NEW#<chan>,<filename>{,<opentype>}

bp_openw
        moveq   #io.new-io.share,d7
bp_openn
        addq.b  #io.share,d7
bp_open
        assert  0,io.old
        bsr.s   opclose         run a check on the channel
        bne.s   rts5
        move.l  d7,d4           save open type
        move.l  d1,d7           save #chan
        addq.l  #8,a3
        cmp.l   a5,a3
        beq.s   opnorm          normally just one parameter will be given
        jsr     ca_gtlin(pc)    if another is present, take it as open code
        bne.s   rts5
        move.l  0(a6,a1.l),d4
        subq.l  #8,a5
opnorm
        subq.l  #8,a3
        bsr.l   fopen
        bne.s   rts5
        move.l  d7,d1           restore #chan
        jmp     bp_chnew(pc)

        vect4000 bp_fname

        end
