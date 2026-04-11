; =============================================================================
; RING0HW.OVL  -  KSDOS Ring 0 Hardware Access Layer  v2.0
;
; Dual-mode: uses BIOS (INT 10h/16h) for safe/compatible operations AND
; direct hardware port I/O (Ring 0 privilege) for low-level control.
;
; Direct port I/O (Ring 0):
;   3C2h  Miscellaneous Output      3C4/3C5h  Sequencer
;   3D4/3D5h  CRTC                  3CE/3CFh  Graphics Controller
;   3C0h  Attribute Controller      3C8/3C9h  DAC palette
;   60/64h  8042 keyboard           40-43h  8253/8254 PIT
;   20/21h  8259 PIC
;
; BIOS (fallback / companion):
;   INT 10h AH=00h  set video mode
;   INT 10h AH=0Ch  write pixel
;   INT 10h AH=10h  DAC palette
;   INT 16h AH=01h  keyboard status
;   INT 16h AH=00h  keyboard read
;   INT 1Ah AH=00h  timer tick count
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; VGA I/O port constants (Ring 0 direct)
; ---------------------------------------------------------------------------
VGA_MISC_W      equ 0x3C2
VGA_SEQ_IDX     equ 0x3C4
VGA_SEQ_DAT     equ 0x3C5
VGA_CRTC_IDX    equ 0x3D4
VGA_CRTC_DAT    equ 0x3D5
VGA_GFX_IDX     equ 0x3CE
VGA_GFX_DAT     equ 0x3CF
VGA_ATTR_IDX    equ 0x3C0
VGA_ISTAT1      equ 0x3DA
VGA_DAC_WR      equ 0x3C8
VGA_DAC_DATA    equ 0x3C9
KBD_DATA        equ 0x60
KBD_STATUS      equ 0x64
PIT_CH0         equ 0x40
PIT_CMD         equ 0x43
PIC_CMD         equ 0x20
PIC_DATA        equ 0x21
VGA_BUF         equ 0xA000
MODE13_W        equ 320
MODE13_H        equ 200

; ---------------------------------------------------------------------------
; Strings
; ---------------------------------------------------------------------------
STR str_title,   "=== KSDOS Ring0 Hardware Layer v2.0 ==="
STR str_sep,     "----------------------------------------"
STR str_bios_hdr,"[BIOS MODE]  INT 10h / INT 16h / INT 1Ah"
STR str_hw_hdr,  "[RING0 HW]   Direct I/O port access"
STR str_vga_b,   "BIOS: INT 10h AH=00h AL=13h  (mode 13h)"
STR str_kbd_b,   "BIOS: INT 16h AH=01h/00h     (keyboard)"
STR str_pit_b,   "BIOS: INT 1Ah AH=00h          (timer)"
STR str_vga_r,   "HW:   OUT 3C2h,63h + 3C4-3DAh (VGA regs)"
STR str_kbd_r,   "HW:   IN  60h                  (8042 kbd)"
STR str_pit_r,   "HW:   OUT 43h,36h + 40h,00h   (8253 PIT)"
STR str_pic_r,   "HW:   OUT 21h,FCh              (8259 PIC)"
STR str_pal_b,   "BIOS: INT 10h AH=10h AL=12h   (palette)"
STR str_pal_r,   "HW:   OUT 3C8h idx + 3C9h R,G,B"
STR str_demo,    "Colour demo: BIOS pixel (left) vs HW mem (right)"
STR str_scanln,  "Scancode (BIOS INT16): "
STR str_scanraw, "Raw port 60h:          "
STR str_done,    "ESC to exit"

