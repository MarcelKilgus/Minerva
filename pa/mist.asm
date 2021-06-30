* Mistake in file being loaded or merged
        xdef    pa_mist

        xref    pa_cdlno,pa_text,pa_tok1

        include 'dev7_m_inc_bv'
        include 'dev7_m_inc_token'
        include 'dev7_m_inc_vect4000'

        section pa_mist

pa_mist
        move.l  bv_tkbas(a6),bv_tkp(a6) reset token list
        move.l  bv_bfbas(a6),a0
        jsr     pa_cdlno(pc)    tokenise the line number
        nop                     return + 0 - ignore if no line number
        moveq   #b.key,d4       return + 2
        moveq   #b.mist,d5
        jsr     pa_tok1(pc)

        jsr     pa_text(pc)
        nop                     return + 0 - ignore if no sensible text
        moveq   #b.sym,d4       return + 2
        moveq   #b.eol,d5
        jsr     pa_tok1(pc)
        moveq   #0,d0
        rts

        vect4000 pa_mist

        end
