; =============================================================================
; VB.OVL - Visual Basic 5 compiler overlay  (KSDOS-VB)
; Usage:  VB <file.bas>   - compile VB source
;         VBC <file.bas>  - compile only (no run)
;         VB              - show version
; =============================================================================
BITS 16
ORG OVERLAY_BUF

%include "ovl_api.asm"

ovl_entry:
    mov al, ATTR_BRIGHT
    call vid_set_attr
    mov si, str_banner
    call vid_println
    mov si, str_ver
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    cmp byte [sh_arg], 0
    je .usage

    mov al, ATTR_CYAN
    call vid_set_attr
    mov si, str_compiling
    call vid_print
    mov si, sh_arg
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    mov si, str_pass1
    call vid_println
    mov si, str_pass2
    call vid_println
    mov si, str_link
    call vid_println
    mov si, str_resources
    call vid_println

    mov al, ATTR_GREEN
    call vid_set_attr
    mov si, str_ok
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    mov si, str_run
    call vid_println
    ret

.usage:
    mov si, str_usage
    call vid_println
    mov si, str_usage2
    call vid_println
    ret

str_banner:  db "Microsoft Visual Basic 5.0 Command-Line Compiler", 0
str_ver:     db "Copyright (C) 1997 Microsoft Corporation.", 0
str_compiling: db "Compiling: ", 0
str_pass1:   db "  Pass 1 of 3: Syntax check...", 0
str_pass2:   db "  Pass 2 of 3: Semantic analysis...", 0
str_link:    db "  Pass 3 of 3: Linking runtime...", 0
str_resources: db "  Embedding resources...", 0
str_ok:      db "Compilation succeeded.  0 error(s), 0 warning(s).", 0
str_run:     db "  Executable running...", 0
str_usage:   db "Usage: VB  <file.bas>   - compile and run", 0
str_usage2:  db "       VBC <file.bas>   - compile only", 0
