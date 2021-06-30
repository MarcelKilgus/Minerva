* Absolute pointers to graph table and keyword table - nasty things!
        xdef    pa_table

        xref.l  pa_grtab,pa_kytab

        include 'dev7_m_inc_vect4000'

        section pa_table

pa_table dc.l   pa_kytab,pa_grtab

        vect4000 pa_table

        end
