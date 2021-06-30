* Directory device block setup for mdv
	xdef	dd_mdv

	xref	dd_mdvcl,dd_mdvio,dd_mdvop
	xref	md_formt,md_slave

	include 'dev7_m_inc_md'

	section dd_mdv

dd_mdv
	dc.w	dd_mdvio-*
	dc.w	dd_mdvop-*
	dc.w	dd_mdvcl-*
	dc.w	md_slave-*
	dc.w	0
	dc.w	0
	dc.w	md_formt-*
	dc.l	md_end		length of definition block
	dc.w	3,'MDV' 	microdrive device name
	dc.w	-1		dummy word that must not be 0 as sx and mdv
*	dc.w	0,0		part must have the same number of reserved words

	end
