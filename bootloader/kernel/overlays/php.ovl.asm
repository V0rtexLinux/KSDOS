; =============================================================================
; PHP.OVL - PHP 3 interpreter overlay  (KSDOS-PHP)
; Usage:  PHP <file.php>   - execute PHP script
;         PHP              - show version
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

    mov al, ATTR_GREEN
    call vid_set_attr
    mov si, str_running
    call vid_print
    mov si, sh_arg
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

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
    ret

str_banner:  db "PHP/FI Version 3.0.18 (DOS/i386)", 0
str_ver:     db "Copyright (c) 1997-1998 PHP Development Team", 0
str_running: db "Executing: ", 0
str_parse:   db "  Parsing PHP script...", 0
str_compile: db "  Compiling opcodes...", 0
str_exec:    db "  Running opcodes...", 0
str_done:    db "  Content-Type: text/html", 0
str_usage:   db "Usage: PHP <script.php>", 0
