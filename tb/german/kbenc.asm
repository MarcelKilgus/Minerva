* Convert IPC shifts and keyrows to character or special
	xdef	tb_kbenc

	include 'dev7_m_inc_sv'
	include 'dev7_m_inc_sx'

	section tb_kbenc

* d1 -i o- 6 lsb are keyrow (5-3 column, 2-0 row), see below for output
* d2 -i  - 3 lsb SHIFT/CTRL/ALT
* a4 -ip - sysvar extension address
* a6 -ip - sysvar
* d0/d2/a1 destroyed

* This code may also destroy d6/a0/a3 if it wants, and even a4, provided it
* does not make a direct return.

* Relevent input data to this code consists of:

*	sv_caps(a6)	if non-zero, CAPS LOCK is on

*	sv_ichar(a6)	zero: no compose
*			one: compose has been started
*			other: used by this code to do whatever it likes.
* Presently, this code records bit 7 with the state of SHIFT on the first
* character of a compose key, and puts its table offset in bits 6..0.

*	sx_kbste(a4)	twelve bytes which are required to be remapped as
*			"special" keys. E.g. CTRL/F5 is done here.

* Direct return, CTRL in combination with one of space, TAB or ENTER:
* d1.w	0..11: Bit 0 = ALT, bit 1 = SHIFT, bit 2 = TAB, bit 3 = ENTER

* Return + 2, normal characters:
* d1.w	msb 0 and lsb 8 bit char or ...
*	... msb 8 bit char and lsb $FF if the ALT prefix ($FF) is required.

* Return + 4, ignore this (compose first char stored or compose aborted)
* d1.w	undefined

compose
	addq.l	#2,(sp) 	return + 2 if ready, + 4 if scrap or first
	lea	compx,a1	point at top of compose char list
	moveq	#127,d0
	and.b	d2,d0		pick out saved offset
	subq.b	#1,d0		is it our second character?
	beq.s	sing		no - go do the first char lookup
	lsl.w	#8,d1		put this char into msb
	move.b	1+compb-compx(a1,d0.w),d1 incorporate the prior byte
	moveq	#dcnt-1,d0
dloop
	rol.w	#8,d1
	cmp.w	-(a1),d1
	beq.s	dfnd
	rol.w	#8,d1
	cmp.w	(a1),d1
	dbeq	d0,dloop
	bne.s	ret2		no such char pair in compose table
dfnd
	sub.w	d0,a1
	bra.s	compok

sing
	moveq	#pcnt*2+scnt-1,d0
	sub.w	#(dcnt-pcnt)*2,a1 leave out auto compose set
sloop
	cmp.b	-(a1),d1
	dbeq	d0,sloop
	bne.s	ret2		no such char in compose table
	cmp.w	#scnt,d0
	bcc.s	savec1		2nd section are dual compose, go store char
compok
	move.b	compr-compb(a1),d1
	tst.b	sv_caps(a6)
	bne.s	rts0		if CAPS LOCK is on, leave as uppercase
	tst.b	d2		was SHIFT on for this (or prev) key?
	bmi.s	rts0		yes - also leave as uppercase
	moveq	#$AC-256,d0	change it if is it $A0 to $AB
togq
	cmp.b	d0,d1		compare high end of range
	bcc.s	rts0		too big - no toggle
	and.b	#$E1,d0 	get low end of range
	cmp.b	d0,d1		compare low end of range
	bcs.s	rts0		too small - no toggle
	eor.b	#32,d1		flip upper/lower case bit
rts0
	rts

savec1
	subq.b	#1,d2		drop the 1st char compose bit, leaving SHIFT
	or.b	d2,d0		incorporate this char offset
setic
	move.b	d0,sv_ichar(a6) store it, then do an ignore return
ret2
	addq.l	#2,(sp) 	make a normal + 2 return
	rts

simple
	asr.w	#8,d2		are we composing?
	bne.s	compose 	yes - go do it

	moveq	#12-1,d0	counter and offset
