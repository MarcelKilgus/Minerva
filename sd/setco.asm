* Sets up colour of ink or paper
        xdef    sd_setco

        xref    cs_color

        include 'dev7_m_inc_sd'

        section sd_setco

* d0 -i o- paper, strip or ink key / error code
* d1 -i  - required colour
* a0 -ip - address of definition block
* a1 -   - address of colour mask

sd_setco
        move.b  d1,sd_pcolr-sd.setpa(a0,d0.w) set colour byte
        lsl.w   #2,d0           select mask by quadrupling d0
        lea     sd_pmask-sd.setpa<<2(a0,d0.w),a1 get address
        moveq   #0,d0           clear error flag
        jmp     cs_color(pc)    go set up colour masks

        end
