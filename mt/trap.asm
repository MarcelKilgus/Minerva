* Manager traps (#1) general entry point
        xdef    mt_trap

        xref    ss_rte + lots of other "xref"'s, done by macro

        include 'dev7_m_inc_err'

        section mt_trap

* d0 cr  control parameter / error flag
* d7   s branch offset

mt_trap
        movem.l d7/a5-a6,-(sp)  save standard registers
        move.l  sp,d7
        and.w   #$8000,d7
        move.l  d7,a6           do not assume there is only one screen

        move.l  sp,a5           mark stack, just for mm_mvjob
* There really ought to be a better way of doing this!!!
* The scenarios when a5 is needed are:
*       cjob from job 0 may push job 0 down
*       frjob and rjob from job 0 can let job 0 go up
*       alres and reres from job 0 can move job 0
*       albas and rebas from job 0 or multibasics may make them move
* The trouble is that the stack depth when access to a6 is needed varies
* enormously.
* It might be conceivably better to make lots of the internal code use a5
* instead of a6, so that a6 could be kept current.
* Alternatively, as most stuff has a use for the current job pointer, maybe a5
* could be set to it and a6 could be put in its proper save area?

        moveq   #127,d7         ensure trap is positive byte only
        and.l   d7,d0
        moveq   #(ent_tabl-ent_top)/2,d7
        add.w   d0,d7
        bcs.s   error           if action not in range
        add.w   d7,d7           d7 addresses words
        move.w  ent_top(pc,d7.w),d7 load entry offset to our junk data reg
        jmp     mt_trap(pc,d7.w) jump to it!!

error
        moveq   #err.bp,d0
        jmp     ss_rte(pc)

tb      macro
        local   i
i       setnum  0
loop    maclab
i       setnum  [i]+2
        xref    mt_[.parm([i])]
        dc.w    mt_[.parm([i])]-mt_trap
        ifnum   [i] < [.nparms] goto loop
        endm

ent_tabl
 tb 00 inf   01 cjob  02 jinf  03 extop 04 rjob  05 frjob 06 free  07 trapv
 tb 08 susjb 09 reljb 0a activ 0b prior 0c alloc 0d lnkfr 0e alres 0f reres
 tb 10 dmode 11 ipcom 12 baud  13 rclck 14 sclck 15 aclck 16 albas 17 rebas
 tb 18 alchp 19 rechp 1a lxint 1b rxint 1c lpoll 1d rpoll 1e lschd 1f rschd
 tb 20 liod  21 riod  22 ldd   23 rdd   24 cntry
ent_top

        end
