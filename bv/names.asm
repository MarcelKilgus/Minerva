* Compact or copy name table and name list
        xdef    bv_names,bv_namei

        xref    bv_chbfx,bv_chnlx,bv_new
        xref    bp_init,bp_init0

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_jb'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_assert'

bv..int equ     6       jb_rela6 flag that tells us if a job is an interpreter

        section bv_names

* Compact or copy machine code proedures and functions

* This is used at startup of a new copy of basic, to acquire names from it's
* interpreting ancestor, the ROM or even elsewhere.

* In the interest of making the process fairly simple, though we could be
* terribly subtle, we get space for the whole of the nt and nl, then compact it
* as we copy it across. We could go to the bother of doing two scans, the first
* just to establish the size, but it seems a bit pedantic, as the extra space
* can be imediately released to the central area, and it won't be vast usually.

* d0 -o  - 0
* d4 -  o- current job id
* a1 -i  - if not zero, -ve will force rom names or positive some other set!
* a3 -  o- ram top address (wanted by job 0, and we happen to have it handy)
* d1-d3/a0-a2 destroyed

bv_namei
        lea     interp,a2       turn ourselves into an interpreter
        moveq   #mt.extop,d0
        trap    #1
        move.l  sv_ramt(a0),-(sp) save ram top
        jsr     bv_chbfx(pc)    set buffer up right away (small one! 128 bytes)
        tst.l   d4
        lea     bp_init0(pc),a2
        beq.s   init            job 0 always uses rom m/c
        move.l  a1,d1
        beq.s   jobscan
        bmi.s   init            if table is given as positive, use it!
        lea     bp_init(pc),a2
init
        jsr     (a2)            initialise rom m/c procedures and functions
        bra.s   donew

retry
        sub.l   a2,d1           revert to required space
        jsr     bv_chnlx(pc)    allocate the space, and try again
jobscan
        lea     jobfind,a2
        moveq   #mt.extop,d0
        trap    #1
        tst.l   d2              check if we copied the tables OK
        bpl.s   retry           not copied, so go increase our space
        bra.s   donew           OK, we've done it, so continue to finish off

* This is used by the NEW, etc commands to compact the local tables.

* d0-d3/a0-a2 destroyed

bv_names
        move.l  a3,-(sp)        just to agree with namei
        assert  bv_ntbas,bv_ntp-4,bv_nlbas-8
        movem.l bv_ntbas(a6),d1-d2/a3 start at bottom of name table, up to top
        sub.l   d1,d2           total size of nt
        moveq   #3,d3           bit to test for m/c (msbs zero)
nx_mc
        addq.l  #8,d1
        subq.l  #8,d2           was there nothing but mc?
        bcs.s   donew           yes - all done
        btst    d3,-8(a6,d1.l)  are we still on mc procs & fns
        bne.s   nx_mc           yes - keep looking

* We musn't confuse people when moving names, so do it in supervisor mode
        lea     names,a2
        moveq   #mt.extop,d0    increment non-sheduling mode (d0.l=0)
        trap    #1
donew
        move.l  (sp)+,a3        get back saved a3 for names or ramtop for namei
        jmp     bv_new(pc)

* Set up stuff for job handling

info
        moveq   #mt.inf,d0      get system info
        trap    #1
        move.l  d1,d4           save own job id
        moveq   #64+bv..int,d1  flag number and initial buffer request
        assert  sv_jbpnt,sv_jbbas-4
        movem.l sv_jbpnt(a0),a2/a3 get jbpnt and jbbas
        move.l  (a2),a2         get pointer to header of current job
        rts

* Entry point for turning job into an interpreter

interp
        bsr.s   info            get info
        clr.l   jb_start(a2)    we can't be re-activated!
        bset    d1,jb_rela6(a2) set interpreter flag
        rte

* Entry point to supervisor mode code scanning for interpreter ancestor

jobfind
        bsr.s   info            set a2 = job header, a3 = jbbas
