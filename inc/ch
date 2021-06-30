* channel definition block / driver headers
        nolist

* channel definition header for all channels

        offset  0
ch_len  ds.l    1       length of definition block
ch_drivr ds.l   1       address of driver
ch_owner ds.l   1       owner job
ch_rflag ds.l   1       address to be set when space released
ch_tag  ds.w    1       channel tag
ch_stat ds.b    1       status: 0 ok, else waiting -1 a1 abs, $80 a1 rel a6
ch_actn ds.b    1       stored action for waiting job
ch_jobwt ds.l   1       ID of job waiting on I/O
ch_end

* extended channel definition for plain serial queues

ch_qin  ds.l    1       pointer to input queue (or zero)
ch_qout ds.l    1       pointer to output queue (or zero)
ch_qend

* device driver header

        offset  0
ch_next ds.l    1       pointer to next driver
ch_inout ds.l   1       entry for input and output
ch_open ds.l    1       entry for open
ch_close ds.l   1       entry for close
* the following are for directory devices (file system) only:
ch_slave ds.l   1       entry for slaving blocks
ch_renam ds.l   1       entry reserved for rename
        ds.l    1
ch_formt ds.l   1       entry for format medium
ch_dflen ds.l   1       length of physical definition block
ch_drnam ds.w   1       length prefixed drive name

        list
