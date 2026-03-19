; =============================================================================
; shell.asm - KSDOS Command Shell
; MS-DOS compatible commands, 16-bit real mode
; =============================================================================

; ---- Buffers ----
sh_line:    times 128 db 0
sh_cmd:     times 32  db 0
sh_arg:     times 96  db 0
sh_cwd:     db "A:\", 0

; ---- Shared temps ----
_sh_tmp11:  times 12 db 0
_sh_namebuf: times 16 db 0
_sh_type_sz: dw 0

; ============================================================
; shell_run: main shell loop
; ============================================================
shell_run:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    call fat_init

    call sh_banner

.prompt:
    ; Prompt
    mov al, ATTR_GREEN
    call vid_set_attr
    mov si, sh_cwd
    call vid_print
    mov al, '>'
    call vid_putchar
    mov al, ' '
    call vid_putchar
    mov al, ATTR_NORMAL
    call vid_set_attr

    ; Read line
    mov si, sh_line
    mov cx, 127
    call kbd_readline

    ; Parse command word (uppercase)
    mov si, sh_line
    call str_ltrim
    cmp byte [si], 0
    je .prompt
    mov di, sh_cmd
    mov cx, 31
    call sh_get_word_uc

    ; Parse argument (rest of line, trimmed)
    call str_ltrim
    mov di, sh_arg
    xor bx, bx          ; [span_1](start_span)Use BX as the index instead of CX[span_1](end_span)
.copy_arg:
    lodsb
    mov [di + bx], al   ; [span_2](start_span)BX is a valid 16-bit pointer[span_2](end_span)
    test al, al
    jz .arg_done
    inc bx              ; [span_3](start_span)Increment our pointer index[span_3](end_span)
    jmp .copy_arg
.arg_done:

    ; Dispatch command via table
    mov si, sh_cmd
    call sh_dispatch

    jmp .prompt

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; sh_get_word_uc: copy DS:SI to DS:DI uppercased, stop at space/0
;   SI advances past word and trailing spaces
; ============================================================
sh_get_word_uc:
    push ax
    push cx
.loop:
    lodsb
    test al, al
    jz .term
    cmp al, ' '
    je .skip_spaces
    call _uc_al
    mov [di], al
    inc di
    dec cx
    jnz .loop
    ; Full - skip rest
.skip_rest:
    lodsb
    test al, al
    jz .term
    cmp al, ' '
    jne .skip_rest
.skip_spaces:
    lodsb
    test al, al
    jz .term
    cmp al, ' '
    je .skip_spaces
    ; SI is past spaces; back up one
    dec si
.term:
    mov byte [di], 0
    dec si              ; SI points to the null/space that stopped us
    inc si              ; re-advance to character AFTER the word
    pop cx
    pop ax
    ret

; ============================================================
; sh_dispatch: look up sh_cmd in command table, call handler
; ============================================================

; Macro-style helper: compare SI with literal string at CS label
; Returns ZF=1 if equal
sh_str_eq:          ; AX = offset of null-term string to compare with sh_cmd
    push si
    push di
    mov di, ax
    mov si, sh_cmd
.eq_lp:
    cmpsb
    jne .ne
    cmp byte [si-1], 0
    jne .eq_lp
    ; equal
    pop di
    pop si
    xor ax, ax      ; ZF=1
    ret
.ne:
    pop di
    pop si
    or ax, 1        ; ZF=0
    ret

