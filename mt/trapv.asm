* Reset trap vector pointer
        xdef    mt_trapv

        xref    ss_jobx,ss_noer

        include 'dev7_m_inc_sv'
        include 'dev7_m_inc_jb'

        section mt_trapv

* d1 -i o- job id (-1 = self)
* a0 -  o- base address of job
* a1 -i  - new pointer

mt_trapv
        jsr     ss_jobx(pc)     get current job pointer
        sub.w   #sv_trapo,a1    adjust trap vector
        move.l  a1,sv_trapv(a6) and set the system vector
        move.l  a1,jb_trapv(a0) ... and the per job vector
        jmp     ss_noer(pc)

        end
