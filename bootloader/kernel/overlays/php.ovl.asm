; =============================================================================
; PHP.OVL  -  PHP 3 Interpreter  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Usage:  PHP <file.php>   - execute PHP script
;         PHP              - show version
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static data
; ---------------------------------------------------------------------------
STR str_banner,  "PHP/FI Version 3.0.18 (DOS/i386)"
STR str_ver,     "Copyright (c) 1997-1998 PHP Development Team"
STR str_running, "Executing: "
STR str_parse,   "  Parsing PHP script..."
STR str_compile, "  Compiling opcodes..."
STR str_exec,    "  Running opcodes..."
STR str_done,    "  Content-Type: text/html"
STR str_usage,   "Usage: PHP <script.php>"

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
        ret
    ENDIF

    Banner GREEN, str_running
    Print   str_running
    PrintLn sh_arg
    SetColor LTGRAY

    PrintLn str_parse
    PrintLn str_compile
    PrintLn str_exec
    PrintLn str_done
ENDFN