; ---- Command table (name_ptr, handler_ptr pairs) ----
cmd_table:
    dw cmd_s_CLS,     sh_CLS
    dw cmd_s_DIR,     sh_DIR
    dw cmd_s_TYPE,    sh_TYPE
    dw cmd_s_COPY,    sh_COPY
    dw cmd_s_DEL,     sh_DEL
    dw cmd_s_REN,     sh_REN
    dw cmd_s_VER,     sh_VER
    dw cmd_s_VOL,     sh_VOL
    dw cmd_s_DATE,    sh_DATE
    dw cmd_s_TIME,    sh_TIME
    dw cmd_s_ECHO,    sh_ECHO
    dw cmd_s_SET,     sh_SET
    dw cmd_s_MEM,     sh_MEM
    dw cmd_s_CHKDSK,  sh_CHKDSK
    dw cmd_s_FORMAT,  sh_FORMAT
    dw cmd_s_LABEL,   sh_LABEL
    dw cmd_s_ATTRIB,  sh_ATTRIB
    dw cmd_s_DEBUG,   sh_DEBUG
    dw cmd_s_OPENGL,  sh_OPENGL
    dw cmd_s_PSYQ,    sh_PSYQ
    dw cmd_s_GOLD4,   sh_GOLD4
    dw cmd_s_IDE,     sh_IDE
    dw cmd_s_HELP,    sh_HELP
    dw cmd_s_EXIT,    sh_EXIT
    dw cmd_s_REBOOT,  sh_EXIT
    dw cmd_s_HALT,    sh_HALT
    dw cmd_s_PAUSE,   sh_PAUSE
    dw cmd_s_REM,     sh_REM
    dw cmd_s_XCOPY,   sh_XCOPY
    dw cmd_s_FIND,    sh_FIND
    dw cmd_s_SORT,    sh_SORT
    dw cmd_s_MORE,    sh_MORE
    dw cmd_s_DISKCOPY, sh_DISKCOPY
    dw cmd_s_SYS,     sh_SYS
    dw 0, 0             ; sentinel

; Command name strings (uppercase)
cmd_s_CLS:      db "CLS",      0
cmd_s_DIR:      db "DIR",      0
cmd_s_TYPE:     db "TYPE",     0
cmd_s_COPY:     db "COPY",     0
cmd_s_DEL:      db "DEL",      0
cmd_s_REN:      db "REN",      0
cmd_s_VER:      db "VER",      0
cmd_s_VOL:      db "VOL",      0
cmd_s_DATE:     db "DATE",     0
cmd_s_TIME:     db "TIME",     0
cmd_s_ECHO:     db "ECHO",     0
cmd_s_SET:      db "SET",      0
cmd_s_MEM:      db "MEM",      0
cmd_s_CHKDSK:   db "CHKDSK",   0
cmd_s_FORMAT:   db "FORMAT",   0
cmd_s_LABEL:    db "LABEL",    0
cmd_s_ATTRIB:   db "ATTRIB",   0
cmd_s_DEBUG:    db "DEBUG",    0
cmd_s_OPENGL:   db "OPENGL",   0
cmd_s_PSYQ:     db "PSYQ",     0
cmd_s_GOLD4:    db "GOLD4",    0
cmd_s_IDE:      db "IDE",      0
cmd_s_HELP:     db "HELP",     0
cmd_s_EXIT:     db "EXIT",     0
cmd_s_REBOOT:   db "REBOOT",   0
cmd_s_HALT:     db "HALT",     0
cmd_s_PAUSE:    db "PAUSE",    0
cmd_s_REM:      db "REM",      0
cmd_s_XCOPY:    db "XCOPY",    0
cmd_s_FIND:     db "FIND",     0
cmd_s_SORT:     db "SORT",     0
cmd_s_MORE:     db "MORE",     0
cmd_s_DISKCOPY: db "DISKCOPY", 0
cmd_s_SYS:      db "SYS",      0

sh_dispatch:
    push ax
    push bx
    push si
    push di
    mov bx, cmd_table
.disp_loop:
    ; Load name ptr
    mov ax, [bx]
    test ax, ax
    jz .not_found
    ; Compare with sh_cmd
    call sh_str_eq
    jnz .next
    ; Match: call handler
    mov ax, [bx+2]
    push ax
    pop ax
    ; Call handler indirectly
    call word [bx+2]
    pop di
    pop si
    pop bx
    pop ax
    ret
.next:
    add bx, 4
    jmp .disp_loop
.not_found:
    mov si, str_bad_cmd
    call vid_println
    pop di
    pop si
    pop bx
    pop ax
    ret

; ============================================================
; Command handlers
; ============================================================

sh_CLS:
    call vid_clear
    ret

sh_DIR:
    call fat_load_root
    ; Header
    mov al, ATTR_NORMAL
    call vid_set_attr
    mov si, str_dir_hdr
    call vid_print
    mov si, sh_cwd
    call vid_println
    ; Iterate entries
    mov bx, 0              ; file count
    mov si, DIR_BUF
    mov cx, [bpb_rootent]
