* Basic parsing tables
        xdef    pa_grtab,pa_kytab

        include 'dev7_m_inc_vect4000'

* An explanation:

* The syntax tables start with a header of the word offsets from the base
* address to the entry points for the individual graphs, numbered even,
* starting with 2, the main entry point for a basic line.

* Once into a graph, the tables are byte oriented.

* Generally, a byte pair is seen, with the first byte indicating the syntax
* element to be matched, and the second byte is the offset from itself to
* continue at, should the match succeed.
* If the match fails the parsing steps past the two bytes and goes on.
* If the match succeeds, the offset is used.

* There are two special case single bytes that control the process.
* One is used to mark a point at which a graph should remember to return as
* matched, as the further alternatives are an optional part of the syntax.
* The second special byte marks the end of a list of alternatives and the
* completion of the graph. If a possible exit has been seen, the return uses
* the saved positions at that point and returns as matched. Otherwise it fails.

* There is also a special case for the second byte of a byte pair. If this is
* zero (i.e. points to itself), it indicates that the graph is complete at this
* point and must immediately return as matched.

* Use of the "point of no return" system of backtracking has been discontinued,
* as it was an overreaction to the odd couple of instances that were awkward,
* and they are now handled by a couple of extra graphs.

* The "end of graph" is coded as *-* to show it's a sorta jump.

* The "end of possibilities" is coded as z, for brevity.

* The "possible exit" is coded as q, for quit.

gen macro
gnum setnum [gnum]+2
[.lab].[.ext] equ [gnum]
 endm

xxx macro
gnum setnum [gnum]+2
 endm

* We will use <length> to sort out the four overall types of entry:
*       ".b" coded atom, ".l" labeled graph, ".s" symbol and ".w" keyword.

graph macro
[.lab] gen.l
 dc.w [.lab]_a-pa_grtab
 endm

        section pa_grtab

