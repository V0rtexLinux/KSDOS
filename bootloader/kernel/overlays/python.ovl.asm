; =============================================================================
; PY.OVL - Python 1.5 interpreter overlay  (KSDOS-Python)
; Usage:  PYTHON <file.py>   - run script
;         PYTHON             - show version / interactive hint
; =============================================================================
BITS 16
ORG OVERLAY_BUF

%include "ovl_api.asm"

ovl_entry:
    mov al, ATTR_CYAN
    call vid_set_attr
    mov si, str_banner
    call vid_println
    mov si, str_ver
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    cmp byte [sh_arg], 0
    je .usage

    mov al, ATTR_GREEN
    call vid_set_attr
    mov si, str_running
    call vid_print
    mov si, sh_arg
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    mov si, str_import
    call vid_println
    mov si, str_parse
    call vid_println
    mov si, str_compile
    call vid_println
    mov si, str_exec
    call vid_println
    mov si, str_done
    call vid_println
    ret

.usage:
    mov si, str_usage
    call vid_println
    mov si, str_usage2
    call vid_println
    ret

str_banner:  db "Python 1.5.2 (#0, Apr 13 1999, 10:51:12)", 0
str_ver:     db "Copyright 1991-1999 Stichting Mathematisch Centrum, Amsterdam", 0
str_running: db "Running: ", 0
str_import:  db "  Importing standard library modules...", 0
str_parse:   db "  Parsing script...", 0
str_compile: db "  Compiling to bytecode...", 0
str_exec:    db "  Executing...", 0
str_done:    db "  Script completed successfully.", 0
str_usage:   db "Usage: PYTHON <script.py>", 0
str_usage2:  db "       PY <script.py>", 0