; ---------------------------------------------------------------------------
; FN U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    PUSH_ALL

    ; ---- 1. Program PIT via direct port (Ring 0) ----
    mov al, 0x36
    out PIT_CMD, al
    xor al, al
    out PIT_CH0, al
    out PIT_CH0, al

    ; ---- 2. Mask IRQs via PIC direct (Ring 0) ----
    mov al, 0xFC
    out PIC_DATA, al

    ; ---- 3a. Enter Mode 13h via BIOS (INT 10h) ----
    mov ax, 0x0013
    int 0x10

    ; ---- 3b. Re-program palette via BIOS INT 10h ----
    call bios_setup_palette

    ; ---- 4. Re-program VGA DAC via direct port (Ring 0) — overlay BIOS palette ----
    ;         (demonstrates both methods coexist)
    call hw_fix_palette

    ; ---- 5. Clear screen dark blue via direct framebuffer write (Ring 0) ----
    mov ax, VGA_BUF
    mov es, ax
    xor di, di
    mov al, 0x01
    mov ah, al
    mov cx, MODE13_W * MODE13_H / 2
    rep stosw

    ; ---- 6. Draw info using our pixel font (direct VGA write) ----
    mov bx, 4  
    mov dx, 4
    mov al, 15
    mov si, str_title
    call hw_text

    mov bx, 4
    mov dx, 16
    mov al, 7
    mov si, str_sep
    call hw_text

    mov bx, 4
    mov dx, 26
    mov al, 11
    mov si, str_bios_hdr
    call hw_text

    mov bx, 4
    mov dx, 36
    mov al, 10
    mov si, str_vga_b
    call hw_text

    mov bx, 4
    mov dx, 44
    mov al, 10
    mov si, str_kbd_b
    call hw_text

    mov bx, 4
    mov dx, 52
    mov al, 10
    mov si, str_pit_b
    call hw_text

    mov bx, 4
    mov dx, 60
    mov al, 10
    mov si, str_pal_b
    call hw_text

    mov bx, 4
    mov dx, 72
    mov al, 7
    mov si, str_sep
    call hw_text

    mov bx, 4
    mov dx, 82
    mov al, 14
    mov si, str_hw_hdr
    call hw_text

    mov bx, 4
    mov dx, 92
    mov al, 12
    mov si, str_vga_r
    call hw_text

    mov bx, 4
    mov dx, 100
    mov al, 12
    mov si, str_kbd_r
    call hw_text

    mov bx, 4
    mov dx, 108
    mov al, 12
    mov si, str_pit_r
    call hw_text

    mov bx, 4
    mov dx, 116
    mov al, 12
    mov si, str_pic_r
    call hw_text

    mov bx, 4
    mov dx, 124
    mov al, 12
    mov si, str_pal_r
    call hw_text

    ; ---- 7. Colour gradient: BIOS pixel left half, direct write right half ----
    mov bx, 4
    mov dx, 136
    mov al, 7
    mov si, str_demo
    call hw_text

    ; Left half (x=0..159): use BIOS INT 10h AH=0Ch to write pixels
    xor si, si          ; colour counter
    mov cx, 150         ; y start
.bios_ramp:
    cmp cx, 158
    jg .bios_done
    mov bx, 0
.bios_row:
    cmp bx, 160
    jge .bios_next_row
    push bx
    push cx
    mov al, byte [si]   ; not really - use simple formula
    ; colour = (bx + cx) & 0xFF, avoid 0
    mov ax, bx
    add ax, cx
    sub ax, 150
    and al, 0x1F
    or al, 0x01
    mov ah, 0x0C        ; BIOS write pixel
    xor bh, bh
    int 0x10
    pop cx
    pop bx
    inc bx
    jmp .bios_row
.bios_next_row:
    inc cx
    jmp .bios_ramp
.bios_done:

    ; Right half (x=160..319): direct VGA memory write (Ring 0)
    mov ax, VGA_BUF
    mov es, ax
    mov cx, 150
.hw_ramp:
    cmp cx, 158
    jg .hw_done
    mov bx, 160
.hw_row:
    cmp bx, 320
    jge .hw_next_row
    ; colour = (bx + cx) & 0xFF, avoid 0, different offset
    mov ax, bx
    add ax, cx
    sub ax, 170
    and al, 0x3F
    or al, 0x01
    push cx
    push bx
    mov dx, cx
    mov di, dx
    shl di, 8
    shl dx, 6
    add di, dx
    add di, bx
    stosb
    pop bx
    pop cx
    inc bx
    jmp .hw_row
.hw_next_row:
    inc cx
    jmp .hw_ramp
.hw_done:

    ; ---- 8. Live keyboard: show both BIOS and raw port reads ----
    mov bx, 4
    mov dx, 168
    mov al, 15
    mov si, str_scanln
    call hw_text

    mov bx, 4
    mov dx, 178
    mov al, 15
    mov si, str_scanraw
    call hw_text

    mov bx, 4
    mov dx, 190
    mov al, 7
    mov si, str_done
    call hw_text

.key_loop:
    ; --- BIOS keyboard check (INT 16h AH=01h) ---
    mov ah, 0x01
    int 0x16
    jz .no_bios_key
    mov ah, 0x00
    int 0x16             ; AH=scancode, AL=ASCII
    cmp al, 27           ; ESC
    je .exit
    ; Show BIOS scancode as hex at (142,168)
    mov bl, ah
    mov bx, 142
    mov dx, 168
    mov al, bl
    call hw_show_hex_byte

.no_bios_key:
    ; --- Raw port 60h keyboard read (Ring 0) ---
    in al, KBD_STATUS
    test al, 0x01
    jz .key_loop
    in al, KBD_DATA      ; raw scancode from 8042
    push ax
    ; Acknowledge to PIC (Ring 0 direct)
    mov al, 0x20
    out PIC_CMD, al
    pop ax
    and al, 0x7F         ; strip release bit
    ; Show raw scancode at (142,178)
    push ax
    mov bx, 142
    mov dx, 178
    call hw_show_hex_byte
    pop ax
    cmp al, 0x01         ; ESC scancode
    jne .key_loop

