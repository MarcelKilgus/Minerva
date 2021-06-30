* System initialisation after RAM test
        xdef    ss_init

        xref    mt_cj0
        xref    md_desel
        xref    sb_start
        xref    ss_jtag,ss_list,ss_rj0
*****        xref.l res_code

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_bt'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_mc'
        include 'dev7_m_inc_pc'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_assert'

* Define sizes of table entries, etc
jtb     equ     2       bits per job table entry
ctb     equ     jtb     bits per channel table entry
xtb     equ     4       bits per combined job/channel table entry
cpj     equ     (1<<xtb-1<<jtb)>>ctb approximate channels per job (3)
sbb     equ     9       bits per slave block
sbl     equ     1<<sbb  size of a slave block
btb     equ     3       bits per slave block table entry
        assert  bt_end,1<<btb

bas_allc equ 2*sbl initial basic allocation (jb_end + bv_end + some + ssmin)
res_code equ 0*sbl permanent fixed respr allocation

        section ss_init

* A routine to initialise bt, jb and ch tables
set_tab
        addq.l  #8,a0           for job/chan tables, move over top+tag+max
set_tabb
        move.l  d3,(a0)+        set current table pointer
        move.l  d3,(a0)+        ... and bottom
        add.l   d0,d3           add length
        move.l  d3,(a0)         and put in top
        rts

* Initialise system

* d5 -i  - reset type (only lsb used)
* a5 -i  - top of available ram
* a7 -i  - top of system stack

* Once all the system variables, etc., have been set up, job 0 is be set up and
* activated. This routine then drops out to go user mode in job 0.

ss_init
        lea     non020,a3       what our return address on a 68008 should be
        moveq   #mt.inf,d0      this trap is up and working enough to set a6
        trap    #1

* Now, have a quick look to see if we're on a 68020. This is not much of method
* for doing this, but at least it'll work, until we can decide on a proper trap
* method that'll allow us to determine what processor we're on.
non020
        cmp.l   -4(sp),a3       check the return address on the stack
        beq.s   not020          like 68008, i guess we're an ordinary machine
        moveq   #1,d0           bit 0 = cache on
        dc.l    $4e7b0002       move d0,cr2... or some such
not020

        move.l  a0,a6           set up pointer to system variables
wipesv
        clr.l   (a0)+           ensure sv area is clean
        cmp.l   a0,a7
        bgt.s   wipesv

* Initialise the hardware (maybe this should be moved to earlier on?)

        lea     pc_intr,a3
        assert  pc_tctrl,pc_ipcwr-1
        move.w  #1,pc_tctrl-pc_intr(a3) set transmit mode and reset link
s.mctrl equ     1<<pc..writ!1<<pc..sclk init pc_mctrl (why the write bit? lwr)
s.intr  equ     pc.intre!pc.intrf!pc.intrt!pc.intri!pc.intrg clear interrupts
        assert  pc_mctrl,pc_intr-1
        move.w  #s.mctrl<<8!s.intr,d0
        move.b  d0,(a3)+        clear any interrupts
* That used to send a null to pc_tdata (& maybe mc_ctrl=0), surely silly!
* Maybe this was in fact meant to give a break condition... need to check out!
* Even hermes doesn't yet notice a break on the line, though it could...
        move.w  d0,-(a3)        a3=mctrl, init mctrl and re-clear interrupts
        move.b  #pc.maskt!pc.maski,sv_pcint(a6)  set mask for no gap
* The IPC interrupt was useless. The IPC code did not implement its use for 
* signalling serial buffer full, as was intended. Up to 1.93, Minerva was
* totally ignoring it. now we have Hermes, it's back in 'cos the code works,
* signalling every eighth byte of serial input to keep us on our toes.

        jsr     md_desel(pc)            deselect microdrives

* Now set up the resource tables and their pointers.
* We only assume that the size of memory available is a multiple of 512 bytes.

        move.l  a7,d3           start of tables is just above stack
        lea     sv_btpnt(a6),a0 start filling at bt pointers

        move.l  a5,d0           slave blocks extend to top of ram
        sub.l   a6,d0           ... from base of system variables
        lsr.l   #sbb-btb,d0     slave block table size
        bsr.s   set_tabb
        lsr.l   #1,d0           add half the space of slave blocks to
        add.l   d0,sv_btpnt(a6) the initial pointer (a bit of a fudge...)

        move.l  d3,a3           save top of bt, bot of jt = the job 0 pointer

        lsr.l   #11+btb-sbb-1,d0 allow one job per 2k (2^11) of memory ...
        addq.l  #8,d0           plus a bonus complement of eight
        moveq   #120,d1         maximum number of jobs
        cmp.l   d1,d0
        bls.s   set_jtab
        move.l  d1,d0
set_jtab
        lsl.w   #jtb,d0
        bsr.s   set_tab

        mulu    #cpj,d0         channels per job (but we will steal some...)
        bsr.s   set_tab

        subq.l  #1,d3           we must finish on a 512 byte boundary...
        or.w    #sbl-1,d3       ... so add a few channels to make certain
        addq.l  #1,d3           (awkward to get this right in any other way)

        move.l  d3,a4           set the top of the system vars
        move.l  d3,sv_cheap(a6) set start of common heap
        move.l  d3,sv_free(a6)  set start of free memory (end of common heap)

        sub.l   a6,d3           take away base of system vars
        lsr.l   #sbb-btb,d3     and divide to give the amount of bt entries
        add.l   a7,d3           permanently occupied at base of table

