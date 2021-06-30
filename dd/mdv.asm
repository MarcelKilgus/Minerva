* Directory device block setup for mdv
        xdef    dd_mdv

        xref    dd_mdvcl,dd_mdvio,dd_mdvop
        xref    md_formt,md_slave

        include 'dev7_m_inc_md'

        section dd_mdv

dd_mdv
        dc.w    dd_mdvio-*
        dc.w    dd_mdvop-*
        dc.w    dd_mdvcl-*
        dc.w    md_slave-*
        dc.w    0
        dc.w    0
        dc.w    md_formt-*
        dc.l    md_end          length of definition block
        dc.w    3,'MDV'         microdrive device name

        end