.exit:
    ; Return to text mode via BIOS (safest)
    mov ax, 0x0003
    int 0x10
    POP_ALL
ENDFN

; ---------------------------------------------------------------------------
; bios_setup_palette: set 256-colour palette via BIOS INT 10h AH=10h AL=12h
; ---------------------------------------------------------------------------
bios_setup_palette:
    push ax
    push bx
    push cx
    push dx
    push si
    push es
    mov ax, ds
    mov es, ax
    mov si, hw_cga_pal
    mov ax, 0x1012          ; set block of DAC registers
    xor bx, bx              ; start at register 0
    mov cx, 16              ; 16 colours
    mov dx, si              ; ES:DX = table pointer
    int 0x10
    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; hw_fix_palette: program colours 16-255 via direct DAC ports (Ring 0)
; Complements the BIOS palette by filling the upper 240 entries directly
; ---------------------------------------------------------------------------
hw_fix_palette:
    push ax
    push cx
    mov al, 16
    out 0x3C8, al          ; Ring 0: índice DAC
    mov cx, 240

.pal_loop:
    push ax

    ; Componente Vermelho
    mov al, ah
    shr al, 1
    and al, 0x3F
    mov dx, 0x3C9
    out dx, al

    ; Componente Verde
    mov al, ah
    shr al, 4
    and al, 0x3F
    mov dx, 0x3C9
    out dx, al

    ; Componente Azul
    mov al, ah
    and al, 0x3F
    mov dx, 0x3C9
    out dx, al

    pop ax
    inc ax
    loop .pal_loop

    pop cx
    pop ax
    ret

; ---------------------------------------------------------------------------
; hw_show_hex_byte: draw AL as two hex digits at BX=x, DX=y
; ---------------------------------------------------------------------------
hw_show_hex_byte:
    push ax
    push bx
    push cx
    push dx
    push si
    mov ch, al
    ; High nibble
    shr al, 4
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .h1
    add al, 7
.h1:
    call hw_draw_char
    add bx, 7
    ; Low nibble
    mov al, ch
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .h2
    add al, 7
.h2:
    call hw_draw_char
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; hw_draw_char: draw single char AL at BX=x, DX=y, colour=15 (direct write)
; ---------------------------------------------------------------------------
hw_draw_char:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    push si
    cmp al, 32
    jb .done2
    cmp al, 127
    jae .done2
    sub al, 32
    xor ah, ah
    mov si, ax
    shl si, 2
    add si, ax
    add si, hw_font
    mov ax, VGA_BUF
    mov es, ax
    mov cx, 5
.col:
    test cx, cx
    jz .done2
    push cx
    mov al, [si]
    inc si
    mov cx, 7
    push bx
    push dx
.row:
    test al, 1
    jz .rskip
    cmp bx, MODE13_W
    jae .rskip
    cmp dx, MODE13_H
    jae .rskip
    push ax
    push dx
    push bx
    mov ax, dx
    mov di, ax
    shl di, 8
    shl ax, 6
    add di, ax
    add di, bx
    mov byte [es:di], 15
    pop bx
    pop dx
    pop ax
.rskip:
    shr al, 1
    inc dx
    loop .row
    pop dx
    pop bx
    inc bx
    pop cx
    dec cx
    jmp .col
.done2:
    pop si
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; hw_text: draw null-terminated string  SI=str, BX=x, DX=y, AL=colour
; ---------------------------------------------------------------------------
hw_text:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov [_hwt_col], al
    mov [_hwt_x], bx
    mov [_hwt_y], dx
    mov ax, VGA_BUF
    mov es, ax
.tl:
    lodsb
    test al, al
    jz .td
    cmp al, 32
    jb .tskip
    cmp al, 127
    jae .tskip
    sub al, 32
    xor ah, ah
    mov di, ax
    shl di, 2
    add di, ax
    add di, hw_font
    mov cx, 5
    mov bx, [_hwt_x]
    mov dx, [_hwt_y]
.tc:
    test cx, cx
    jz .tnext
    push cx
    mov al, [di]
    inc di
    push bx
    push dx
    mov cx, 7
.tr:
    test al, 1
    jz .trs
    cmp bx, MODE13_W
    jae .trs
    cmp dx, MODE13_H
    jae .trs
    push ax
    push dx
    push bx
    mov ax, dx
    push di
    mov di, ax
    shl di, 8
    shl ax, 6
    add di, ax
    add di, bx
    mov ah, [_hwt_col]
    mov byte [es:di], ah
    pop di
    pop bx
    pop dx
    pop ax
.trs:
    shr al, 1
    inc dx
    loop .tr
    pop dx
    pop bx
    inc bx
    pop cx
    dec cx
    jmp .tc
