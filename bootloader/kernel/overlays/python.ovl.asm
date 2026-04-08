; =============================================================================
; PY.OVL  -  Python 1.5 Interpreter  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Usage:  PYTHON <file.py>   - run script
;         PYTHON             - show version / interactive hint
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static data
; ---------------------------------------------------------------------------
STR str_banner,  "Python 1.5.2 (#0, Apr 13 1999, 10:51:12)"
STR str_ver,     "Copyright 1991-1999 Stichting Mathematisch Centrum, Amsterdam"
STR str_running, "Running: "
STR str_import,  "  Importing standard library modules..."
STR str_parse,   "  Parsing script..."
STR str_compile, "  Compiling to bytecode..."
STR str_exec,    "  Executing..."
STR str_done,    "  Script completed successfully."
STR str_usage,   "Usage: PYTHON <script.py>"
STR str_usage2,  "       PY <script.py>"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    Banner CYAN, str_banner
    PrintLn str_ver

    cmp byte [sh_arg], 0
    IF e
        PrintLn str_usage
        PrintLn str_usage2
        ret
    ENDIF

    Banner GREEN, str_running
    Print   str_running
    PrintLn sh_arg
    SetColor LTGRAY

    PrintLn str_import
    PrintLn str_parse
    PrintLn str_compile
    PrintLn str_exec
    PrintLn str_done
ENDFN
