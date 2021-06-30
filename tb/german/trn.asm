* Default serial translation tables
	xdef	tb_trn

	section tb_trn

* Macros for generating serial translate table

trtab macro
trtl setstr [.lab]
trtn setnum 0
trtf setstr n
 endm

trs macro f,t
f setnum [f]
trs[f] setnum [t]
trtf setstr y
 endm

trt macro f,t,u,v
 trs [f],0
trt[trtn] setstr {[f],[t],[u],[v]}
trtn setnum [trtn]+1
 endm

tro macro f,t,u
 trt [f],[t],8,[u]
 endm

batrt macro i
[trtl] dc.w $4AFB
 goto [trtf]
n maclab
 dc.w 0
 goto x
y maclab
 dc.w trs-[trtl],trt-[trtl]
trs
i setnum 0
l maclab
 ifstr [.def(trs[i])] = TRUE goto d
 dc.b [i]
 goto a
d maclab
 dc.b [trs[i]]
a maclab
i setnum [i]+1
 ifnum [i] < 256 goto l
trt dc.b [trtn]
 ifnum [trtn] = 0 goto x
i setnum 0
m maclab
 dc.b [trt[i]]
i setnum [i]+1
 ifnum [i] < [trtn] goto m
x maclab
 endm

tb_trn	trtab
	trs '@','?'
	trs 91,'?' open bracket
	trs 92,'?' backslash
	trs ']','?'
	trs '`','?'
	trs '{','?'
	trs '|','?'
	trs '}','?'
	trs '~','?'
	trs '','?'
	trs '€','{'
	trs '„','|'
	trs '‡','}'
	trs 'œ','~'
	trs 'Ÿ','`'
	trs ' ',91 open bracket
	trs '¤',92 backslash
	trs '§',']'
	trs '¶','@'
	batrt

	end
