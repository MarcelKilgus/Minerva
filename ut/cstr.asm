* Compares strings
        xdef    ut_istr,ut_cstr,ut_csstr

        xref    pa_alfnm

        include 'dev7_m_inc_assert'
        include 'dev7_m_inc_vect4000'

        section ut_cstr

* Type is passed as the two lsb's of d0:
* Bit 0 is set for case insensitive
* Bit 1 is set to process embedded numbers (some digits and an optional point)
 
* ut_istr
* d0 -i o- return 0 always (ccr set)
* d1 -  o- zero if not found, or index where found
* a0 -ip - string to search for, prefixed by length
* a1 -ip - string to look in, prefixed by length
* d2-d3 destroyed

* ut_cstr
* d0 -i o- return -1 if (a0)<(a1), 0 for equality, or +ve (ccr set)
* a0 -ip - string to search for, prefixed by length
* a1 -ip - string to look in, prefixed by length

* ut_csstr
* d0 -i o- return -1 if (a0)<(a1), 0 for equality, or +ve (ccr set)
* d2 -ip - length of string at a0
* a0 -ip - string to search for
* a1 -ip - string to look in, prefixed by length

* Characters are converted to one of the following patterns:
* 00000000 00000000 - end of string
* 00000000 00110nnn - digit, as it came in
* 1000000c c1ccccck - letter, original case bit forced on, k=1 for lowercase
* 1000000c c1ccccc1 - letter, original case bit forced on, case insensitive
* 1111111x xxxxxxxx - other character, more high bits set by adding $ff00-'.'.
* Order is unsigned.
* Note that digits are recognised by being words greater than zero.
* Note that decimal point is semi-recognised by the lsb being zero, as it
* happens, the code sorts out the difference between it and end of string.

* General register usage:
* d0   type in bit 1..0 / 1 or -1 inside / return as -1, 0 or 1 (.l) + ccr
* d1.w processed character from main string
* d2   working register
* d3.w processed character from other string
* d4.w mask sets char to standard case, maybe preserving case distinction
* d5   odd useful short-term constants
* d6   save end of searched string
* a0   pointer to main string
* a1   pointer to other string
* a2   end of main string
* a3   end of other string
* a4   address of comparison state-routine
* a5   points to get_char throughout
* a6   base address of strings

* a0 -i o- points to char (a6,a0.l) and always incremented
* a2 -ip - end-of-string
* d1 -  o- set to character with shift and translate
* d4 -ip - mask for setting bits in letter codes
* d2.l destroyed
get_char
        moveq   #0,d1           char value for string end (sorted first)
        cmp.l   a2,a0           off end of string?
        bge.s   get_done        yes, then return the special value

        jsr     pa_alfnm(pc)    find mode of 1st char into d2
        ; d1.l has character    d1: 00000000 cccccccc
        ; d2.l has mode, 0=digit, 1=uppercase, 2=other, 3=lowercase
        ; ccr: z for digit, c for alpha
        bcs.s   get_alpha       go do bits for alpha
        beq.s   get_done        digits are left as they come (+ve, >0)
        add.w   #$ff00-'.',d1   d1: 1111111x xxxxxxxx
get_done
        addq.l  #1,a0           point to next character in/past string
        rts                     (above ensures we can backtrack easily)

get_alpha
        asr.b   #2,d2           put case (0=upper, 1=lower) into x
        addx.w  d1,d1           d1: 0000000c ccccccck 
        or.w    d4,d1           d1: 1000000c c1ccccck
        bra.s   get_done        k is clear iff case sensitive and u/c

istrsave reg    d4-d6/a0-a5
istrkeep reg    d1-d2/a0-a2/a4

ut_istr
        move.l  a1,d1           set starting position
        movem.l istrsave,-(sp)
        and.b   #1,d0           meaningless to try embedded numeric
        bsr.s   set_all
        move.l  a3,d6           hold onto end addr of real longer string
istr_lp
        lea     0(a1,d2.w),a3   set string of same length as (a0)
        cmp.l   d6,a3           string off end?
        bgt.s   not_sstr
        movem.l istrkeep,-(sp)  save registers we need to preserve
        bsr.s   str_comp        check substring
        movem.l (sp)+,istrkeep  reload regs
        addq.l  #1,a1           move on to next slice
        bne.s   istr_lp
        subq.l  #2,a1
        move.l  a1,d1
not_sstr
        movem.l (sp)+,istrsave
        sub.l   a1,d1
        moveq   #0,d0           always say no error
        rts

