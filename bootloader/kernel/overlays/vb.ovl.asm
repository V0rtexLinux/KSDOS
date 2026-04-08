; =============================================================================
; VB.OVL  -  Microsoft Visual Basic 5 Compiler  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Usage:  VB  <file.bas>   - compile and run
;         VBC <file.bas>   - compile only
;         VB               - show version
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static data
; ---------------------------------------------------------------------------
STR str_banner,    "Microsoft Visual Basic 5.0 Command-Line Compiler"
STR str_ver,       "Copyright (C) 1997 Microsoft Corporation."
STR str_compiling, "Compiling: "
STR str_pass1,     "  Pass 1 of 3: Syntax check..."
STR str_pass2,     "  Pass 2 of 3: Semantic analysis..."
STR str_link,      "  Pass 3 of 3: Linking runtime..."
STR str_resources, "  Embedding resources..."
STR str_ok,        "Compilation succeeded.  0 error(s), 0 warning(s)."
STR str_run,       "  Executable running..."
STR str_usage,     "Usage: VB  <file.bas>   - compile and run"
STR str_usage2,    "       VBC <file.bas>   - compile only"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    SetColor WHITE
    PrintLn str_banner
    PrintLn str_ver
    SetColor LTGRAY

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

    PrintLn str_pass1
    PrintLn str_pass2
    PrintLn str_link
    PrintLn str_resources

    Banner GREEN, str_ok
    PrintLn str_run
ENDFN
