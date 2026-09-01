; =============================================================================
; PAINT.OVL  -  Mode 13h drawing canvas (System32-style utility)  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Arrow keys move the brush, SPACE toggles pen up/down, 0-9 pick a colour,
; C clears the canvas, ESC exits.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

BRUSH   equ 3
STEP    equ 4

U16 px, 160
U16 py, 100
U16 pen_down, 0
U8  pcolor, 14

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    call gl16_init
    mov al, 0
    call gl16_clear

.loop:
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp al, ' '
    je .toggle_pen
    cmp al, 'c'
    je .clear
    cmp al, 'C'
    je .clear
    cmp al, '0'
    jb .arrows
    cmp al, '9'
    ja .arrows
    sub al, '0'
    movzx bx, al
    shl bx, 1
    mov ax, [paint_palette + bx]
    mov [pcolor], al
    jmp .loop

.arrows:
    test ah, ah
    jz .loop
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    jmp .loop
.up:
    mov ax, [py]
    sub ax, STEP
    cmp ax, 0
    jl .loop
    mov [py], ax
    jmp .maybe_draw
.down:
    mov ax, [py]
    add ax, STEP
    cmp ax, 200-BRUSH
    jg .loop
    mov [py], ax
    jmp .maybe_draw
.left:
    mov ax, [px]
    sub ax, STEP
    cmp ax, 0
    jl .loop
    mov [px], ax
    jmp .maybe_draw
.right:
    mov ax, [px]
    add ax, STEP
    cmp ax, 320-BRUSH
    jg .loop
    mov [px], ax
.maybe_draw:
    cmp word [pen_down], 0
    je .loop
    call paint_stamp
    jmp .loop

.toggle_pen:
    xor word [pen_down], 1
    jmp .loop
.clear:
    mov al, 0
    call gl16_clear
    jmp .loop

.quit:
    call gl16_exit
ENDFN

paint_palette:
    dw 0, 1, 2, 3, 4, 5, 6, 7, 14, 15

; paint_stamp: stamp a BRUSHxBRUSH square of [pcolor] at (px,py)
paint_stamp:
    push ax
    mov ax, [px]
    mov [rect_x0], ax
    mov ax, [px]
    add ax, BRUSH
    mov [rect_x1], ax
    mov ax, [py]
    mov [rect_y0], ax
    add ax, BRUSH
    mov [rect_y1], ax
    movzx ax, byte [pcolor]
    call gl16_rect
    pop ax
    ret

%include "../opengl.asm"
