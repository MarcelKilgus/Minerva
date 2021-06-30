* Default message tables
	xdef	tb_msg

* This file holds all the error messages etc. which are language dependent.
* This is linked at the top of a ROM (in ROM based systems) to make language
* versions easier to implement.

msg	macro
	dc.w	x[.l]-tb_msg
	section tb_txt
x[.l]
	ifstr	{[.ext]} = B goto nolen
	dc.w	y[.l]-*-2
nolen	maclab
i	setnum	0
loop	maclab
i	setnum	[i]+1
	dc.b	[.parm([i])]
	ifnum	[i] < [.nparms] goto loop
y[.l]
	ds.w	0
	section tb_msg
	endm

lf	equ	10

	section tb_msg

tb_msg
	dc.w	$4afb
	msg	{'Abgebrochen'},10
	msg	{'Fehlerhafter JOB'},10
	msg	{'Speicher‡berlauf'},10
	msg	{'Bereichs‡berlauf'},10
	msg	{'Puffer Voll'},10
	msg	{'Kanal nicht Er„ffnet'},10
	msg	{'Nicht Gefunden'},10
	msg	{'Existiert Bereits'},10
	msg	{'In Bearbeitung'},10
	msg	{'Dateiende'},10
	msg	{'Datentr€ger Voll'},10
	msg	{'Ung‡ltige Bezeichnung'},10
	msg	{'§bertragungsfehler'},10
	msg	{'Formatierungsfehler'},10
	msg	{'Ung‡ltiger PARAMETER'},10
	msg	{' Fehlerhafter Datentr€ger'},10
	msg	{'Fehler im Ausdruck'},10
	msg	{'§berlauf'},10
	msg	{'Nicht Implementiert ...'},10
	msg	{'Nur lesen'},10
	msg	{'Syntax-Fehler'},10
	msg	{'in Zeile '}
	msg	{' Sektoren'},10
	msg	{' F1/F2 f‡r Monitor/TV '},10 \
		{' F3/F4 2. Bildschirm  '},10 \
		{' 128K+SHIFT Nicht+CTRL'}
	msg	{' The QView Mega Corporation'}
	msg	{'w€hrend WHEN Verarbeitung'},10
	msg	{'PROC/FN Gel„scht'},10
	msg.b	{'SonMonDieMitDonFreSam'}
	msg.b	{'JanFebM€rAprMaiJunJulAugSepOktNovDez'}

	end