rdlp
	cmp.b	sx_kbste(a4,d0.w),d1
	dbeq	d0,rdlp
	bne.s	ret2		end of table, return normal
	move.w	d0,d1		found a match, special return
	rts

qlck
	tst.b	sv_caps(a6)	is CAPS LOCK set
	beq.s	qalt		no - skip this bit
	moveq	#'z'+1,d0
	bsr.s	togq
	moveq	#$8C-256,d0
	bsr.s	togq
qalt
	not.b	d2		was ALT on?
simp1
	bmi.s	simple		no - go finish off
	rol.w	#8,d1		put char into msb
	st	d1		put $FF into lsb
	bra.s	ret2

acomp
	moveq	#compa-1-compb+2,d0
	add.b	d1,d0		adjust autocompose to give offset
	addq.l	#2,(sp)
	bra.s	setic

curcap
	bsr.s	roll		put ALT in lsb
	bra.s	simp1		this will be negative...

tb_kbenc
	ror.w	#3,d2		tuck away SCA bits
	move.b	sv_ichar(a6),d2 are we composing?
	beq.s	noshf		no - carry on
	bmi.s	shsav		SHIFT is already set
	add.w	d2,d2		move this SHIFT ...
	roxr.b	#1,d2		... down into lsb
shsav
	asl.w	#3,d2		this junks SHIFT/CTRL/ALT
	addq.b	#4,d2		and pretend SHIFT only is on
	ror.w	#3,d2		tuck away SCA = 100
	sf	sv_ichar(a6)	drop the compose flag
noshf
	ror.w	#8,d2		save compose in msb
	and.w	#$3F,d1
	bsr.s	roll		fetch in SHIFT
	bsr.s	roll		fetch in CTRL
	move.b	keytab-3*4(pc,d1.w),d1 get translated character
	cmp.b	#$C0,d1
	bcs.s	qlck
	cmp.b	#$E8,d1
	bcc.s	qalt
	lsr.b	#1,d1		cursor/CAPS or CTRL + space/TAB/ENTER
	bcc.s	curcap
	sub.b	#$DC>>1,d1	dump offset then put in ALT and special return
	bcs.s	acomp		however, if carry set, this is an auto compose
roll
	add.b	d2,d2		roll one bit from d2 ...
	addx.b	d1,d1		... into d1
	rts

* Main Translation Table
* ----------------------

* The scan value (3..63) is multiplied by four, plus two for SHIFT and one
* more for CTRL.

