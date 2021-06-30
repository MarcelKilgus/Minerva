* A table to help set up ram copies of all the linkage data.
        xdef    ss_list

        xref    ss_ext
        xref    ip_poll,ip_sched
        xref    sd_sched
        xref    io_sched
        xref    od_ser,od_pipe,od_con,od_net
        xref    dd_mdv

* It is read from the top, backwards, with a one terminating the list.
* All the address offset entries will be even.
* We use odd values to mark starting off of new bits of tables.
* A zero in the high byte is the end of the list.
* The lsb is one less than twice the number of words needing reloaction.
* An even msb and a one in the lsb means a single address, and this is used to
* set up the poll and scheduler lists.
* Otherwise, the address will point to the top of another table.
* If in this case the msb is even, 6 bytes are left zero and words are copied
* until a zero is reached. this is used for the dd and sx bits.
* The specified count of words are then relocated, allowing a special case of
* zero to generate a true zero.
* Each set is built with link words and the final such is pushed to the stack.
* a total of five linkage base words are stacked.
* This is all very custom stuff, and not ammenable to messing about with!
* the structures finish up built at base = sv_chtop(a6).

        section ss_list

        dc.b    0,1             address       will be set up with
        dc.w    ss_ext+24*2-*   base+$00: 00000000 + 11 addresses + 13 words
        dc.b    2,11*2-1
        dc.w    ip_poll-*       base+$50: 00000000 ip_poll
        dc.b    2,1
        dc.w    sd_sched-*                                  base+$60 sd_sched
        dc.w    ip_sched-*      base+$60: base+$68 ip_sched
        dc.w    io_sched-*                                  00000000 io_scan
        dc.b    2,1
        dc.w    od_ser+3*2-*    base+$70: base+$80 od_serio od_serop od_sercl
        dc.w    od_pipe+3*2-*   base+$80: base+$90 io_serq  od_pipop od_pipcl
        dc.w    od_con+3*2-*    base+$90: base+$a0 od_conio od_conop od_concl
        dc.w    od_net+3*2-*    base+$a0: 00000000 od_netio od_netop od_netcl
        dc.b    1,3*2-1
        dc.w    dd_mdv+12*2-*   base+$b0: 00000000 dd_mdvio dd_mdvop dd_mdvcl
*                               base+$c0: md_slave 00000000 00000000 md_formt
*                               base+$d0: 0 md_end 0 3 m d  v 0 0000 00000000
*                               base+$e0: end of system extension
ss_list

        end