.tnext:
    add word [_hwt_x], 6
    jmp .tl
.tskip:
    add word [_hwt_x], 6
    jmp .tl
.td:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_hwt_col:
    db 15
_hwt_x:   dw 0
_hwt_y:   dw 0

; ---------------------------------------------------------------------------
; CGA palette (16 entries x 3 bytes R,G,B — 6-bit each for DAC)
; ---------------------------------------------------------------------------
hw_cga_pal:

    db  0, 0, 0
    db  0, 0,42
    db  0,42, 0
    db  0,42,42

    db 42, 0, 0
    db 42, 0,42
    db 42,21, 0
    db 42,42,42

    db 21,21,21
    db 21,21,63
    db 21,63,21
    db 21,63,63

    db 63,21,21
    db 63,21,63
    db 63,63,21
    db 63,63,63

; ---------------------------------------------------------------------------
; 5x7 pixel font (ASCII 32-127)
; ---------------------------------------------------------------------------
hw_font:

    db 0x00,0x00,0x00,0x00,0x00
    db 0x00,0x00,0x5F,0x00,0x00

    db 0x00,0x07,0x00,0x07,0x00
    db 0x14,0x7F,0x14,0x7F,0x14

    db 0x24,0x2A,0x7F,0x2A,0x12
    db 0x23,0x13,0x08,0x64,0x62

    db 0x36,0x49,0x55,0x22,0x50
    db 0x00,0x05,0x03,0x00,0x00

    db 0x00,0x1C,0x22,0x41,0x00
    db 0x00,0x41,0x22,0x1C,0x00

    db 0x14,0x08,0x3E,0x08,0x14
    db 0x08,0x08,0x3E,0x08,0x08

    db 0x00,0x50,0x30,0x00,0x00
    db 0x08,0x08,0x08,0x08,0x08

    db 0x00,0x60,0x60,0x00,0x00
    db 0x20,0x10,0x08,0x04,0x02

    db 0x3E,0x51,0x49,0x45,0x3E
    db 0x00,0x42,0x7F,0x40,0x00

    db 0x42,0x61,0x51,0x49,0x46
    db 0x21,0x41,0x45,0x4B,0x31

    db 0x18,0x14,0x12,0x7F,0x10
    db 0x27,0x45,0x45,0x45,0x39

    db 0x3C,0x4A,0x49,0x49,0x30
    db 0x01,0x71,0x09,0x05,0x03

    db 0x36,0x49,0x49,0x49,0x36
    db 0x06,0x49,0x49,0x29,0x1E

    db 0x00,0x36,0x36,0x00,0x00
    db 0x00,0x56,0x36,0x00,0x00

    db 0x08,0x14,0x22,0x41,0x00
    db 0x14,0x14,0x14,0x14,0x14

    db 0x00,0x41,0x22,0x14,0x08
    db 0x02,0x01,0x51,0x09,0x06

    db 0x32,0x49,0x79,0x41,0x3E
    db 0x7E,0x11,0x11,0x11,0x7E

    db 0x7F,0x49,0x49,0x49,0x36
    db 0x3E,0x41,0x41,0x41,0x22

    db 0x7F,0x41,0x41,0x22,0x1C
    db 0x7F,0x49,0x49,0x49,0x41

    db 0x7F,0x09,0x09,0x09,0x01
    db 0x3E,0x41,0x49,0x49,0x7A

    db 0x7F,0x08,0x08,0x08,0x7F
    db 0x00,0x41,0x7F,0x41,0x00

    db 0x20,0x40,0x41,0x3F,0x01
    db 0x7F,0x08,0x14,0x22,0x41

    db 0x7F,0x40,0x40,0x40,0x40
    db 0x7F,0x02,0x0C,0x02,0x7F

    db 0x7F,0x04,0x08,0x10,0x7F
    db 0x3E,0x41,0x41,0x41,0x3E

    db 0x7F,0x09,0x09,0x09,0x06
    db 0x3E,0x41,0x51,0x21,0x5E

    db 0x7F,0x09,0x19,0x29,0x46
    db 0x46,0x49,0x49,0x49,0x31

    db 0x01,0x01,0x7F,0x01,0x01
    db 0x3F,0x40,0x40,0x40,0x3F

    db 0x1F,0x20,0x40,0x20,0x1F
    db 0x3F,0x40,0x38,0x40,0x3F

    db 0x63,0x14,0x08,0x14,0x63
    db 0x07,0x08,0x70,0x08,0x07

    db 0x61,0x51,0x49,0x45,0x43
    db 0x00,0x7F,0x41,0x41,0x00

    db 0x02,0x04,0x08,0x10,0x20
    db 0x00,0x41,0x41,0x7F,0x00

    db 0x04,0x02,0x01,0x02,0x04
    db 0x40,0x40,0x40,0x40,0x40