* N.B. Qliberator fudges about so it can use the internal version of compare
* string, which doesn't require the string lengths on the front of the strings,
* but expects registers to have been set up. Changing "set_all" has caused some
* hassle, as has moving the marked code below. As a warning, all the code lines
* that are critical are marked with ";!"

set_all
        move.w  0(a6,a0.l),d2   get character count
        addq.l  #2,a0           point to first char of main (look for) string
set_2nd
        lea     0(a0,d2.w),a2   set end pointer
        move.w  0(a6,a1.l),a3   get character count
        addq.l  #2,a1           point to first char of other (look in) string
        add.l   a1,a3           set end pointer
set_some ; the above has been done for us by Qlib ;!
        move.w  #$8020,d4       letter bit and blank out case
        asr.b   #1,d0           ignore case to x
        addx.b  d4,d4           put it in ls bit of word
        lea     get_char,a5      frequently used routine
        asr.b   #1,d0           move special to x, ignore case flag to bit 8
        lea     c_norm,a4       for modes 0 and 1
        bcc.s   set_done
set_spec
        lea     c_spec,a4       for modes 2 and 3
        moveq   #9,d5           used to check for digits
set_done
        rts

* The routines are organised as a finite-state machine, with the state in a4.
* The actions to take depend on the state, and the characters encountered.
* notation is as follows:

        ; Characters:

        ; d - digit 0..9
        ; . - the character '.'
        ; f - a digit, or '.' followed by a digit
        ; x - any non-digit character (including '.')
        ; ? - any character

        ; Actions:
        ; lex   - exit if unequal, or if both chars are eos. else absorb both
        ; >             - exit 'greater than'
        ; <             - exit 'less than'
        ; absorb        - advance string pointer
        ; absorb both   - advance both string pointers
        ; enter         - change to appropriate state


* Qlib: cstrsave must avoid the set of registers d1-d6/a0-a5 (MG+ ROM) ;!
* Much simpler entry fudging and no need to restrict our code so much. ;!
* Qlib checks the word at ut_istr for the MG-type movem instruction. ;!
qlib_comp ;!
        move.l  d4,d0
        rol.l   #1,d0           put type code back into d0 bits 1..0
        bra.s   qlib_c1

cstrsave reg    d1-d5/a0-a5     never make this d1-d6/a0-a5 ;!
ut_cstr ;!
        assert  $06 ut_cstr-qlib_comp ; for Qlib ;!
        movem.l cstrsave,-(sp) ; see above for this instrn and Qlib ;!
        bsr.s   set_all
strcom
        bsr.s   str_comp
        movem.l (sp)+,cstrsave
        rts

* New entry point:
* Same as ut_cstr, except that a0 points at chars and d2 has length
ut_csstr
        assert  $06 ut_cstr-qlib_comp ; for Qlib ;!
        movem.l cstrsave,-(sp) ; see above for this instrn and Qlib ;!
        bsr.s   set_2nd
        bra.s   strcom

qlib_c1
        bsr.s   set_some        Qlib already has a0-a3 ready
str_comp
        moveq   #1,d0           start up with exit code 1 for str(a0) > str(a1)
        bra.s   norm_loop

        ; Last bit of fraction handling before we get started at the top level
        ; Trim off any trailing zeroes, but exit if a non-zero digit is seen
c_tzero
        jsr     (a5)            absorb the '0'
c_trail
        cmp.w   d5,d1           is main char '0'?
        beq.s   c_tzero         yes - strip trailing zeroes
        tst.w   d1              is main char now some other digit?
        bgt.s   exit            yes - so main string is greater
        bsr.s   set_spec        reset mode to special

        ; Special: (type 2 and 3 comparisons, initial condition)
        ;       f       f       - enter digit mode e
        ;       ?       ?       - lex

        ; Numerical comparison is the special case: both strings should be
        ; figures to provoke this. Once numerical mode is entered, life is
        ; a bit simpler.
c_spec
        tst.w   d1              main char a digit?
        bgt.s   spec_1_is_digit branch if so
        tst.b   d1              no - does it look like a decimal point?
        bne.s   c_norm          no - no numerical comparison
        moveq   #-'0',d2
        add.b   0(a6,a0.l),d2   look at next char
        cmp.b   d5,d2
        bhi.s   c_norm          branch if not a digit
        cmp.l   a2,a0           if the decimal point was the last of string...
        bge.s   c_norm          ... or it wasn't really one, carry on as usual
