* Execute a keyword line
        xdef    ib_kywrd

* All "xref"'s from macro

        include 'dev7_m_inc_err'

h setstr { ib_rts ib_errnf ib_errbl }
gotab   macro
i setnum  0
l maclab
i setnum [i]+1
n setstr ib_[.parm([i])]
 ifnum [.instr(h,n)] > 0 goto d
        xref    [n]
d maclab
        dc.w    [n]-ib_rts
 ifnum [i] < [.nparms] goto l
        endm

        section ib_kywrd

kyentry
        gotab         end   for   if    rep   sel   when  def
        gotab   errnf errnf goto  errnf errnf errnf errnf errnf
        gotab   errnf restr next  exit  else  on    ret   errnf
        gotab   rts   dim   errbl name  errnf errnf rts   errbl

ib_kywrd
        moveq   #0,d0
        move.b  1(a6,a4.l),d0   read key number
        addq.l  #2,a4
        add.b   d0,d0           entries in words
        move.w  kyentry-2(pc,d0.w),d0 get code offset
        jmp     ib_rts(pc,d0.w) note: if we go to ib_rts, d0=0

ib_errnf
        moveq   #err.nf,d0
        rts

ib_errbl
        moveq   #err.bl,d0
ib_rts
        rts


        end
