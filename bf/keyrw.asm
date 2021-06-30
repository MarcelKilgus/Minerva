* Basic KEYROW function
        xdef    bf_keyrw,bf_ipcom

        xref    ca_gtin1

        include 'dev7_m_inc_ipcmd'
        include 'dev7_m_inc_mt'
        include 'dev7_m_inc_q'
        include 'dev7_m_inc_sv'

        section bf_keyrw

bf_keyrw
        jsr     ca_gtin1(pc)    get integer params
        bne.s   rts0            propagate any error
        move.w  #2,-(sp)        8 bit result
        move.b  d1,(sp)         the parameter
        clr.l   -(sp)           4 bits long
        move.w  #kbdr_cmd<<8!1,-(sp) read kbd matrix command + 1 param
frame   equ     1+1+4+1+1
        lea     keyrw,a2
        moveq   #mt.extop,d0
        trap    #1
        addq.l  #frame,sp       release local stack space
        move.w  d1,0(a6,a1.l)   put result on arithmetic stack
        moveq   #3,d4           result type is integer
rts0
        rts

keyrw
        move.l  d0,a2           system variables base address
        move.l  sv_keyq(a2),a2  get current keyboard queue
        move.l  q_nxtout(a2),q_nextin(a2) remove all characters from queue
* Entry point to execute ipcom on user stack - called via mt.extop
bf_ipcom
        moveq   #mt.ipcom,d0
        move.l  usp,a3          command on user stack
        trap    #1
        rte

        end
