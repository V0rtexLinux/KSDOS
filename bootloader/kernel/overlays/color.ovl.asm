; =============================================================================
; COLOR.OVL  -  Color palette demo  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
;
; Draws the full 8 background x 16 foreground CGA/VGA text attribute grid,
; one swatch per combination, so every colour KSDOS can put on screen is
; visible at once. All loop state lives in memory (not registers) so it
; survives calls into the kernel's video jump table untouched.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Loop state
; ---------------------------------------------------------------------------
U8 clr_bg,   0
U8 clr_fg,   0
U8 clr_row,  2
U8 clr_col,  0
U8 clr_attr, 0

STR str_title, "COLOR - VGA Text Attribute Grid"
STR str_sub,   "8 backgrounds x 16 foregrounds - every KSDOS text colour"
STR str_bg,    "bg "
STR str_colon, ": "
STR str_note,  "Attribute byte = (background << 4) | foreground"
STR str_exit,  "Press any key to exit..."

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
    PrintLn str_sub

    mov byte [clr_row], 2
    mov byte [clr_bg], 0
.bg_loop:
    cmp byte [clr_bg], 8
    jge .bg_done

    mov dh, [clr_row]
    mov dl, 0
    call vid_set_cursor
    SetColor 0x0F
    Print str_bg
    movzx ax, byte [clr_bg]
    call print_word_dec
    SetColor 0x07
    Print str_colon

    mov byte [clr_fg], 0
.fg_loop:
    cmp byte [clr_fg], 16
    jge .fg_done

    movzx ax, byte [clr_bg]
    mov cl, 4
    shl ax, cl
    movzx bx, byte [clr_fg]
    add ax, bx
    mov [clr_attr], al

    movzx ax, byte [clr_fg]
    mov bl, 3
    mul bl
    add al, 9
    mov [clr_col], al

    mov dh, [clr_row]
    mov dl, [clr_col]
    call vid_set_cursor
    mov al, [clr_attr]
    call vid_set_attr
    PrintChar 219
    PrintChar 219

    inc byte [clr_fg]
    jmp .fg_loop
.fg_done:
    inc byte [clr_bg]
    inc byte [clr_row]
    jmp .bg_loop
.bg_done:

    SetColor 0x07
    mov dh, 12
    mov dl, 0
    call vid_set_cursor
    PrintLn str_note
    Print str_exit
    GetKey
ENDFN