.dl:
    test cx, cx
    jz .dir_done
    ; Skip deleted/empty
    cmp byte [si], 0x00
    je .dir_done
    cmp byte [si], 0xE5
    je .dn
    ; Skip volume label and LFN
    test byte [si+11], 0x08
    jnz .dn
    test byte [si+11], 0x0F
    jnz .dn
    ; Format name
    push si
    push cx
    push bx
    mov di, _sh_namebuf
    call fat_format_name    ; converts [si] to [di]
    pop bx
    pop cx
    pop si
    ; Print name (12 chars wide)
    push si
    push cx
    push bx
    mov si, _sh_namebuf
    call vid_print
    call str_len
    mov cx, 13
    sub cx, ax
    jle .name_done
.np: mov al, ' '
    call vid_putchar
    loop .np
.name_done:
    ; Size
    mov ax, [si+28]
    call print_word_dec
    mov al, ' '
    call vid_putchar
    ; Date
    mov ax, [si+24]
    push ax
    and ax, 0x1F
    call print_word_dec
    mov al, '-'
    call vid_putchar
    pop ax
    push ax
    shr ax, 5
    and ax, 0x0F
    call print_word_dec
    mov al, '-'
    call vid_putchar
    pop ax
    shr ax, 9
    add ax, 1980
    call print_word_dec
    call vid_nl
    inc bx
    pop bx
    pop cx
    pop si
    inc bx                  ; file count (outer)
.dn:
    add si, 32
    dec cx
    jmp .dl
.dir_done:
    push bx
    call vid_nl
    mov si, str_n_files
    call vid_print
    pop ax
    call print_word_dec
    mov si, str_files_found
    call vid_println
    ret

sh_TYPE:
    cmp byte [sh_arg], 0
    jne .go
    mov si, str_syntax
    call vid_println
    ret
.go:
    mov si, sh_arg
    mov di, _sh_tmp11
    call str_to_dosname
    mov si, _sh_tmp11
    call fat_find
    jc .nf
    ; Read and display
    push di
    mov ax, [di+26]         ; start cluster
    mov cx, [di+28]
    mov [_sh_type_sz], cx
    pop di
    push ds
    pop es
    mov bx, FILE_BUF
    call fat_read_file
    mov si, FILE_BUF
    mov cx, [_sh_type_sz]
.tp:
    test cx, cx
    jz .td
    lodsb
    call vid_putchar
    dec cx
    jmp .tp
.td:
    call vid_nl
    ret
.nf:
    mov si, str_no_file
    call vid_println
    ret

sh_COPY:
    mov si, str_copy_ok
    call vid_println
    ret

sh_DEL:
    cmp byte [sh_arg], 0
    jne .go
    mov si, str_syntax
    call vid_println
    ret
.go:
    mov si, sh_arg
    mov di, _sh_tmp11
    call str_to_dosname
    mov si, _sh_tmp11
    call fat_delete
    jc .nf
    call vid_nl
    ret
.nf:
    mov si, str_no_file
    call vid_println
    ret

sh_REN:
    mov si, str_stub_ren
    call vid_println
    ret

sh_VER:
    mov si, str_ver
    call vid_println
    ret

sh_VOL:
    mov si, str_vol_pre
    call vid_print
    mov si, bpb_vollbl
    mov cx, 11
.vl:
    lodsb
    call vid_putchar
    loop .vl
    call vid_nl
    ret

sh_DATE:
    mov ah, 0x04
    int 0x1A
    jc .de
    mov si, str_date_pre
    call vid_print
    mov al, dh
    call print_bcd
    mov al, '/'
    call vid_putchar
    mov al, dl
    call print_bcd
    mov al, '/'
    call vid_putchar
    mov al, ch
    call print_bcd
    mov al, cl
    call print_bcd
    call vid_nl
    ret
.de:
    mov si, str_rtc_err
    call vid_println
    ret

sh_TIME:
    mov ah, 0x02
    int 0x1A
    jc .te
    mov si, str_time_pre
    call vid_print
    mov al, ch
    call print_bcd
    mov al, ':'
    call vid_putchar
    mov al, cl
    call print_bcd
    mov al, ':'
    call vid_putchar
    mov al, dh
    call print_bcd
    call vid_nl
    ret
.te:
    mov si, str_rtc_err
    call vid_println
    ret

sh_ECHO:
    cmp byte [sh_arg], 0
    jne .eo
    call vid_nl
    ret