* Holding onto d3/d5/a0/a3/a5-a6 and modifying a4/a7...
* ... we steal some channels so we can build ram versions of the linkage data
* Note: d1 is currently 120, i.e. the msw is zero

        lea     ss_list(pc),a2  clever table... see source for structure
        moveq   #7-1,d0         first is the mdv count, and make msw zero
        bra.s   getlen          jump in to get things going

lp_link
        move.b  d1,d0           is this sx/od/dd now?
        beq.s   storeit         no, the direct address is all we want
        move.l  d4,a1           it's an indirect pointer
        add.b   d0,d0           is there any copying to do?
        bcs.s   lp_addr         if not sx/mdv, no extra bits
        clr.l   -(a4)           (must clear, as we have not zeroed this area)
        clr.w   -(a4)           3 words reserved at end of sx/mdv entries
lp_copy
        move.w  -(a1),-(a4)     copy the top bit of the sx/mdv entries ...
        bne.s   lp_copy         ... until we hit a zero
lp_addr
        move.w  -(a1),d4        get lsw (msw is zero)
        beq.s   storeit         allow for zeroes in mdv list
        add.w   a1,d4           add offset, ensuring < 32k
storeit
        move.l  d4,-(a4)        store relocated address
        subq.b  #2,d0
        bpl.s   lp_addr         do all entries
        move.l  d2,-(a4)        set linkage word
        move.l  a4,d2           next linkage
nxt_ptr
        move.w  -(a2),d0        get next pointer
        move.l  a2,d4           clears msw for us
        add.w   d0,d4           this is the absolute address, maybe
        lsr.w   #1,d0           was the thing we picked up odd?
        bcc.s   lp_link         loop till we hit an odd one
        move.l  d2,-(sp)        save linkage start
getlen
        moveq   #0,d2           final link is zero
        move.w  d0,d1           put count byte into register
        bne.s   nxt_ptr         carry on building if not zero

* We actually end up here with d0, d1 and d2 zero.
* The stack now holds 5 longwords ready to set linkage pointers, the last one
* not important here, though it was just used to set up the sysvars extension.

* We've now stolen the top of the channel table, so say so...

        move.l  a4,(a0)         modify sv_chtop(a6) to point at linkages

fil_jbch
        assert  jtb,ctb
        subq.l  #1<<jtb,a4
        st      (a4)            fill job and channel tables with -1 msb
        cmp.l   a4,a3           down to job 0
        bne.s   fil_jbch

        moveq   #(res_code+bas_allc)>>(sbb-btb),d1
        sub.w   d1,a3           take off initial alloc
clrtop
        clr.l   -(a4)           wipe area for basic and resident section
        cmp.l   a4,a3
        bne.s   clrtop

        moveq   #1,d2
fill_bt
        assert  bt_stat,0
        subq.l  #bt_end,a4
        move.b  d2,(a4)         fill status byte with 1 for free slave blocks
        cmp.l   a4,d3
        bne.s   fill_bt

* Now fill in miscellaneous bits of the system variable area

        movem.l (sp)+,d3/a0-a3 grab the linkage pointers (d3 is not used)
        assert  sv_plist,sv_shlst-4,sv_drlst-8,sv_ddlst-12
        movem.l a0-a3,sv_plist(a6) set the pointers
clrbot
        clr.l   -(a4)           wipe area for permanent tables
        cmp.l   a4,a7
        bne.s   clrbot

        addq.b  #1,sv_netnr(a6) set net station number to 1

        assert  sv_ardel,sv_arfrq-2
        move.l  #30<<16+2,sv_ardel(a6) auto repeat delay = 600 ms
        ;                 sv_arfrq 1/auto repeat frequency = 40ms
        addq.b  #3,sv_cqch+1(a6) initially, old ctrl/c to change queues
        move.w  #sv.ident,sv_ident(a6) ident (tacky way sv's were to be found)
;        move.l  a5,sv_ramt(a6)  set real top of ram
        assert  res_code,0
;       lea     -res_code(a5),a0 find top of working ram
;       moveq   #bas_allc>>(sbb-btb),d1
        asl.l   #sbb-btb,d1
        move.l  a5,a0           find top of working ram
        assert  sv_respr,sv_ramt-4
;        move.l  a0,sv_respr(a6) store as base of resident area
        movem.l a0/a5,sv_respr(a6) store as base of resident area an top of ram
        move.l  a0,sv_trnsp(a6) & transient base & it's basic's top

        sub.w   d1,a0           leave initial basic allocation
        move.l  a0,sv_basic(a6) and this is basic job defn block
        lea     jb_end(a0),a1
clrbas
        clr.l   -(a1)           wipe job 0 header
        cmp.l   a1,a0
        blt.s   clrbas
        jsr     ss_jtag(pc)     make the tag tick, and a3 = job 0 jobtab ptr
        lea     sb_start(pc),a1
        ; a0 = header, a1 = start, a3 = jobtab ptr, d1 = overall size, so ...
        jsr     mt_cj0(pc)      set up the job 0 header
        move.b  d5,-(a3)        tacky, but set lsb of saved a4 to reset flags

        move.b  #32,jb_princ-jb_end(a0) activate job 0

        moveq   #mt.cntry,d0
        moveq   #0,d1           translation off
*       moveq   #1,d2           default messages (still 1 from above)
        trap    #1

        move.w  #9600,d1        set rs232 9600 baud
        moveq   #mt.baud,d0
        trap    #1

        jmp     ss_rj0(pc)      this will start up basic

        end
