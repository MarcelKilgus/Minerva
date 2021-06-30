* Basic variable type setting
        xdef    bv_vtype

        include 'dev7_m_inc_bv'

        section bv_vtype

* Central code for setting a variable's type

* d0 -  o- pointer to last byte of name
* d1 -  o- type 1, 2 or 3 for str$, fp or int%
* a2 -ip - name table entry. byte 0 cleared, byte 1 set to type

bv_vtype
        moveq   #0,d0
        move.w  2(a6,a2.l),d0   get namelist offset
        add.l   bv_nlbas(a6),d0 point at it
        moveq   #0,d1
        move.b  0(a6,d0.l),d1   number of chars in name
        add.w   d1,d0           point to last char
        moveq   #'%',d1
        sub.b   0(a6,d0.l),d1   examine last character
        bhi.s   nt_set          if '$', d1='%'-'$'=1 for string
        sne     d1              if '%', d1=0+3=3 for integer
        addq.b  #3,d1           others, d1=-1+3=2 for floating point
nt_set
        move.w  d1,0(a6,a2.l)   unset usage and set type
        rts

        end
