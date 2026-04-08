; =============================================================================
; PERL.OVL  -  Perl 5 Interpreter  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Usage:  PERL <file.pl>   - run Perl script
;         PERL             - show version
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static data
; ---------------------------------------------------------------------------
STR str_banner,  "This is perl, version 5.004_04 built for i386-msdos"
STR str_ver,     "Copyright 1987-1998 Larry Wall"
STR str_running, "Running: "
STR str_lex,     "  Lexing and parsing..."
STR str_optree,  "  Building op-tree..."
STR str_exec,    "  Executing..."
STR str_done,    "  Script exited with status 0."
STR str_usage,   "Usage: PERL <script.pl>"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    Banner MAGENTA, str_banner
    PrintLn str_ver

    cmp byte [sh_arg], 0
    IF e
        PrintLn str_usage
        ret
    ENDIF

    SetColor CYAN
    Print   str_running
    PrintLn sh_arg
    SetColor LTGRAY

    PrintLn str_lex
    PrintLn str_optree
    PrintLn str_exec
    PrintLn str_done
ENDFN