spec_1_is_digit
        tst.w   d3              other char a digit?
        bgt.s   spec_num_mode   yes - numerical mode
        tst.b   d3              no - does it look like a decimal point?
        bne.s   c_norm          jump if not
        moveq   #-'0',d2
        add.b   0(a6,a1.l),d2   look at next char
        cmp.b   d5,d2
        bhi.s   c_norm          branch if not a digit
        cmp.l   a3,a1           if the decimal point was the last of string...
        blt.s   spec_num_mode   ... or it wasn't really one, carry on as usual

        ; Normal: (type 0 and 1 comparisons)
        ;       ?       ?       - lex
c_norm
        cmp.w   d3,d1           test characters
        bne.s   exit_ne         leave if strings different
        tst.w   d1              end of both strings?
        beq.s   exit_eq         yes - equal!
norm_loop
        jsr     (a5)            get one string's data
sw_a5_a4
        pea     (a4)            finish by going off to current state
        pea     (a5)            return via get_char
swapall
        exg     a1,a0           swap everything over
        exg     a3,a2
        exg     d1,d3
        neg.w   d0              reverse result type
        rts

c_1notd
        tst.w   d3              is second char a digit?
        bgt.s   exit_lt         yes - must be less

        lea     c_point,a4      state change to point mode
        tst.b   d1              does main char look like a decimal point?
        bne.s   c_dp_2          no - don't absorb it
        jsr     (a5)            absorb the decimal point on the main string
c_dp_2
        tst.b   d3              does other char look like a decimal point?
        beq.s   sw_a5_a4        yes - go swap, absorb, then state (c_point)

        ; Point mode:
        ;       d       d       - lex
        ;       ?       0       - absorb 0
        ;       0       ?       - absorb 0
        ;       ?       ?       - enter special
c_point
        tst.w   d3              is second char a digit?
        ble.s   c_trail         no - go strip any zeroes left on main string
        tst.w   d1              are both the chars digits?
        bgt.s   c_norm          yes, so use standard comparison
        bsr.s   swapall         swap strings
        bra.s   c_trail         no - go strip any zeroes left on other string

* Exits - finalise setting of d0 and condition codes

exit_eq
        clr.w   d0
exit_ne
        bcc.s   exit
exit_lt
        neg.w   d0
exit
        ext.l   d0              get ccr right
        rts

        ; At this point, we know that both strings have contained numbers
        ; and we have not passed a decimal point on either string.

        ;       0?      ?       - absorb 0
        ;       ?       0?      - absorb 0
spec_num_mode
        moveq   #'0',d5
        bsr.s   leadzero        strip leading-zeroes
        bsr.s   swapall         ... on both strings
        bsr.s   leadzero
        ; The strings now do not have leading zeros at all
        lea     c_dig_eq,a4

        ; Digit mode equal:
        ;       d       d       - enter digit g/l on lex order. absorb both
        ;       d       x       - >
        ;       x       d       - <
        ;       .       .       - absorb both '.'; enter point mode
        ;       .       x       - absorb '.' - enter point mode
        ;       x       .       - absorb '.' - enter point mode
        ;       x       x       - enter special
c_dig_eq
        tst.w   d1              is main char a digit?
        ble.s   c_1notd         no - go see about second char
        tst.w   d3              is other char a digit?
        ble.s   exit            no - must be greater
        cmp.w   d3,d1           test the two digits
        beq.s   norm_loop       if the digits were equal, go round again
        lea     c_dig_ne,a4     enter digits not equal state
        bcs.s   c_dig_l         if less than, skip first swap

        ; Digit mode not equal:
        ;       d       d       - absorb both
        ;       x       ?       - <
        ;       d       x       - >
c_dig_ne
        bsr.s   swapall         need to keep strings the same way round here
c_dig_l
        tst.w   d1              is the main char a digit?
        ble.s   exit_lt         no, so other is higher
        tst.w   d3              are both the characters digits?
        bgt.s   norm_loop       yes, so absorb them and continue
        bra.s   exit            no, main string is higher

* This routine strips out leading zeros from a number.
* At entry the string pointers always refer to a bona fide number.
* At exit, there are no leading zeros on the string, which may leave nothing of
* the number, but this is OK.
        ;       0?      ?       - absorb 0
leaddrop
        jsr     (a5)            absorb the zero
leadzero
        cmp.w   d5,d1           is first char (or subsequent digit) a '0'?
        beq.s   leaddrop        yes, keep dropping them
        rts

        vect4000 ut_istr

        end
