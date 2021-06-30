* An unexpected def line
        xdef    ib_def,ib_def1

        xref    ib_nxnon,ib_nxst,ib_s2non

        include 'dev7_m_inc_token'

        section ib_def

* d2 -il - which end to look for

* Have to put in something to deal with DEF FN f(x)=x+1

ib_def
        moveq   #b.def,d2
ib_def1
        jsr     ib_nxst(pc)     get start of next statement
        bne.s   okrts           end of program
        jsr     ib_nxnon(pc)
        cmp.w   #w.end,d1       keep looking for an END
        bne.s   ib_def1
        jsr     ib_s2non(pc)
        cmp.b   d2,d1           ENDDEF (or ENDWHEN)
        bne.s   ib_def1
okrts
        moveq   #0,d0
        rts

        end
