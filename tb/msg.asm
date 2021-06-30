* Default message tables
        xdef    tb_msg

* This file holds all the error messages etc. which are language dependent.
* This is linked at the top of a ROM (in ROM based systems) to make language
* versions easier to implement.

msg     macro
        dc.w    x[.l]-tb_msg
        section tb_txt
x[.l]
        ifstr   {[.ext]} = B goto nolen
        dc.w    y[.l]-*-2
nolen   maclab
i       setnum  0
loop    maclab
i       setnum  [i]+1
        dc.b    [.parm([i])]
        ifnum   [i] < [.nparms] goto loop
y[.l]
        ds.w    0
        section tb_msg
        endm

lf      equ     10

        section tb_msg

tb_msg
        dc.w    $4afb
        msg     {'not complete'},lf
        msg     {'invalid job'},lf
        msg     {'out of memory'},lf
        msg     {'out of range'},lf
        msg     {'buffer full'},lf
        msg     {'channel not open'},lf
        msg     {'not found'},lf
        msg     {'already exists'},lf
        msg     {'in use'},lf
        msg     {'end of file'},lf
        msg     {'drive full'},lf
        msg     {'bad name'},lf
        msg     {'Xmit error'},lf
        msg     {'format failed'},lf
        msg     {'bad parameter'},lf
        msg     {'bad or changed medium'},lf
        msg     {'error in expression'},lf
        msg     {'overflow'},lf
        msg     {'not implemented yet'},lf
        msg     {'read only'},lf
        msg     {'bad line'},lf
        msg     {'At line '}
        msg     {' sectors'},lf
        msg     {' F1/F2 sets monitor/TV'},lf \
                {' F3/F4 for dual screen'},lf \
                {' 128K+SHIFT  dumb+CTRL'}
        msg     {'  The QView Mega Corporation!'}
        msg     {'during WHEN processing'},lf
        msg     {'PROC/FN cleared'},lf
        msg.b   {'SunMonTueWedThuFriSat'}
        msg.b   {'JanFebMarAprMayJunJulAugSepOctNovDec'}

        end
