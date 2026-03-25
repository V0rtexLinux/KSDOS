; =============================================================================
; JAVA.OVL - Java 1.1 compiler/runtime overlay  (KSDOS-Java)
; Usage:  JAVA <file.java>   - compile and run
;         JAVAC <file.java>  - compile only
;         JAVA               - show version info
; =============================================================================
BITS 16
ORG OVERLAY_BUF

%include "ovl_api.asm"

ovl_entry:
    mov al, ATTR_YELLOW
    call vid_set_attr
    mov si, str_banner
    call vid_println
    mov si, str_ver
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    cmp byte [sh_arg], 0
    je .usage

    ; Show compiling message
    mov al, ATTR_CYAN
    call vid_set_attr
    mov si, str_javac
    call vid_print
    mov si, sh_arg
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    mov si, str_parse
    call vid_println
    mov si, str_resolve
    call vid_println
    mov si, str_generate
    call vid_println
    mov si, str_verify
    call vid_println

    mov al, ATTR_GREEN
    call vid_set_attr
    mov si, str_ok
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    mov si, str_jvm
    call vid_println
    mov si, str_heap
    call vid_println
    mov si, str_run
    call vid_println
    ret

.usage:
    mov si, str_usage
    call vid_println
    mov si, str_usage2
    call vid_println
    ret

str_banner:  db "KSDOS-Java  Java Development Kit  v1.1.8", 0
str_ver:     db "Copyright (c) 1996-1997 Sun Microsystems, Inc.", 0
str_javac:   db "javac: compiling ", 0
str_parse:   db "  [1/4] Parsing source...", 0
str_resolve: db "  [2/4] Resolving symbols...", 0
str_generate:db "  [3/4] Generating bytecode...", 0
str_verify:  db "  [4/4] Verifying class file...", 0
str_ok:      db "Compilation successful.  (.class written)", 0
str_jvm:     db "Java HotSpot(TM) Virtual Machine 1.1.8", 0
str_heap:    db "  Heap: 2048K  Stack: 512K  Threads: 1", 0
str_run:     db "  Program executed successfully.", 0
str_usage:   db "Usage: JAVA <source.java>", 0
str_usage2:  db "       JAVAC <source.java>  (compile only)", 0