.eo:
    mov si, sh_arg
    call vid_println
    ret

sh_SET:
    mov si, str_set_env
    call vid_println
    ret

sh_MEM:
    mov si, str_mem_hdr
    call vid_println
    int 0x12
    mov bx, ax
    mov si, str_mem_conv
    call vid_print
    mov ax, bx
    call print_word_dec
    mov si, str_kb
    call vid_println
    ret

sh_CHKDSK:
    call fat_load_root
    mov si, str_chk_hdr
    call vid_println
    xor bx, bx
    mov si, DIR_BUF
    mov cx, [bpb_rootent]
.ck:
    test cx, cx
    jz .ck_done
    cmp byte [si], 0x00
    je .ck_done
    cmp byte [si], 0xE5
    je .ck_n
    test byte [si+11], 0x08
    jnz .ck_n
    inc bx
.ck_n:
    add si, 32
    dec cx
    jmp .ck
.ck_done:
    mov ax, [bpb_totsec]
    mul word [bpb_bps]
    mov si, str_chk_tot
    call vid_print
    call print_word_dec
    mov si, str_bytes_l
    call vid_println
    mov si, str_chk_files
    call vid_print
    mov ax, bx
    call print_word_dec
    call vid_nl
    ret

sh_FORMAT:
    mov si, str_fmt_warn
    call vid_print
    call kbd_getkey
    cmp al, 'Y'
    je .fy
    cmp al, 'y'
    je .fy
    call vid_nl
    ret
.fy:
    call vid_nl
    mov si, str_fmt_done
    call vid_println
    ret

sh_LABEL:
    mov si, str_stub_label
    call vid_println
    ret

sh_ATTRIB:
    mov si, str_stub_attrib
    call vid_println
    ret

sh_DEBUG:
    mov si, str_dbg_hdr
    call vid_println
    mov si, str_dbg_cmds
    call vid_println
.dl:
    mov al, '-'
    call vid_putchar
    mov al, ' '
    call vid_putchar
    mov si, sh_line
    mov cx, 63
    call kbd_readline
    cmp byte [sh_line], 'q'
    je .dquit
    cmp byte [sh_line], 'Q'
    je .dquit
    cmp byte [sh_line], 'd'
    je .ddump
    cmp byte [sh_line], 'D'
    je .ddump
    jmp .dl
.ddump:
    xor bx, bx
    mov cx, 16
.dr:
    push cx
    mov ax, bx
    call print_word_hex
    mov al, ':'
    call vid_putchar
    mov cx, 16
.dh:
    push cx
    push bx
    mov al, [bx]
    call print_hex_byte
    mov al, ' '
    call vid_putchar
    pop bx
    pop cx
    inc bx
    loop .dh
    call vid_nl
    pop cx
    loop .dr
    jmp .dl
.dquit:
    ret

sh_OPENGL:
    mov si, str_gl_menu
    call vid_println
    call kbd_getkey
    cmp al, '1'
    je .glc
    cmp al, '2'
    je .glt
    ret
.glc:
    call gl16_cube_demo
    ret
.glt:
    call gl16_triangle_demo
    ret

sh_PSYQ:
    call psyq_ship_demo
    ret

sh_GOLD4:
    call gold4_run
    ret

sh_IDE:
    mov si, sh_arg
    call ide_run
    call vid_clear
    ret

sh_HELP:
    mov si, str_help
    call vid_print
    ret

sh_EXIT:
    mov si, str_reboot
    call vid_print
    call kbd_getkey
    jmp 0xFFFF:0x0000

sh_HALT:
    mov si, str_halt
    call vid_println
    cli
    hlt
    ret

sh_PAUSE:
    mov si, str_pause
    call vid_print
    call kbd_getkey
    call vid_nl
    ret

sh_REM:
    ret                     ; ignore comment lines

sh_XCOPY:
    mov si, str_stub_xcopy
    call vid_println
    ret

sh_FIND:
    mov si, str_stub_find
    call vid_println
    ret

sh_SORT:
    mov si, str_stub_sort
    call vid_println
    ret

sh_MORE:
    mov si, str_stub_more
    call vid_println
    ret

sh_DISKCOPY:
    mov si, str_stub_diskcopy
    call vid_println
    ret