* The range $C0 to $E7 are cursor keys and CAPS LOCK, which need the ALT bit
* put into their lsb.
* We utilise the fact that these all have a zero lsb so we can sort out our
* special CTRL{/SHIFT}{/ALT} + space/TAB/ENTER and auto compose.
* The s/t/e ones have the ODD values from $DD to $E7 given them.
* The auto-compose key (UK {SHIFT/}`) uses $D9 and $DB.
* Thus we distinguish them as we play with the ALT bit.
* We still have the dozen odd codes $C1 to $D7 for further games ...
* Some more code could be saved overall, but at the expense of making this
* table rather more obscure.

* Keyboard with compose characters
* +---+ +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
*			     —š  ˜›  –™ 	  ¦		 ¡¥
*	  µ   ³   ’  ·     ” Ž‘• Œƒ“  ¸   ¹   †   ´   º   Ÿ  …
* |   | |  | ! | " | ¶ | $ | % | & | / | ( | ) | = | ? | ' | ^ | > |
* | F1| |ESC| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 | œ | # | \ | < |
* +---+ +---+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
*		      ª«£‘		    •’	¢	›
*		      Š‹ƒ	®	   “”	‚   ±  ™š   »
* |   | |     |   |   |   |   |   |   |   |   |   |   |   | * |   |
* | F2| | TAB | Q | W | E | R | T | Z | U | I | O | P | § | + | | |
* +---+ +-----++--++--++--++--++--++--++--++--++--++--++--++--+ | |
*						   « ˜ ª¢¡ Ž
*		 ¬	 ­   ²			 ¯ ‹–— Š‚Œ
* |   | | CAPS |   |   |   |   |   |   |   |   |   |   |   | /__/ |
* | F3| | LOCK | A | S | D | F | G | H | J | K | L | ¤ |   | \	  |
* +---+ +------+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+------+
*		   ž	  ¨ˆ	      ©‰   °
* |   | |  //\\  |   |	 |   |	 |   |	 |   | ; | : | _ |  //\\  |
* | F4| |   ||	 | Y | X | C | V | B | N | M | , | . | - |   ||   |
* +---+ +------+-+-+-+-+-+---+---+---+---+---+---+-+-+-+-+-+------+
*		 ¼   ½				     ¾	 ¿
* |   | |      |/__|__\|			   |/|\| | |	  |
* | F5| | CTRL |\  |  /|			   | | |\|/| ALT  |
* +---+ +------+---+---+---------------------------+---+---+------+

keytab			       dc.l $781858B8
	dc.l $76165690,$2D8F5F9F,$6E0E4EAE,$2C8C3B97
 dc.l $387C288A,$329222BC,$369626BE,$711151B1
	dc.l $650545A5,$305D3D89,$741454B4,$751555B5
 dc.l $395B2988,$771757B7,$690949A9,$09E1FDE3
	dc.l $721252B2,$9C7B3FBF,$7A1A5ABA,$6F0F4FAF
 dc.l $6C0C4CAC,$3393B683,$680848A8,$31912181
	dc.l $610141A1,$701050B0,$64044498,$6A0A4AAA
 dc.l $87BBA71B,$E0E2E4E6,$6B0B4BAB,$731353B3
	dc.l $660646A6,$237D278B,$6707479D,$849BA49A
 dc.l $2BBD2A1D,$791959B9,$2E8E3A9E,$630343A3
	dc.l $620242A2,$5C405E1E,$6D0D4DAD,$8099A082
 dc.l $0AE5FEE7,$C0C2C4C6,$D0D2D4D6,$1B007F1F
	dc.l $C8CACCCE,$3C7E3E1C,$20DDFCDF,$D8DADCDE
 dc.l $F4F5F6F7,$E8E9EAEB,$35952585,$ECEDEEEF
	dc.l $F0F1F2F3,$F8F9FAFB,$3494248D,$37602F86


* Compose Key Table
* -----------------

* The compose table is structured as follows:
* The "compb" set has the single character compose characters followed by
* words which are the character pairs which will be part of a compose pair.
* A pair will be matched whichever way round they are typed.
* The "compr" set contains the resultant single character composed characters,
* followed by the resultant dual character composed characters.
* All entries are the SHIFT'ed characters, as this is forced while composing.
* The entries that have lower case versions are changed back provided that
* CAPSLOCK is not on and the SHIFT key was not held on EITHER keypress.
* The "compa" marker comes between the pair of unshifted characters that are
* to be used as dummies when doing one of two possible auto-compose keys.

compr	dc.b	'µ»·´³ž¢¨©¦¬­®¯°±²¸¹Ÿº¼½¾¿'
scnt	equ	*-compr
	dc.b	'¡ŒŽª£‘“•”’¥–˜—«™›š'
pcnt	equ	*-compr-scnt
	dc.b	'' no first auto compose key
	dc.b	'' no second auto compose key
dcnt	equ	*-compr-scnt
	ds.b	dcnt&1 needed to make sure of getting onto word boundary
compb	dc.b	'*¶?!$YOCN=ADTLMPF()^',39,$C4,$CC,$D4,$DC
	dc.b	' > / & % EE/E&E%E"I/I&I%I"¤>¤/¤&¤%¤E§/§&§%'
	dc.b	'' no first auto compose key
compa	dc.b	'' no second auto compose key
compx

	end
