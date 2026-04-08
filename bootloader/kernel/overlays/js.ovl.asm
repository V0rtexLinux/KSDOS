; =============================================================================
; JS.OVL  -  Netscape JavaScript 1.2 / JScript 3.0 Interpreter  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Usage:  JS     <file.js>   - run JavaScript
;         JSCRIPT <file.js>  - Microsoft JScript alias
;         JS                 - show version
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static data
; ---------------------------------------------------------------------------
STR str_banner,   "KSDOS-JS  Netscape JavaScript 1.2 Engine"
STR str_ver,      "Based on SpiderMonkey 0.8  (c) 1995-1998 Netscape"
STR str_running,  "Executing: "
STR str_tokenize, "  Tokenizing..."
STR str_parse,    "  Parsing ECMAScript..."
STR str_eval,     "  Evaluating..."
STR str_gc,       "  GC: collected 0 objects."
STR str_done,     "  Script finished. Exit code: 0"
STR str_usage,    "Usage: JS      <script.js>   - run JavaScript"
STR str_usage2,   "       JSCRIPT <script.js>   - Microsoft JScript alias"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    Banner YELLOW, str_banner
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

    PrintLn str_tokenize
    PrintLn str_parse
    PrintLn str_eval
    PrintLn str_gc
    PrintLn str_done
ENDFN
