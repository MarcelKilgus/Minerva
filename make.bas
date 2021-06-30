sub$ = "A1"
r$ = "dev7_m_rom_"
:
DOS_DRIVE 8,'c:\data\QL\roms'
d$ = "dos8_"
:
MAKE "English", "1.98_" & sub$
MAKE "German", "1G98_" & sub$
:
DEFine PROCedure Make(lang$, v$)
  EW QMake;"\c dev7_m \b \0 " & lang$ & " \1 \2"
  :
  DELETE r$ & v$ & "_bin"
  DELETE r$ & v$ & "_map"
  RENAME r$ & lang$,          r$ & v$ & "_bin"
  RENAME r$ & lang$ & "_map", r$ & v$ & "_map"
  adr = ALCHP(48 * 1024)
  LBYTES r$ & v$ & "_bin", adr
  SBYTES_O d$ & "Minerva_" & v$ & ".bin", adr, 48 * 1024
  RECHP adr
END DEFine
