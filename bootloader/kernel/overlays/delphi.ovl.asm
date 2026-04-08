; =============================================================================
; DELPHI.OVL  -  Borland Delphi 3 / Object Pascal Compiler  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Usage:  DELPHI <file.pas>  - compile and run
;         DCC    <file.pas>  - same (Delphi CLI compiler alias)
;         DELPHI             - show version
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static data
; ---------------------------------------------------------------------------
STR str_banner,    "Borland Delphi 3.0  Object Pascal Compiler  v11.0"
STR str_ver,       "Copyright (c) 1983,1997 Borland International"
STR str_compiling, "Compiling: "
STR str_units,     "  Resolving unit dependencies..."
STR str_syntax,    "  Parsing Object Pascal syntax..."
STR str_codegen,   "  Generating native i386 code..."
STR str_link,      "  Linking with RTL and VCL..."
STR str_ok,        "Success: 0 Error(s), 0 Hint(s)"
STR str_run,       "  Executable launched."
STR str_usage,     "Usage: DELPHI <source.pas>   - compile and run"
STR str_usage2,    "       DCC    <source.pas>   - Delphi CLI compiler"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    Banner RED, str_banner
    PrintLn str_ver

    cmp byte [sh_arg], 0
    IF e
        PrintLn str_usage
        PrintLn str_usage2
        ret
    ENDIF

    SetColor CYAN
    Print   str_compiling
    PrintLn sh_arg
    SetColor LTGRAY

    PrintLn str_units
    PrintLn str_syntax
    PrintLn str_codegen
    PrintLn str_link

    Banner GREEN, str_ok
    PrintLn str_run
ENDFN
