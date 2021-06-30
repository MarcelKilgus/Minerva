* Startup program for basic
	xdef	sb_start

	xref	bp_alvv,bp_chnew,bp_chnid,bp_init
	xref	bv_chnlx,bv_chnt,bv_namei,bv_om
	xref	cn_date,cn_day
	xref	ib_clvv
	xref	ii_clock
	xref	sb_unvr
	xref	ut_con,ut_err,ut_mint,ut_mtext,ut_wrdef
	xref.s	vers_sub

	include 'dev7_m_inc_assert'
	include 'dev7_m_inc_bv'
	include 'dev7_m_inc_err'
	include 'dev7_m_inc_io'
	include 'dev7_m_inc_mt'
	include 'dev7_m_inc_sv'
	include 'dev7_m_inc_vect4000'

* Parameters for window definitions: initial, monitor and TV

;	 if ntsc
;tvmode  equ	 2
;tot_ht  equ	 192 number of scan lines for 525 version
;ch_ht	 equ	 8
;tv_wid  equ	 420
;	 else
tvmode	equ	1
tot_ht	equ	256 number of scan lines for 625 version
ch_ht	equ	10
tv_wid	equ	448
;	 endif
ch_wid	equ	6

h_0	equ	4*ch_ht
h_n	equ	20*ch_ht
x_n	equ	(512-tv_wid)/4*2
y_0	equ	tot_ht-h_0
y_n	equ	y_0-h_n
h_c	equ	5*ch_ht+10
y_c	equ	tot_ht-h_c
w_c	equ	37*ch_wid+8
x_c	equ	x_n
h_b	equ	3*ch_ht+3
y_b	equ	y_c+5
w_b	equ	23*ch_wid+4
x_b	equ	x_c+(w_c-w_b+12*ch_wid)/4*2

minss	equ	256	minimum stack

	section sb_start

* Entry point for basic start up.

* a0 -i  - initial command channel, or zero
* a4 -i  - job 0 restart flags in lsb
* a5 -i  - total size of the basic area
* a6 -ip - bottom of the basic area
* a7 -i  - pointer to standard exec parameters (count/chans/length/text)

setbv
	move.l	d1,-(a6)
	dbra	d0,setbv
rts1
	rts

sb_start
	move.l	a5,d3
	add.l	a6,d3
	sub.l	sp,d3		remember stack offset for out-of-mem setup

	assert	0,bv_chang&3,bv_endpt&3,bv_end&3
	moveq	#bv_end>>2,d2	size of bv area
	assert	minss,bv_end
	lsl.w	#2+1,d2
	cmp.l	d2,a5		have we been given enough space to start with?
	pea	bv_om(pc)	if anything goes wrong during startup, die!
	blt.s	rts1		no - don't go on...
	pea	sb_unvr(pc)	get ready to enter superbasic universe
parms	equ	2*4		we have two longwords on stack before params
	lsr.w	#1,d2
	add.w	d2,a6
	moveq	#0,d1		top of bv area all zero
	moveq	#(bv_end-bv_endpt-4)>>2-1,d0
	bsr.s	setbv
	move.w	a5,d1
	move.l	d1,-(a6)	set ssbas to top of basic area
	sub.w	d2,d1		and next bunch point to the minimum stack there
	moveq	#(bv_endpt-bv_chang)>>2-1,d0
	bsr.s	setbv
	move.l	d2,d1		last bunch point to top of bv area
	moveq	#bv_chang>>2-1,d0
	bsr.s	setbv		(a6 back to normal now)

	move.l	d3,bv_sssav(a6) save out-of-memory as death for now
	move.l	a0,bv_comch(a6) save any input command channel

* In-line clause and auto/edit flags are off

	st	bv_rand+2(a6)	preset random number
	st	bv_cont(a6)	turn continue flag on (ie. stop off)
*	 st	 bv_print(a6)	 set print from prtok flag on
* surely the above is a waste of time?

	jsr	ib_clvv(pc)	hit anything else that a clear would set up

