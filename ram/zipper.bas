100 REMark Save Minerva sources
110 :
120 IF VER$(-1):OPEN#1;'con_190x50a258x206':BORDER 1,255:CLS:POKE_L\48\0,PEEK_L(\48\40)
130 w$='ram1_temp':p$='dev7_m_':t$='flp1_'
140 INPUT'Ready to FORMAT disc in'!t$&'?';r$
150 f$=DATE$:f$=t$&'M'&f$(3TO 4)&f$(6TO 8)&f$(10TO 11)&' Z':FORMAT f$
160 :
170 dircop'RAM':dircop'INC':DELETE w$
180 l$='ROM':zip$=l$:f$=l$&'_link':cop f$:zipem:COPY p$&f$,w$&0:OPEN_IN#3;w$&0
190 REPeat lp
200  IF EOF(#3):EXIT lp
210  INPUT#3;l$:IF LEN(l$)<9:NEXT lp
220  l$=l$(p$INSTR l$+LEN(p$)TO)
230  l$=l$(1TO LEN(l$)-4)
240  zip$=l$:f$=l$&'_cct':cop f$:COPY p$&f$,w$&1:OPEN_IN#4;w$&1
250  PRINT!l$;:REPeat ll
260   IF EOF(#4):EXIT ll
270   INPUT#4;m$:IF LEN(m$)<9:NEXT ll
280   m$=m$(p$&l$INSTR m$+LEN(p$)TO)
290   cop m$(1TO LEN(m$)-4)&'_asm'
300   END REPeat ll:CLOSE#4:DELETE w$&1:zipem
310  END REPeat lp:CLOSE:STAT t$
320 DELETE w$:DELETE w$&0:PRINT!'Done':CLEAR
330 :
340 DEFine PROCedure dircop(y$)
350  zip$=y$:OPEN_OVER#3;w$:WDIR#3;p$&y$:GET#3\0
360  REPeat lp:IF EOF(#3):EXIT lp:ELSE INPUT#3;m$:cop m$(3TO)
370  CLOSE#3:zipem:END DEFine
380 :
390 DEFine PROCedure zipem:EXEC_W'zip';'-9 '&t$&zip$;:END DEFine
400 :
410 DEFine PROCedure cop(z$):zip$=zip$&' '&p$&z$:END DEFine
420 :
430 DEFine PROCedure saveme:SAVE'dev7_m_ram_zipper_bas':END DEFine
440 :
