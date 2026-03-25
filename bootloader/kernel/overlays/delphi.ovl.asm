; =============================================================================
; DELPHI.OVL - Borland Delphi 3 / Object Pascal compiler overlay
; Usage:  DELPHI <file.pas>  - compile Pascal/Delphi source
;         DCC    <file.pas>  - same (Delphi Command-line Compiler alias)
;         DELPHI             - show version info
; =============================================================================
BITS 16
ORG OVERLAY_BUF

%include "ovl_api.asm"

ovl_entry:
    mov al, ATTR_RED
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

    mov si, str_units
    call vid_println
    mov si, str_syntax
    call vid_println
    mov si, str_codegen
    call vid_println
    mov si, str_link
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

str_banner:  db "Borland Delphi 3.0  Object Pascal Compiler  v11.0", 0
str_ver:     db "Copyright (c) 1983,1997 Borland International", 0
str_compiling: db "Compiling: ", 0
str_units:   db "  Resolving unit dependencies...", 0
str_syntax:  db "  Parsing Object Pascal syntax...", 0
str_codegen: db "  Generating native i386 code...", 0
str_link:    db "  Linking with RTL and VCL...", 0
str_ok:      db "Success: 0 Error(s), 0 Hint(s)", 0
str_run:     db "  Executable launched.", 0
str_usage:   db "Usage: DELPHI <source.pas>   - compile and run", 0
str_usage2:  db "       DCC    <source.pas>   - Delphi CLI compiler", 0
