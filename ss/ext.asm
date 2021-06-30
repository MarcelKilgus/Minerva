* Data to be put at the base of the system variables extension area
        xdef    ss_ext

        xref    mm_rechp
        xref    tb_f0,tb_f1,tb_itrn,tb_kbenc,tb_otrn,tb_msg,tb_trn

        section ss_ext

ss_ext          ;               user routine to call on shift/ctrl/alt/enter
        dc.w    tb_itrn-*       input tranlation routine
        dc.w    tb_otrn-*       output translation routine
        dc.w    mm_rechp-*      memory management driver, close entry point

        dc.w    tb_kbenc-*      keyboard encoder routine
        dc.w    0               linked list of routines to front end mt.ipcom
        dc.w    0               reserved
        dc.w    0               reserved

        dc.w    tb_trn-*        default i/o translation table address
        dc.w    tb_msg-*        default message table address
        dc.w    tb_f0-*         default primary font
        dc.w    tb_f1-*         default secondary font

* A zero word delimits the constants
        dc.b    0               real display mode
        dc.b    0               suppress flags: bit 7 = format with files open
        dc.b    0               event byte: bits 4-7 toggled by ip_kybrd:
        ;break job 0 basic      ctrl/space              bit 4
        ;break all multibasic's ctrl/alt/space          bit 5
        ;first user kbd event   shift/ctrl/space        bit 6
        ;second user kbd event  shift/ctrl/alt/space    bit 7
        dc.b    10<<3!0<<3!3    cursor flash rate, size and color
        dc.l    $ffffffff,$fff9ffff,$ffffe0ff special key remap table
        ;       freeze screen   ctrl/alt/tab            ctrl/f5
        ;       caps lock       shift/ctrl/enter        caps lock

        dc.w    '1.98',4,'JSL1'
*       dc.w    0,0,0           reserved

        end