ancest
        move.w  jb_owner+2(a2),d0 get owner job number (tag MUST match!)
        lsl.w   #2,d0
        move.l  0(a3,d0.w),a2   get owner header address
        beq.s   j0ok            job 0 keeps its table at job base
        btst    d1,jb_rela6(a2) is this an interpreting ancestor?
        beq.s   ancest          no - keep looking
        add.w   jb_end+2(a2),a2 an interpreter must show where its tables are!
j0ok
        lea     jb_end(a2),a0   point to tables

* We have found an ancestor who is an interpreter... now copy their m/c stuff.

        assert  bv_ntbas,bv_ntp-4,bv_nlbas-8,bv_nlp-12
        lea     bv_ntbas(a6),a1
        move.l  (a1)+,a2
        move.l  a2,(a1)+
        move.l  a2,(a1)+
        move.l  a2,(a1)+        reset our existing tables
        movem.l bv_ntbas(a0),d0/d2-d3/a3
        sub.l   d3,a3           size of their name list
        sub.l   d0,d2           size of their name table
        move.l  d2,d1
        add.l   a3,d1           total space in their name table + name list
        add.l   a2,d1           our new offset to top of name list
        cmp.l   (a1),d1         will it fit in below our nlp+4
        bhi.s   rte0            no - go back and retry (d2 >= 0)

* We have a succesful check on space, so now copy their tables.

        move.l  d1,-(a1)        set nlp
        sub.l   a3,d1
        move.l  d1,-(a1)        set nlbas
        move.l  d1,-(a1)        set ntp
        add.l   a0,d3           where their name list starts
        add.l   d0,a0           where their name table starts
        add.l   a6,a2           absolute base of our name table as destination
        move.l  a2,a3
        add.l   d2,a3           absolute base of our name list as destination
        move.l  a3,d0           copy it for offset calculation
        bra.s   nx_nt

* Note that d2.l < 0 when we have copied tables here 
nx_end
        sub.l   a6,a2           make new nt top relative
        sub.l   a6,a3           make new nl top relative
        move.l  a2,bv_ntp(a6)   reset the top nt pointer
        move.l  a3,bv_nlp(a6)   reset the top namelist pointer
rte0
        rte

* Entry point for supervisor mode code for our own name table/list compaction

names
        lea     -8(a6,d1.l),a0  this the first non-mc
        move.l  a0,a2           two copies, one to scan and one to move
        add.l   a6,a3           make name list base absolute
        move.l  a3,d0           save destination name list base
        add.w   -6(a0),a3       set address of the last m/c name
        move.b  (a3)+,d3        get it's length
        add.w   d3,a3           any further m/c names move down to here
        move.l  d0,d3           duplicate as source base, so we can share code

* d0 - absolute base of destination name list
* d1 - temporary (name length counter)
* d2 - remaining nt entry length
* d3 - absolute base of source name list
* a0 - absolute nt pointer
* a1 - temporary (old nl name pointer)
* a2 - absolute destination to copy nt entries down to
* a3 - absolute pointer to new name list
nx_add
        addq.l  #8,a0           step to next nt entry
nx_nt
        subq.l  #8,d2           have we finished yet?
        bcs.s   nx_end          yes - go finish off
look
        btst    #3,(a0)         is this entry a mc proc/fn
        beq.s   nx_add          no - keep looking
        move.w  (a0)+,(a2)+     move first word of nt entry down
        move.w  (a0)+,a1        get the old name list offset
        add.l   d3,a1           this is where the name comes from
        move.w  a3,(a2)
        sub.w   d0,(a2)+        put in the new name list offset
        move.l  (a0)+,(a2)+     copy the other longword of the nt entry
        move.b  (a1),d1         get the name length
copy_nl
        move.b  (a1)+,(a3)+     copy a char
        subq.b  #1,d1
        bcc.s   copy_nl         until they're all gone
        bra.s   nx_nt

        end
