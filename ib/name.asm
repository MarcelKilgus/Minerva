* Deal with a name at the start of a statement
        xdef    ib_name,ib_name1

        xref    ib_array,ib_bproc,ib_fname,ib_let,ib_nxnon,ib_proc,ib_s4non

        include 'dev7_m_inc_err'
        include 'dev7_m_inc_nt'
        include 'dev7_m_inc_token'

        section ib_name

* a4 -i o- pf pointer

ib_name
        jsr     ib_nxnon(pc)    get a non-space
        cmp.b   #b.nam,d0
        bne.s   err_ni          not a name, wrong!
ib_name1
        moveq   #0,d4
        move.w  2(a6,a4.l),d4   get name number
        jsr     ib_s4non(pc)    get next non-space ready for checking
        jsr     ib_fname(pc)    don't mess up d4 'cos later bits need it
        move.b  0(a6,a2.l),d0   read name type
        subq.b  #t.arr,d0       is name an array?
        beq.l   ib_array        yes, go do it
        subq.b  #t.bpr-t.arr,d0 is name a basic procedure?
        beq.l   ib_bproc        yes, go do it
        subq.b  #t.mcp-t.bpr,d0 is name an m/c procedure then?
        bne.l   ib_let          no, assume it's a variable then, let does rest
        jmp     ib_proc(pc)     go do the m/c proc

err_ni
        moveq   #err.ni,d0
        rts

        end
