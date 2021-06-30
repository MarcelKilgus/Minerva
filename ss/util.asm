* Utilities at real deep levels of the system
        xdef    ss_jtag,ss_tag

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_err'
        include 'dev7_m_inc_assert'

        section ss_util

* ss_jtag establishes a new job slot. a4 is left pointing at sv_jbmax. It is
* called from mt_cjob and ss_init(for job 0).

* ss_tag establishes a new channel/job slot. It requires a4 to have been set
* to point at sv_xxbas, and it leaves with it pointing at sv_xxmax.
* It is only called from io_trap2 for a channel open: i.e. the "xx"'s are "ch".

* Both routines should be called with a negative error code in d0.l.
* On return, the flags are set from d0, which will be the supplied error
* code on failure, or will now contain the new job/channel id. This is now
* always positive, as tag values are prevented from exceeding $7fff.

* d0 i o +ve new id for the table or -ve error if table full
* a3   r pointer to slot found
* a4(i)r input as sv_chbas at ss_tag. returns pointing at sv_xxmax.
* a6 ip  system variables, for jtag entry.

        assert  sv_chtag-sv_jbtag,sv_chmax-sv_jbmax,\
                sv_chbas-sv_jbbas,sv_chtop-sv_jbtop
ss_jtag
        lea     sv_jbbas(a6),a4
ss_tag
        move.l  d0,-(sp)        save poss error code
        move.l  (a4)+,a3        get base of table
        assert  sv_jbtop,sv_jbbas+4
tag_loop
        cmp.l   (a4),a3         is this the end of the table?
        bcc.s   tag_ret         yes - go return d0 as the supplied err.xx
        tst.l   (a3)+           is this a spare entry?
        bpl.s   tag_loop        no - carry on going

tag_this
        subq.l  #4,a3           back up to the entry that was spare
        move.l  a3,d0           copy address of entry
        sub.l   -(a4),d0        subtract base of table
        lsr.w   #2,d0           divide by entry size gives job/channel number
        move.l  d0,(sp)         move this onto stack, setting lsw for return
        subq.l  #sv_jbbas-sv_jbtag,a4
        move.w  (a4),(sp)       copy the tag on stack, setting msw for return
        addq.w  #1,(a4)+        update the tag
        bpl.s   tag_ok          not wrapping round, so it's ok for next time
        lsr.w   -2(a4)          cheap... $8000 -> $4000, wrap last half of tags
tag_ok
        assert  sv_jbmax,sv_jbtag+2
        cmp.w   (a4),d0         have we ever got this high before?
        bcs.s   tag_ret         yes - leave it alone
        move.w  d0,(a4)         no - better record this job/channel number
tag_ret
        move.l  (sp)+,d0        reload d0 with original err or new id
        rts                     return negative on error

        end