* We now have tables set up enough to become an interpreter

	jsr	bv_namei(pc)	go fetch m/c names, leaves RAM top in a3 ...
	move.l	d4,d0		... and job id in d4
	beq.l	ini_job0	if we're job zero, go start up now

	sub.l	a4,a4		access passed info relative to sp

	move.w	parms(sp),d5	get number of channels passed
	beq.s	nochans 	none - forget it

	moveq	#-1,d1
	move.w	d5,d2		a counter (we assume it's positive!)
copych
	move.l	parms+2(sp,a4.l),a0
	addq.l	#4,a4
samech
	addq.w	#1,d1		next channel to open
	cmp.w	#2,d1		are we about to open #2?
	beq.s	samech		yes - skip that
	jsr	bp_chnew(pc)
	subq.w	#1,d2		have we finished the channel list?
	bgt.s	copych		no - skip test for duplicating channel #0
	tst.w	d1		have we opened channel #1 yet?
	beq.s	samech		no - let it repeat the same id as #0
nochans

* Build CMD$ as an initial variable

	moveq	#1+4,d1
	jsr	bv_chnlx(pc)
	jsr	bv_chnt(pc)
	move.l	bv_ntp(a6),a3
	move.w	#$201,0(a6,a3.l) t.var<<8|t.str
	addq.l	#1+4,bv_nlp(a6)
	movem.l bv_nlbas(a6),d3/a1
	lea	cmds+1+4,a0
ncpy
	subq.l	#1,a1
	move.b	(a0),0(a6,a1.l) copy in characters of CMD$'s name
	tst.b	-(a0)
	bne.s	ncpy
	sub.w	d3,a1
	move.w	a1,2(a6,a3.l)	set namelist offset
	st	4(a6,a3.l)	just in case...
	addq.l	#8,bv_ntp(a6)
	moveq	#2,d1
	add.w	parms+2(sp,a4.l),d1 get command length (we'll trust it's ok)
* It would be a bit of a waste of code here to check the length out.
* We'll just put up with the fact that other than 0..32766 will cause problems,
* with -2 and -1, at least, possibly crashing the machine!
	jsr	bp_alvv(pc)
copycmd
	move.b	parms+2(sp,a4.l),0(a6,a0.l)
	addq.l	#1,a4
	addq.l	#1,a0
	subq.l	#1,d1
	bne.s	copycmd

	tst.w	d5		did we get any channels passed in?
	bne.s	rts2		yes - that's fine
	move.l	bv_comch(a6),d4 did we get a command channel?
	beq.l	all_wind	no - we have no channels, go produce defaults
rts2
	rts			enter superbasic

plug_chk
	cmp.l	#$4afb0001,(a3) has it got the right id?
	bne.s	plug_inc	... no
	move.l	#$c000,a1	start from first conceivable slot
	bra.s	plug_ent

plug_dup
	move.l	a3,a2
	move.l	a1,a4
	moveq	#128-1,d1	we'll check the first 512 bytes for a match
plug_cp
	cmp.l	(a4)+,(a2)+	does this still look like the same plug-in
	dbne	d1,plug_cp	keep matching
	beq.s	plug_inc	512 bytes the same! presumably the same plug-in
	exg	a1,a3
	bsr.s	plug_inc	move to next possible slot
	exg	a1,a3
plug_ent
	cmp.l	a3,a1		are we back up to this one yet?
	bne.s	plug_dup	no - keep checking for replicates
* The above attempts to avoid mapping in ROM's that appear more than once in
* the address space.
* This happens when address lines are not fully decoded and in cases like the
* Trump Card, which makes it's ROM at $10000 appear also at $c0000.
* Another point: the total ROM compared should be kept reasonably small, to
* avoid problems with ROM's that have their high addresses as hardware control.

	lsl.w	12(sp)		check if i2c is inhibiting this ROM
	bcs.s	plug_inc	it is, so skip (works ok with duplicates)

	lea	8(a3),a1	write message from plug-in
	jsr	ut_mtext(pc)
	move.w	4(a3),d0	get basic procedures from plug-in
	beq.s	plug_exe
	lea	0(a3,d0.w),a1	set the base address of procedure list
	jsr	bp_init(pc)	set up the procedures
plug_exe
	move.w	6(a3),d0	execute plug-in initialisation
	beq.s	plug_inc
	jsr	0(a3,d0.w)
plug_inc
	add.w	#$4000,a3	move on to next
	cmp.l	#$18000,a3	is it end of low bits? (TK2!)
	bne.s	plug_meg
	move.l	8(sp),a3	set a3 to RAM top
plug_meg
	move.l	0,d0		pick up value from locn 0
	rts

ini_job0
	move.l	a4,-(sp)	save restart flags and clear ROM inhibits
	move.l	a3,-(sp)	save RAM top address ...
	move.l	a3,-(sp)	... twice, to simplify ROM replication check
	bsr.l	ini_disp

* Look for plug-ins

	btst	#1,11(sp)	have we been told not to scan ROM's?
	bne.s	plug_out	yes - skip the ROM scan

	move.l	#$c000,a3	first check ROM cartridge, etc
plug_on
	bsr.s	plug_chk
	cmp.l	#$100000,a3
	bcs.s	plug_on 	always scan first megabyte
	cmp.l	(a3),d0 	does it now look like we're wrapping?
	bne.s	plug_on 	no - keep going
plug_out
	assert	0,plug_on+2+12-plug_out
* Above is all rearranged to cope with the horrendous MCS interface, which
* does the ROM check for itself, and then discards its own return address, adds
* twelve to the top of the stack and returns.... arghhhhh....!!!!

	addq.l	#8,sp		discard the RAM top addresses
	moveq	#$0010,d3	f1-f4 bit, timeout and key count!!!
	and.l	(sp),d3 	test that flag
	bne.s	go_key		not zero - initial tiny wait for f1-f4

* Find the mode

read_key
	move.w	#$210,d3	normaly hang about for around 10 secs
go_key
	moveq	#io.fbyte,d0
	trap	#3
	addq.l	#-err.nc,d0	check if timed out
	beq.s	set_mde1	yes, just use what we started with
	addq.b	#8,d1		f5 key = $f8
	add.b	d1,d3		check if {ctrl+}{shift+}f1-f4 (d3.lsb = $10)
	bcc.s	read_key	not f1-f4, read again
	roxl.b	#5,d3		set quick reset bit and dual to extend
	ror.b	#3,d3		slide TV/128k/ROM/quick bits down
	roxr.b	#1,d3		slip in the dual bit
	moveq	#$40000>>16,d1	start getting 128k mask ready
	bset	d1,d3		flag byte now: dual/0/0/f1-f4/TV/128k/ROM/quick
	and.b	d3,d1		isolate 128k bit
	swap	d1		put it up in msw, now $40000 if 128k requested
	move.b	d3,d1		d1.l now ready for re-reset call
	move.l	(sp),d3 	get top of stack
	move.l	d1,(sp) 	replace top of stack
	eor.b	d1,d3		check which bits differ
	and.b	#%10000110,d3	do dualscreen, 128k and romscan bits agree?
set_mde1
	beq.s	set_mode	yes - we're happy to leave that as it is
	jmp	390		no - go to magic reset location with d1.l set

get_mode
	moveq	#-1,d2
	moveq	#-1,d1
	moveq	#mt.dmode,d0
	trap	#1
	lea	mon_def,a1	address of first monitor mode window definition
	tst.b	d2
	beq.s	rts3
	lea	tv_def,a1	address of first TV mode window definition
rts3
	rts

* No channels at all were passed. Do standard ones.

all_wind
	bsr.s	get_mode	sets up definition pointer for us
ini_wind
	moveq	#0,d4
	bsr.s	def_wind	open window #0
	pea	def_next	open #1 and #2, then return
def_next
	addq.w	#1,d4		then do next #
	add.w	#wdef_len,a1	step on pointer
def_wind
	jsr	ut_con(pc)	open a console
	move.w	d4,d1
	jmp	bp_chnew(pc)	and set up the basic channel

* Maybe have a go at allowing TV windows but monitor mode, one day... or use
* both spare bits (6..5) as TV mode? (That even might get NTSC going!)
set_mode
	assert	1,tvmode
	moveq	#8,d1
	and.l	(sp)+,d1	last use of restart flags, set display type
	move.w	d1,d2
	lsr.b	#3,d2		set monitor/TV mode
	moveq	#mt.dmode,d0	n.b. nice... all channels have black paper
	trap	#1

	bsr.s	get_mode	sets up definition pointer for us
	moveq	#0,d4
	bsr.s	mov_wind	put #0 in proper place
	bsr.s	mov_next	put #1 in proper place
	bsr.s	mov_next	put #2 in proper place

* Look for a boot file

	moveq	#-3*boot_len,d4
getboot
	addq.w	#boot_len,d4	'mdv1_boot' string on 2nd try
	beq.s	rts4		no boot file, so go enter superbasic
	moveq	#io.open,d0	try to open a boot file
	moveq	#-1,d1
	moveq	#io.share,d3
	lea	boot+2*boot_len(pc,d4.w),a0 try plain 'boot' string first time
	trap	#2
	tst.l	d0		did the file open ok?
	bne.s	getboot 	no - try next one
	move.l	a0,bv_comch(a6) set command channel
rts4
	rts			enter superbasic

mov_next
	addq.w	#1,d4		do next #
	add.w	#wdef_len,a1	step on pointer
mov_wind
	bsr.s	chnid		select channel
wrdef
	jmp	ut_wrdef(pc)	return via window redefinition

boot	dc.w	4,'boot'
mdv1_	dc.w	9,'mdv1_boot'
boot_len equ mdv1_-boot

ini_disp
	lea	ini_def,a1
	bsr.s	ini_wind	open channels #0, #1 and #2
	assert	0,mt.inf
*	moveq	#mt.inf,d0
	trap	#1
	move.w	#vers_sub,-(sp) store sub-version
	move.l	d2,-(sp)	store qdos version number
	move.l	#10<<24!10<<16!'  ',-(sp) nl,nl,sp,sp
	jsr	ii_clock(pc)	get i2c clock if it's there
;	moveq	#mt.rclck,d0
;	trap	#1
	move.l	sp,a1
	sub.w	#2+36-10,sp
	sub.l	a6,a1
	jsr	cn_date(pc)
	addq.l	#2,a1
	jsr	cn_day(pc)
	moveq	#10,d3
	move.b	d3,7(sp)
	move.b	d3,19(sp)
	move.l	#36<<16!'K ',(sp) 36 characters
* We now have, word prefixed, "K day\yyyy mmm dd\hh:mm:ss\\  vernSubv"
	moveq	#2,d4
	bsr.s	chnid
	moveq	#err.bt,d0	put boot message in #2, redefine then select #1
	bsr.s	err_mov
	move.l	2+36+4(sp),d1
	lsl.l	#16-10,d1
	swap	d1
	sub.w	#128,d1 	don't count ROM, etc
	jsr	ut_mint(pc)	print RAM size to #1
	move.l	sp,a1		set buffer pointer
	jsr	ut_mtext(pc)	print rest of line #1
	add.w	(sp)+,sp	discard it all
	moveq	#err.cp,d0	final copyright in #1, redefine then select #0
err_mov
	jsr	ut_err(pc)	print message
	lea	ini_def,a1	put back defn block pointer as for #0
	bsr.s	wrdef		redefine same as #0
	subq.w	#1,d4
chnid
	move.w	d4,d1
	jmp	bp_chnid(pc)	select next channel

* Three sets of three window definitions: initial, monitor and TV

* NB. TK2 now searches for these window definitions, looking for the $ff010207
* for window #1 in mon_def. It expects tv_def to follow, and all the defs to
* be in this order. No way can it use ini_def, but it doesn't want it...

mon_def
	dc.w	$0000,$0004,512,050,000,206	green on black, no border
	dc.w	$ff01,$0207,256,202,256,000	white on red, grey border
	dc.w	$ff01,$0702,256,202,000,000	red on white, grey border

tv_def
	dc.w	$0000,$0007,tv_wid,h_0,x_n,y_0	white on black, no border
	dc.w	$0000,$0207,tv_wid,h_n,x_n,y_n	white on red, no border
	dc.w	$0000,$0107,tv_wid,h_n,x_n,y_n	white on blue, no border

ini_def
	dc.w	$0000,$0004,tv_wid,y_c-y_n,x_n,y_n green on black, no border
	dc.w	$3802,$1006,w_c,h_c,x_c,y_c	white on dk red dk grey border
	dc.w	$ff01,$0206,w_b,h_b,x_b,y_b	white on red, grey border

wdef_len equ (tv_def-mon_def)/3

cmds	dc.w	4,'CMD$'

	vect4000 sb_start

	end
