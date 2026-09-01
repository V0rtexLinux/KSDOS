; =============================================================================
; CLOCK.OVL  -  Digital clock (System32-style utility)  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Reads the CMOS RTC via INT 1Ah and displays date/time, live. ESC exits.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

STR str_title, "CLOCK - press ESC to exit"
STR str_date,  "Date: "
STR str_time,  "Time: "
STR str_slash, "/"
STR str_colon, ":"
STR str_20,    "20"

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

.loop:
    mov dh, 3
    mov dl, 0
    call vid_set_cursor

    Print str_date
    mov ah, 0x04
    int 0x1A                    ; CH=century DH=day CL=year DH=month...
    ; per spec: CH=century(BCD) CL=year(BCD) DH=month(BCD) DL=day(BCD)
    Print str_20
    mov al, cl
    call clk_print_bcd
    Print str_slash
    mov al, dh
    call clk_print_bcd
    Print str_slash
    mov al, dl
    call clk_print_bcd
    NewLine

    Print str_time
    mov ah, 0x02
    int 0x1A                    ; CH=hour CL=min DH=sec (BCD)
    mov al, ch
    call clk_print_bcd
    Print str_colon
    mov al, cl
    call clk_print_bcd
    Print str_colon
    mov al, dh
    call clk_print_bcd
    NewLine

    mov ah, 0x01
    int 0x16
    jz .loop
    mov ah, 0x00
    int 0x16
    cmp al, 27
    jne .loop
ENDFN

; clk_print_bcd: AL = packed BCD byte -> print as 2 decimal digits
clk_print_bcd:
    push ax
    mov ah, al
    shr ah, 4
    and ah, 0x0F
    add ah, '0'
    push ax
    mov al, ah
    call vid_putchar
    pop ax
    and al, 0x0F
    add al, '0'
    call vid_putchar
    pop ax
    ret