pa_grtab
gnum    setnum  $80     graph numbers and entry points        
q       equ     [gnum] possible exit from graph = graph plus zero
line    graph   basic line
odc     graph   opening definition clause
osl     graph   opening select clause
oc      graph   opening clause
;ocif    graph   entry to opening if clause (no longer used)
ic      graph   intermediate clause
icon    graph   entry to intermediate on clause
ec      graph   end clause
stat    graph   statement
dplst   graph   definition parameter list
rnge    graph   range
expr    graph   expression
whcon   graph   condition (part-way thro' expression)
da      graph   dimension array list
var     graph   variable
splst   graph   separated parameter list
subs    graph   subscription list
lit     graph   literal
ongo    graph   distinguish "ON name = expr" from "ON expr GO ..."
proc    graph   distinguish "name(expr) = expr" from "name splst" (mostly)
ass     graph   distingish assignment statements as far as possible
tosub   graph   GO TO or GO SUB, to save a little space

gnum    setnum  $40     keyword numbers
END     gen.w
FOR     gen.w
IF      gen.w
REP     gen.w   ; REPeat
SEL     gen.w   ; SELect
WHEN    gen.w
DEF     gen.w   ; DEFine
PROC    gen.w   ; PROCedure
FN      gen.w   ; FuNction
GO      gen.w
TO      gen.w
SUB     gen.w
        xxx.w   ; extra WHEN, not parsed, needed by keyword check for WHENERRor
ERR     gen.w   ; ERRor
        xxx.w   ; spare keyword (currently IF, historically EOF then END)
        xxx.w   ; spare keyword (currently IF, historically INPUT then ERRor)
RESTORE gen.w
NEXT    gen.w
EXIT    gen.w
ELSE    gen.w
ON      gen.w
RET     gen.w   RETurn
REMAINDER gen.w
DATA    gen.w
DIM     gen.w   DIMension
LOC     gen.w   LOCal
LET     gen.w
THEN    gen.w
STEP    gen.w
REM     gen.w   REMark
MIST    gen.w   MISTake (reading line from file)

gnum    setnum  $20     symbol numbers
equ     gen.s   equals '='
col     gen.s   colon ':'
hsh     gen.s   hash '#'
com     gen.s   comma ','
obr     gen.s   open bracket '('
cbr     gen.s   close bracket')'
ocb     gen.s   open curly bracket '{'
ccb     gen.s   close curly bracket '}'
spc     gen.s   space
lf      gen.s   line feed

gnum    setnum  $00     coded atom numbers
z       equ     [gnum] - end of possibilities is coded atom zero
name    gen.b   name
val     gen.b   value
num     xxx.b   number - code actually duplicates the above... s/l integers?
sysv    xxx.b   system variable
ops     gen.b   operation symbol
mons    gen.b   mon-operation symbol
sep     gen.b   separator
str     gen.b   string
txt     gen.b   text
linum   gen.b   line number

* Line graph table
line_a dc.b linum.b,line_b-*-1 optional line number
line_b dc.b  odc.l,line_d-*-1
;line_b dc.b  odc.l,line_f-*-1 see below
line_c dc.b   IF.w,line_l-*-1,osl.l,line_j-*-3,oc.l,line_d-*-5
       dc.b    ELSE.w,line_c-*-1,ic.l,line_d-*-3,ec.l,line_d-*-5
       dc.b     stat.l,line_d-*-1
line_d dc.b      col.s,line_c-*-1
line_e dc.b       lf.s,*-*,z
;line_f dc.b equ.s,line_g-*-1,col.s,line_c-*-3,lf.s,*-*,z
; replace above when single line functions are going to be implemented
;line_g dc.b expr.l,line_e-*-1,z
line_h dc.b THEN.w,line_c-*-1
line_i dc.b                   col.s,line_c-*-1,lf.s,*-*,z
line_j dc.b lf.s,*-*,col.s,line_k-*-3
line_k dc.b                           icon.l,line_c-*-1,z
line_l dc.b expr.l,line_h-*-1,z

* Opening definition clause graph table
odc_a dc.b DEF.w,odc_b-*-1,z
odc_b dc.b PROC.w,odc_c-*-1,FN.w,odc_c-*-3,z
odc_c dc.b name.b,odc_d-*-1,z
odc_d dc.b q,dplst.l,*-*,z

* Opening clause graph table
oc_a dc.b FOR.w,oc_b-*-1,REP.w,oc_d-*-3,WHEN.w,oc_f-*-5,z
oc_b dc.b name.b,oc_g-*-1,z
;oc_d dc.b name.b,*-*,z
oc_f dc.b ERR.w,*-*,name.b,oc_r-*-3,z
oc_g dc.b equ.s,oc_m-*-1,z
*oc_h dc.b q allowed WHEN ERRor <expr>{,<expr>} !!!
*oc_i dc.b     expr.l,oc_n-*-1,z
*oc_j dc.b hsh.s,oc_p-*-1,z oc_j/p/t were "#expr{,#expr}" - not used!
oc_m dc.b rnge.l,oc_s-*-1,z
*oc_n dc.b q,com.s,oc_i-*-2,z
*oc_p dc.b expr.l,oc_u-*-1,z
oc_r dc.b q,whcon.l,*-*,z this starts at possible subscription/slicing
oc_s dc.b STEP.w,oc_v-*-1
oc_t dc.b                 q,com.s,oc_m-*-2,z
*oc_u dc.b q,com.s,oc_j-*-2,z
oc_v dc.b expr.l,oc_t-*-1,z

* Opening select clause
osl_a dc.b SEL.w,osl_b-*-1,z
osl_b dc.b ON.w,osl_c-*-1
oc_d
ic_b
osl_c dc.b                name.b,*-*,z

* Intermediate clause graph table (now takes in the "ON expr GO ..." statement)
ic_a dc.b EXIT.w,ic_b-*-1,NEXT.w,ic_b-*-3,RET.w,ic_c-*-5,ON.w,ic_d-*-7
icon_a dc.b                            equ.s,ic_e-*-1,z
;ic_b dc.b name.b,*-*,z
;ic_c dc.b q,expr.l,*-*,z
ic_d dc.b ongo.l,*-*,name.b,icon_a-*-3,z
ic_e dc.b REMAINDER.w,*-*
ic_f dc.b                 rnge.l,ic_g-*-1,z
ic_g dc.b com.s,ic_f-*-1,q,z

* End clause graph table
ec_a dc.b END.w,ec_b-*-1,z
ec_b dc.b REP.w,ec_d-*-1,FOR.w,ec_d-*-3,IF.w,*-*,SEL.w,*-*
     dc.b                            WHEN.w,*-*,DEF.w,ec_c-*-3,z
ec_c dc.b q
ec_d dc.b   name.b,*-*,z

* Proc call "name(expr)=expr sep" (to distinguish it from assignment)
proc_a dc.b obr.s,proc_b-*-1,z
proc_b dc.b expr.l,proc_c-*-1,z
proc_c dc.b cbr.s,proc_d-*-1,z
proc_d dc.b ops.b,proc_e-*-1
proc_e dc.b expr.l,proc_f-*-1
proc_f dc.b sep.b,*-*,z

* ON expr GO ... graph table (to distinguish it from ON var = expr)
ongo_a dc.b expr.l,ongo_l-*-1,z
ongo_l dc.b GO.w,ongo_m-*-1,z
ongo_m dc.b tosub.l,ongo_p-*-1,z
ongo_n dc.b expr.l,ongo_p-*-1,z
ongo_p dc.b com.s,ongo_n-*-1,q,z

* TO or SUB plus expr to save a couple of bytes
tosub_a dc.b TO.w,tosub_c-*-1,SUB.w,tosub_c-*-3,z
*tosub_c dc.b expr.l,*-*,z

* Statement graph table
stat_a dc.b LOC.w,stat_v-*-1,DIM.w,stat_c-*-3,DATA.w,ongo_n-*-5
       dc.b  RESTORE.w,stat_b-*-1,REM.w,stat_h-*-3,MIST.w,stat_h-*-5
       dc.b   GO.w,tosub_a-*-1,LET.w,stat_p-*-3,name.b,stat_t-*-5,z
* Note: "name(expr)=expr" still has to be left to runtime!
ic_c
stat_b dc.b q
rnge_c
tosub_c
stat_s dc.b   expr.l,*-*,z
stat_c dc.b name.b,stat_d-*-1,z
stat_d dc.b da.l,stat_e-*-1,z
stat_e dc.b com.s,stat_c-*-1,q,z
stat_v dc.b name.b,stat_f-*-1,z
stat_f dc.b da.l,stat_g-*-1
stat_g dc.b                 com.s,stat_v-*-1,q,z
stat_h dc.b txt.b,*-*,z
stat_p dc.b name.b,stat_q-*-1,z
stat_q dc.b var.l,stat_r-*-1,z
ass_b
stat_r dc.b equ.s,stat_s-*-1,z
stat_t dc.b proc.l,stat_u-*-1,ass.l,*-*
stat_u dc.b                             splst.l,*-*,z

* Assignment statement (with a chance of getting it wrong! "name(expr)=expr")
ass_a dc.b var.l,ass_b-*-1,z

* Definition parameter list graph table
dplst_a dc.b obr.s,dplst_b-*-1,z
dplst_b dc.b name.b,dplst_c-*-1,obr.s,dplst_e-*-3,z
* Wow! We can have DEFFN fred(a,b,(c,d))!
dplst_c dc.b com.s,dplst_b-*-1
dplst_d dc.b                   cbr.s,*-*,z
dplst_e dc.b name.b,dplst_f-*-1,z
dplst_f dc.b com.s,dplst_e-*-1,cbr.s,dplst_d-*-3,z

* Range graph table
rnge_a dc.b expr.l,rnge_b-*-1,z
rnge_b dc.b TO.w,rnge_c-*-1,q,z
;rnge_c dc.b expr.l,*-*,z

* Expression graph table - WHEN var condition graph starts at whcon_a
pa_expr
expr_a dc.b val.b,expr_d-*-1,mons.b,expr_a-*-3 we may do multiple monadics
       dc.b  obr.s,expr_b-*-1
       dc.b   str.b,expr_d-*-1,lit.l,expr_d-*-3,name.b,expr_h-*-5,z
expr_b dc.b expr.l,expr_g-*-1,z
whcon_a ; new entry point for WHEN var condition, allow subscription of var
expr_d dc.b obr.s,expr_f-*-1,q,ops.b,expr_a-*-4,z
expr_f dc.b subs.l,expr_g-*-1,z
expr_g dc.b cbr.s,expr_d-*-1,z
expr_h dc.b obr.s,expr_i-*-1,q,ops.b,expr_a-*-4,z
expr_i dc.b splst.l,expr_g-*-1,z

* Dimensioned array graph table (name already parsed)
da_a dc.b obr.s,da_c-*-1,z
da_c dc.b expr.l,da_d-*-1,z
da_d dc.b com.s,da_c-*-1,cbr.s,*-*,z

* Variable graph table (name already parsed)
var_a dc.b q,obr.s,var_b-*-2,z
var_b dc.b subs.l,var_c-*-1,z n.b. this still allows a lot of bad constructs!
var_c dc.b cbr.s,var_a-*-1,z

* Separated parameter list
splst_a dc.b q,sep.b,splst_a-*-2,hsh.s,splst_b-*-4
splst_b dc.b                                         expr.l,splst_c-*-1,z
splst_c dc.b sep.b,splst_a-*-1,q,z

* Subscription parameter list (as good as we can manage...)
subs_0 dc.b q
subs_a dc.b   sep.b,subs_0-*-1
subs_b dc.b                      expr.l,subs_c-*-1,z
subs_c dc.b sep.b,subs_0-*-1,q,z
* If we could insist on specific separators, we could do subscription properly!
* subscript list graph
*subs_a dc.b sube.l,subs_b-*-1,z
*subs_b dc.b q,comsep.b,subs_a-*-2,z
* subscript element graph
*sube_a dc.b septo.b,sube_c-*-1,expr.l,sube_b-*-3,z
*sube_b dc.b q,septo.b,sube_c-*-2,z
*sube_c dc.b q,expr.l,*-*,z

* Literal graph table
lit_a dc.b ocb.s,lit_b-*-1,z
lit_b dc.b expr.l,lit_c-*-1,lit.l,lit_c-*-3,z
lit_c dc.b com.s,lit_b-*-1,ccb.s,*-*,z

tabset macro max
[.lab] dc.b [max]
k setstr k[.l]
kno setnum 0
plp maclab
kno setnum [kno]+1
 dc.b [k][kno]-[.lab]
 ifnum [kno] < [max] goto plp
kno setnum 1
kfoll setnum 0
 endm

tab macro
i setnum 0
tlp maclab
i setnum [i]+1
 ifnum [i] > [.nparms] goto tex
this setstr [.parm([i])]
 ifnum [.len(this)] > 1 goto defit
kfoll setnum [this]
 goto tlp 
defit maclab
[k][kno] dc.b [.len(this)]<<4![kfoll],'[this]'
kfoll setnum 0
kno setnum [kno]+1
 goto tlp
tex maclab
 endm

tabend macro
k[kno] ds.b 0
 endm

* Keywords

pa_kytab tabset 31 ; Note we can ONLY have $1f keywords
        tab     6 END FOR IF REPeat SELect WHEN 2 DEFine PROCedure FuNction
        tab     2 GO TO SUB 1 WHEN ERRor GO GO
* Next time we need keywords, replace the last pair above
* They used to be "END ERRor", and earlier "EOF INPUT"!
* Using "GO", which has already been parsed and rejected, saves 4 bytes.
        tab     RESTORE NEXT EXIT ELSE ON RETurn REMAINDER DATA DIM
        tab     LOCal LET THEN STEP REMark MISTake
        tabend

        vect4000 pa_expr

        end
