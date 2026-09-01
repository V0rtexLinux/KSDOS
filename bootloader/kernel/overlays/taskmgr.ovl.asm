; =============================================================================
; TASKMGR.OVL  -  Task Manager style resource monitor  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Live view of conventional + extended memory and video mode. ESC exits.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

STR str_title,   "TASK MANAGER - Performance"
STR str_conv,    "Conventional memory: "
STR str_kb,      " KB total"
STR str_ext,     "Extended memory:     "
STR str_kb2,     " KB (INT 15h/88h)"
STR str_video,   "Video mode:          "
STR str_cols,    "  columns: "
STR str_uptime,  "Uptime (BIOS ticks): "
STR str_footer,  "ESC to exit"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    ClearScreen
    mov dh, 0
    mov dl, 0
    call vid_set_cursor
    SetColor 0x1F
    PrintLn str_title
    SetColor 0x07
    NewLine

    ; static info, printed once
    Print str_conv
    int 0x12
    call print_word_dec
    PrintLn str_kb

    Print str_ext
    mov ah, 0x88
    int 0x15
    call print_word_dec
    PrintLn str_kb2

    Print str_video
    mov ah, 0x0F
    int 0x10
    push ax
    xor ah, ah
    call print_word_dec
    Print str_cols
    pop ax
    mov al, ah
    xor ah, ah
    call print_word_dec
    NewLine
    NewLine

.loop:
    mov dh, 8
    mov dl, 0
    call vid_set_cursor
    Print str_uptime
    xor ax, ax
    int 0x1A                    ; CX:DX = tick count since midnight
    mov ax, dx
    call print_word_dec
    PrintChar ' '
    PrintChar ' '
    PrintChar ' '
    NewLine
    NewLine
    PrintLn str_footer

    mov ah, 0x01
    int 0x16
    jz .loop
    mov ah, 0x00
    int 0x16
    cmp al, 27
    jne .loop
ENDFN