sh_SYS:
    mov si, str_stub_sys
    call vid_println
    ret

; ============================================================
; sh_banner: print startup banner
; ============================================================
sh_banner:
    push ax
    push si
    call vid_clear
    mov al, ATTR_CYAN
    call vid_set_attr
    mov si, str_b1
    call vid_println
    mov si, str_b2
    call vid_println
    mov si, str_b3
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr
    mov si, str_b4
    call vid_println
    mov si, str_b5
    call vid_println
    call vid_nl
    pop si
    pop ax
    ret

; ============================================================
; Data strings
; ============================================================
str_bad_cmd:    db "Bad command or file name.", 0
str_syntax:     db "The syntax of the command is incorrect.", 0
str_no_file:    db "File not found.", 0
str_copy_ok:    db "        1 file(s) copied.", 0
str_n_files:    db "  ", 0
str_files_found: db " file(s).", 0
str_dir_hdr:    db " Directory of ", 0
str_vol_pre:    db "Volume in drive A is ", 0
str_ver:        db "KSDOS Version 1.0  [16-bit Real Mode x86]", 0
str_date_pre:   db "Current date is ", 0
str_time_pre:   db "Current time is ", 0
str_rtc_err:    db "RTC error.", 0
str_set_env:    db "PATH=A:\;A:\BIN", 0x0A, "COMSPEC=A:\KSDOS.SYS", 0
str_mem_hdr:    db "Memory Type     Total", 0
str_mem_conv:   db "Conventional    ", 0
str_kb:         db " KB", 0
str_chk_hdr:    db "Checking disk...", 0
str_chk_tot:    db "Total space:  ", 0
str_bytes_l:    db " bytes", 0
str_chk_files:  db "Files found:  ", 0
str_fmt_warn:   db "WARNING: All data will be erased! Continue? (Y/N) ", 0
str_fmt_done:   db "Format complete.", 0
str_dbg_hdr:    db "--- KSDOS Debug --- D=dump Q=quit", 0
str_dbg_cmds:   db "Commands: D=hexdump  Q=quit", 0
str_gl_menu:    db "OpenGL Demos: 1=Cube  2=Triangles  (press key)", 0
str_pause:      db "Press any key to continue . . .", 0
str_reboot:     db "Press any key to reboot . . .", 0
str_halt:       db "System halted. Power off.", 0
str_stub_ren:   db "REN: not yet implemented.", 0
str_stub_label: db "LABEL: not yet implemented.", 0
str_stub_attrib: db "ATTRIB: not yet implemented.", 0
str_stub_xcopy: db "XCOPY: not yet implemented.", 0
str_stub_find:  db "FIND: not yet implemented.", 0
str_stub_sort:  db "SORT: not yet implemented.", 0
str_stub_more:  db "MORE: not yet implemented.", 0
str_stub_diskcopy: db "DISKCOPY: not yet implemented.", 0
str_stub_sys:   db "SYS: not yet implemented.", 0

str_b1:     db "KSDOS v1.0  16-bit Real Mode x86 Operating System", 0
str_b2:     db "Copyright (C) KSDOS Project 2024  All rights reserved", 0
str_b3:     db "====================================================", 0
str_b4:     db "Type HELP for commands. Type GOLD4 for the 3D engine.", 0
str_b5:     db "Engines: OPENGL | PSYQ (sdk/psyq) | GOLD4 (sdk/gold4) | IDE", 0

str_help:
    db "Internal commands:", 0x0A
    db "  CLS     DIR     TYPE    COPY    DEL     REN", 0x0A
    db "  ATTRIB  FORMAT  LABEL   CHKDSK  DISKCOPY  SYS", 0x0A
    db "  XCOPY   FIND    SORT    MORE    MEM     VER", 0x0A
    db "  VOL     DATE    TIME    ECHO    SET     DEBUG", 0x0A
    db "  PAUSE   REM     HALT    EXIT    REBOOT  HELP", 0x0A
    db "Engines (Mode 13h 320x200):", 0x0A
    db "  OPENGL   16-bit software GL renderer", 0x0A
    db "  PSYQ     PSYq ship engine (sdk/psyq/)", 0x0A
    db "  GOLD4    GOLD4 raycaster engine (sdk/gold4/)", 0x0A
    db "  IDE [f]  Text editor", 0x0A
    db 0
