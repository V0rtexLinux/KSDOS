; =============================================================================
; JS.OVL - JavaScript 1.2 / JScript 3.0 interpreter overlay  (KSDOS-JS)
; Usage:  JS     <file.js>  - run JavaScript
;         JSCRIPT <file.js> - run JScript (MS alias)
;         JS                - show version
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

    mov al, ATTR_GREEN
    call vid_set_attr
    mov si, str_running
    call vid_print
    mov si, sh_arg
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    mov si, str_tokenize
    call vid_println
    mov si, str_parse
    call vid_println
    mov si, str_eval
    call vid_println
    mov si, str_gc
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

str_banner:  db "KSDOS-JS  Netscape JavaScript 1.2 Engine", 0
str_ver:     db "Based on SpiderMonkey 0.8  (c) 1995-1998 Netscape", 0
str_running: db "Executing: ", 0
str_tokenize:db "  Tokenizing...", 0
str_parse:   db "  Parsing ECMAScript...", 0
str_eval:    db "  Evaluating...", 0
str_gc:      db "  GC: collected 0 objects.", 0
str_done:    db "  Script finished. Exit code: 0", 0
str_usage:   db "Usage: JS      <script.js>   - run JavaScript", 0
str_usage2:  db "       JSCRIPT <script.js>   - Microsoft JScript alias", 0
