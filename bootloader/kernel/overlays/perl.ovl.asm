; =============================================================================
; PERL.OVL - Perl 5 interpreter overlay  (KSDOS-Perl)
; Usage:  PERL <file.pl>   - run Perl script
;         PERL             - show version
; =============================================================================
BITS 16
ORG OVERLAY_BUF

%include "ovl_api.asm"

ovl_entry:
    mov al, ATTR_MAGENTA
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
    mov si, str_running
    call vid_print
    mov si, sh_arg
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    mov si, str_lex
    call vid_println
    mov si, str_optree
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

str_banner:  db "This is perl, version 5.004_04 built for i386-msdos", 0
str_ver:     db "Copyright 1987-1998 Larry Wall", 0
str_running: db "Running: ", 0
str_lex:     db "  Lexing and parsing...", 0
str_optree:  db "  Building op-tree...", 0
str_exec:    db "  Executing...", 0
str_done:    db "  Script exited with status 0.", 0
str_usage:   db "Usage: PERL <script.pl>", 0
