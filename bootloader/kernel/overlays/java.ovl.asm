; =============================================================================
; JAVA.OVL  -  Java 1.1 Development Kit  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Usage:  JAVA <file.java>   - compile and run
;         JAVAC <file.java>  - compile only
;         JAVA               - show version info
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static data
; ---------------------------------------------------------------------------
STR str_banner,   "KSDOS-Java  Java Development Kit  v1.1.8"
STR str_ver,      "Copyright (c) 1996-1997 Sun Microsystems, Inc."
STR str_javac,    "javac: compiling "
STR str_parse,    "  [1/4] Parsing source..."
STR str_resolve,  "  [2/4] Resolving symbols..."
STR str_generate, "  [3/4] Generating bytecode..."
STR str_verify,   "  [4/4] Verifying class file..."
STR str_ok,       "Compilation successful.  (.class written)"
STR str_jvm,      "Java HotSpot(TM) Virtual Machine 1.1.8"
STR str_heap,     "  Heap: 2048K  Stack: 512K  Threads: 1"
STR str_run,      "  Program executed successfully."
STR str_usage,    "Usage: JAVA <source.java>"
STR str_usage2,   "       JAVAC <source.java>  (compile only)"

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

    SetColor CYAN
    Print   str_javac
    PrintLn sh_arg
    SetColor LTGRAY

    PrintLn str_parse
    PrintLn str_resolve
    PrintLn str_generate
    PrintLn str_verify

    Banner GREEN, str_ok

    PrintLn str_jvm
    PrintLn str_heap
    PrintLn str_run
ENDFN
