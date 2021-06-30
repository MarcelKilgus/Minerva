* Returns information about the machine + call routine in supervisor mode
        xdef    mt_inf,mt_extop

        xref    ss_jobx,ss_noer

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_sx'

        section mt_inf

* d0 -  o- 0
* d1 -  o- this job id
* d2 -  o- version number (ascii)
* a0 -  o- pointer to system variables

mt_inf
        moveq   #-1,d1          current job number
        jsr     ss_jobx(pc)     sort it out
        move.l  sv_chtop(a6),a0
        move.l  sx_qdos(a0),d2  version number
        move.l  a6,a0           pointer to system variables
        jmp     ss_noer(pc)

* d0 -  o- system variables address
* a2 -ip - code to be called in supervisor mode
* Actually, any registers may be altered by the called code
* The code at (a2) is entered with d0 holding a copy of the system variables
* base address and all other registers as they were at the trap.
* It should do an "rte" when it has completed.
mt_extop
        move.l  a6,d0           let the caller have a copy of the sysvars base
        movem.l (sp)+,d7/a5-a6  reload caller's registers
        jmp     (a2)            go do it

        end
