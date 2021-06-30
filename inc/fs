* file system definitions
        nolist

fs.nmlen  equ    36     max length of file name
fs.hdlen  equ    64     length of file system header

* file system channel channel definition block

        offset  $18 ( = ch_end, end of standard channel header )
fs_next ds.l    1       link to next file system channel
fs_acces ds.b   1       access mode
fs_drive ds.b   1       drive id
fs_filnr ds.w   1       file number
fs_nblok ds.w   1       block containing next byte
fs_nbyte ds.w   1       next byte in block
fs_eblok ds.w   1       end of file (block)
fs_ebyte ds.w   1       end of file (byte in block)
fs_cblok ds.l   1       pointer to table for current slave block
fs_updt ds.b    1       set if file is updated
        ds.b    5       spare
fs_fname ds.w   1+fs.nmlen/2  length prefixed file name
fs_spare ds.b   72
fs_end

* common part of a physical file system definition block

        offset  0
        ds.b    $10
fs_drivr ds.l   1       pointer to driver
fs_drivn ds.b   1       drive number
        ds.b    1
fs_mname ds.w   1+10/2  length prefixed medium name
fs_files ds.b   1       number of files open

* file system trap #3 codes

fs.check  equ    $40                check all pending operations
fs.flush  equ    $41                flush buffers
fs.posab  equ    $42                position file pointer (absolute)
fs.posre  equ    $43                position file pointer (relative)

fs.mdinf  equ    $45                information about medium
fs.heads  equ    $46                set file header
fs.headr  equ    $47                read file header
fs.load   equ    $48                load file
fs.save   equ    $49                save file
fs.renam  equ    $4a                rename file
fs.trunc  equ    $4b                truncate file

        list
