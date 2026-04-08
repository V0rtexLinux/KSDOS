; =============================================================================
; opengl.asm - KSDOS Software OpenGL 16-bit  [FIXED v2]
; VGA Mode 13h (320x200 x 256 colours)
; Implements: gl16_init, gl16_exit, gl16_clear, gfx_pix, gfx_line,
;             gl16_tri, gl16_cube_demo, gl16_triangle_demo
;
; FIX: gl16_tri rewritten with _tri_cur_y variable (no [esp+2] tricks)
; FIX: imul/idiv sequence corrected (imul sets DX:AX, no cwd needed)
; FIX: cube projection uses full rotation matrix
; =============================================================================

%ifndef VGA_GFX_SEG
VGA_GFX_SEG     equ 0xA000
%endif
%ifndef MODE13_W
MODE13_W        equ 320
MODE13_H        equ 200
%endif

; ---------------------------------------------------------------------------
; Palette helpers — guarded to avoid duplicates when linked with video.asm
; ---------------------------------------------------------------------------
%ifndef GFX_PALETTE_DEFINED
%define GFX_PALETTE_DEFINED

gfx_set_palette_entry:
    push ax
    push bx
    push cx
    push dx
    mov ah, 0x10
    mov al, 0x10
    xor bh, 0
    int 0x10
    pop dx
    pop cx
    pop bx
    pop ax
    ret

gfx_setup_palette:
    push ax
    push bx
    push cx
    push dx
    push si
    push es
    ; Load first 16 standard CGA colours via BIOS
    mov ax, ds
    mov es, ax
    mov si, cga_palette
    mov ax, 0x1012
    xor bx, bx
    mov cx, 16
    mov dx, si
    int 0x10
    ; Fill rest of palette (colours 16-255): simple RGB ramp
    mov al, 16
.pal_loop:
    cmp al, 0           ; wrapped? (255+1=0)
    je .pal_done
    push ax
    xor bx, bx
    mov bl, al
    mov dh, bl
    shr dh, 2
    and dh, 0x3F
    mov ch, bl
    shr ch, 1
    and ch, 0x3F
    mov cl, bl
    and cl, 0x3F
    mov ax, 0x1010
    int 0x10
    pop ax
    inc al
    jmp .pal_loop
.pal_done:
    pop es
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

cga_palette:
    db  0, 0, 0      ; 0  black
    db  0, 0,42      ; 1  blue
    db  0,42, 0      ; 2  green
    db  0,42,42      ; 3  cyan
    db 42, 0, 0      ; 4  red
    db 42, 0,42      ; 5  magenta
    db 42,21, 0      ; 6  brown
    db 42,42,42      ; 7  light grey
    db 21,21,21      ; 8  dark grey
    db 21,21,63      ; 9  light blue
    db 21,63,21      ; 10 light green
    db 21,63,63      ; 11 light cyan
    db 63,21,21      ; 12 light red
    db 63,21,63      ; 13 light magenta
    db 63,63,21      ; 14 yellow
    db 63,63,63      ; 15 white

; gfx_pix: plot one pixel  AL=colour, BX=x (0..319), DX=y (0..199)
gfx_pix:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    cmp bx, MODE13_W
    jae .gp_skip
    cmp dx, MODE13_H
    jae .gp_skip
    mov cx, ax
    mov ax, VGA_GFX_SEG
    mov es, ax
    mov ax, dx
    mov di, ax
    shl di, 8               ; di = y*256
    shl ax, 6               ; ax = y*64
    add di, ax              ; di = y*320
    add di, bx              ; di = y*320 + x
    mov al, cl
    stosb
.gp_skip:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; gfx_line: Bresenham line  AL=col, BX=x0, CX=y0, DX=x1, SI=y1
gfx_line:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    mov [gl_line_col], al
    mov [gl_x0], bx
    mov [gl_y0], cx
    mov [gl_x1], dx
    mov [gl_y1], si
    mov ax, dx
    sub ax, bx
    mov [gl_dx], ax
    jge .gdx_pos
    neg ax
.gdx_pos:
    mov [gl_dx_abs], ax
    mov ax, si
    sub ax, cx
    mov [gl_dy], ax
    jge .gdy_pos
    neg ax
.gdy_pos:
    mov [gl_dy_abs], ax
    mov ax, [gl_x0]
    cmp ax, [gl_x1]
    jl .gsx_pos
    mov word [gl_sx], -1
    jmp .gsy
.gsx_pos:
    mov word [gl_sx], 1
.gsy:
    mov ax, [gl_y0]
    cmp ax, [gl_y1]
    jl .gsy_pos
    mov word [gl_sy], -1
    jmp .gerr_init
.gsy_pos:
    mov word [gl_sy], 1
.gerr_init:
    mov ax, [gl_dx_abs]
    sub ax, [gl_dy_abs]
    mov [gl_err], ax
.gbres_loop:
    mov bx, [gl_x0]
    mov dx, [gl_y0]
    mov al, [gl_line_col]
    call gfx_pix
    mov ax, [gl_x0]
    cmp ax, [gl_x1]
    jne .gnot_done
    mov ax, [gl_y0]
    cmp ax, [gl_y1]
    jne .gnot_done
    jmp .gline_done
.gnot_done:
    mov ax, [gl_err]
    shl ax, 1
    mov [gl_e2], ax
    mov bx, [gl_dy_abs]
    neg bx
    cmp ax, bx
    jle .gno_x
    mov bx, [gl_dy_abs]
    sub [gl_err], bx
    mov bx, [gl_sx]
    add [gl_x0], bx
.gno_x:
    mov ax, [gl_e2]
    mov bx, [gl_dx_abs]
    cmp ax, bx
    jge .gno_y
    add [gl_err], bx
    mov bx, [gl_sy]
    add [gl_y0], bx
.gno_y:
    jmp .gbres_loop
.gline_done:
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; gfx_line_mem: draw line using gl_* memory variables
gfx_line_mem:
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, [gl_x0]
    mov cx, [gl_y0]
    mov dx, [gl_x1]
    mov si, [gl_y1]
    mov al, [gl_line_col]
    call gfx_line
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Data for gfx_line
gl_line_col:    db 0
gl_x0:          dw 0
gl_y0:          dw 0
gl_x1:          dw 0
gl_y1:          dw 0
gl_dx:          dw 0
gl_dy:          dw 0
gl_dx_abs:      dw 0
gl_dy_abs:      dw 0
gl_sx:          dw 1
gl_sy:          dw 1
gl_err:         dw 0
gl_e2:          dw 0

%endif

; ---- gl state ----
gl_mode:        db 0        ; 0=text, 1=graphics

; ============================================================
; gl16_init: switch to Mode 13h and set up palette
; ============================================================
gl16_init:
    push ax
    mov ax, 0x0013
    int 0x10
    mov byte [gl_mode], 1
    call gfx_setup_palette
    pop ax
    ret

; ============================================================
; gl16_exit: return to 80x25 text mode
; ============================================================
gl16_exit:
    push ax
    mov ax, 0x0003
    int 0x10
    mov byte [gl_mode], 0
    pop ax
    ret

; ============================================================
; gl16_clear: fill screen with colour AL
; ============================================================
gl16_clear:
    push ax
    push cx
    push di
    push es
    mov cx, ax              ; save colour
    mov ax, VGA_GFX_SEG
    mov es, ax
    xor di, di
    mov al, cl
    mov ah, cl
    mov cx, MODE13_W * MODE13_H / 2
    rep stosw
    pop es
    pop di
    pop cx
    pop ax
    ret

; ============================================================
; gl16_pix: plot pixel  BX=x, DX=y, AL=colour
; ============================================================
gl16_pix:
    cmp bx, MODE13_W
    jae .skip
    cmp dx, MODE13_H
    jae .skip
    push ax
    push bx
    push dx
    push di
    push es
    mov cx, ax
    mov ax, VGA_GFX_SEG
    mov es, ax
    mov ax, dx
    mov di, ax
    shl di, 8
    shl ax, 6
    add di, ax
    add di, bx
    mov al, cl
    stosb
    pop es
    pop di
    pop dx
    pop bx
    pop ax
.skip:
    ret

; ============================================================
; gl16_hline: draw horizontal line
; BX=x_start, CX=x_end, DX=y, AL=colour
; ============================================================
gl16_hline:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    ; Clip y
    cmp dx, MODE13_H
    jae .hl_done
    ; Clip x
    cmp bx, cx
    jle .hl_order
    xchg bx, cx
.hl_order:
    cmp bx, MODE13_W
    jae .hl_done
    cmp cx, 0
    jl .hl_done
    ; Clamp left
    cmp bx, 0
    jge .hl_cl_ok
    xor bx, bx
.hl_cl_ok:
    ; Clamp right
    cmp cx, MODE13_W - 1
    jle .hl_cr_ok
    mov cx, MODE13_W - 1
.hl_cr_ok:
    ; Compute start offset
    mov [_hl_col], al
    mov ax, VGA_GFX_SEG
    mov es, ax
    mov ax, dx
    mov di, ax
    shl di, 8
    shl ax, 6
    add di, ax
    add di, bx              ; di = y*320 + x_start
    ; Count = cx - bx + 1
    sub cx, bx
    inc cx
    mov al, [_hl_col]
    rep stosb
.hl_done:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
_hl_col: db 0

; ============================================================
; gl16_tri: filled triangle (scanline fill) — FIXED
; Arguments set before call:
;   tri_x0,tri_y0, tri_x1,tri_y1, tri_x2,tri_y2 (words)
;   tri_col (byte) = fill colour
;
; Algorithm:
;   Sort vertices by Y so y0<=y1<=y2.
;   Long edge: P0->P2.
;   Top half (y0..y1): long edge vs P0->P1
;   Bottom half (y1..y2): long edge vs P1->P2
;   Use _tri_cur_y variable - no stack tricks.
; ============================================================
tri_x0:     dw 0
tri_y0:     dw 0
tri_x1:     dw 0
tri_y1:     dw 0
tri_x2:     dw 0
tri_y2:     dw 0
tri_col:    db 0

; Working vars (no stack abuse)
_tri_cur_y: dw 0
_tri_xl:    dw 0
_tri_xr:    dw 0
_tri_dy:    dw 0

gl16_tri:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; ---- Sort vertices by Y: y0 <= y1 <= y2 ----
    mov ax, [tri_y0]
    cmp ax, [tri_y1]
    jle .s01
    mov bx, [tri_x0] ; swap 0,1
    mov cx, [tri_y0]
    mov dx, [tri_x1]
    mov si, [tri_y1]
    mov [tri_x0], dx
    mov [tri_y0], si
    mov [tri_x1], bx
    mov [tri_y1], cx
.s01:
    mov ax, [tri_y1]
    cmp ax, [tri_y2]
    jle .s12
    mov bx, [tri_x1] ; swap 1,2
    mov cx, [tri_y1]
    mov dx, [tri_x2]
    mov si, [tri_y2]
    mov [tri_x1], dx
    mov [tri_y1], si
    mov [tri_x2], bx
    mov [tri_y2], cx
.s12:
    mov ax, [tri_y0]
    cmp ax, [tri_y1]
    jle .s01b
    mov bx, [tri_x0]
    mov cx, [tri_y0]
    mov dx, [tri_x1]
    mov si, [tri_y1]
    mov [tri_x0], dx
    mov [tri_y0], si
    mov [tri_x1], bx
    mov [tri_y1], cx
.s01b:

    ; ---- Top half: y from y0 to y1 ----
    ; Long  edge: P0->P2  x = x0 + (x2-x0)*(y-y0)/(y2-y0)
    ; Short edge: P0->P1  x = x0 + (x1-x0)*(y-y0)/(y1-y0)
    mov ax, [tri_y0]
    mov [_tri_cur_y], ax

.top_loop:
    mov ax, [_tri_cur_y]
    cmp ax, [tri_y1]
    jg .skip_top

    ; t = y - y0  (stored in DI)
    mov di, ax
    sub di, [tri_y0]

    ; --- Long edge (P0->P2) ---
    mov ax, [tri_x2]
    sub ax, [tri_x0]        ; ax = x2-x0
    imul di                 ; dx:ax = (x2-x0)*(y-y0)
    mov cx, [tri_y2]
    sub cx, [tri_y0]        ; cx = y2-y0
    test cx, cx
    jz .le_zero
    idiv cx                 ; ax = result
    jmp .le_done
.le_zero:
    xor ax, ax
.le_done:
    add ax, [tri_x0]
    mov [_tri_xl], ax

    ; --- Short top edge (P0->P1) ---
    mov ax, [tri_x1]
    sub ax, [tri_x0]        ; ax = x1-x0
    imul di                 ; dx:ax = (x1-x0)*(y-y0)
    mov cx, [tri_y1]
    sub cx, [tri_y0]        ; cx = y1-y0
    test cx, cx
    jz .se_zero
    idiv cx
    jmp .se_done
.se_zero:
    xor ax, ax
.se_done:
    add ax, [tri_x0]
    mov [_tri_xr], ax

    ; --- Draw horizontal span ---
    mov dx, [_tri_cur_y]
    mov bx, [_tri_xl]
    mov cx, [_tri_xr]
    cmp bx, cx
    jle .top_draw
    xchg bx, cx
.top_draw:
    mov al, [tri_col]
    call gl16_hline

    inc word [_tri_cur_y]
    jmp .top_loop
.skip_top:

    ; ---- Bottom half: y from y1 to y2 ----
    ; Long  edge: P0->P2  (same formula)
    ; Short edge: P1->P2  x = x1 + (x2-x1)*(y-y1)/(y2-y1)
    mov ax, [tri_y1]
    mov [_tri_cur_y], ax

.bot_loop:
    mov ax, [_tri_cur_y]
    cmp ax, [tri_y2]
    jg .skip_bot

    ; t_long = y - y0
    mov di, ax
    sub di, [tri_y0]

    ; --- Long edge (P0->P2) ---
    mov ax, [tri_x2]
    sub ax, [tri_x0]
    imul di
    mov cx, [tri_y2]
    sub cx, [tri_y0]
    test cx, cx
    jz .ble_zero
    idiv cx
    jmp .ble_done
.ble_zero:
    xor ax, ax
.ble_done:
    add ax, [tri_x0]
    mov [_tri_xl], ax

    ; t_short = y - y1
    mov ax, [_tri_cur_y]
    mov di, ax
    sub di, [tri_y1]

    ; --- Short bottom edge (P1->P2) ---
    mov ax, [tri_x2]
    sub ax, [tri_x1]
    imul di
    mov cx, [tri_y2]
    sub cx, [tri_y1]
    test cx, cx
    jz .bse_zero
    idiv cx
    jmp .bse_done
.bse_zero:
    xor ax, ax
.bse_done:
    add ax, [tri_x1]
    mov [_tri_xr], ax

    ; --- Draw horizontal span ---
    mov dx, [_tri_cur_y]
    mov bx, [_tri_xl]
    mov cx, [_tri_xr]
    cmp bx, cx
    jle .bot_draw
    xchg bx, cx
.bot_draw:
    mov al, [tri_col]
    call gl16_hline

    inc word [_tri_cur_y]
    jmp .bot_loop
.skip_bot:

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; 5x7 pixel font (bitmap chars 32-90)
; Each char = 5 bytes, bit 0 = top row
; ============================================================
gl_font:
    db 0x00,0x00,0x00,0x00,0x00 ; 32 ' '
    db 0x00,0x00,0x5F,0x00,0x00 ; 33 '!'
    db 0x00,0x07,0x00,0x07,0x00 ; 34 '"'
    db 0x14,0x7F,0x14,0x7F,0x14 ; 35 '#'
    db 0x24,0x2A,0x7F,0x2A,0x12 ; 36 '$'
    db 0x23,0x13,0x08,0x64,0x62 ; 37 '%'
    db 0x36,0x49,0x55,0x22,0x50 ; 38 '&'
    db 0x00,0x05,0x03,0x00,0x00 ; 39 '''
    db 0x00,0x1C,0x22,0x41,0x00 ; 40 '('
    db 0x00,0x41,0x22,0x1C,0x00 ; 41 ')'
    db 0x14,0x08,0x3E,0x08,0x14 ; 42 '*'
    db 0x08,0x08,0x3E,0x08,0x08 ; 43 '+'
    db 0x00,0x50,0x30,0x00,0x00 ; 44 ','
    db 0x08,0x08,0x08,0x08,0x08 ; 45 '-'
    db 0x00,0x60,0x60,0x00,0x00 ; 46 '.'
    db 0x20,0x10,0x08,0x04,0x02 ; 47 '/'
    db 0x3E,0x51,0x49,0x45,0x3E ; 48 '0'
    db 0x00,0x42,0x7F,0x40,0x00 ; 49 '1'
    db 0x42,0x61,0x51,0x49,0x46 ; 50 '2'
    db 0x21,0x41,0x45,0x4B,0x31 ; 51 '3'
    db 0x18,0x14,0x12,0x7F,0x10 ; 52 '4'
    db 0x27,0x45,0x45,0x45,0x39 ; 53 '5'
    db 0x3C,0x4A,0x49,0x49,0x30 ; 54 '6'
    db 0x01,0x71,0x09,0x05,0x03 ; 55 '7'
    db 0x36,0x49,0x49,0x49,0x36 ; 56 '8'
    db 0x06,0x49,0x49,0x29,0x1E ; 57 '9'
    db 0x00,0x36,0x36,0x00,0x00 ; 58 ':'
    db 0x00,0x56,0x36,0x00,0x00 ; 59 ';'
    db 0x08,0x14,0x22,0x41,0x00 ; 60 '<'
    db 0x14,0x14,0x14,0x14,0x14 ; 61 '='
    db 0x00,0x41,0x22,0x14,0x08 ; 62 '>'
    db 0x02,0x01,0x51,0x09,0x06 ; 63 '?'
    db 0x32,0x49,0x79,0x41,0x3E ; 64 '@'
    db 0x7E,0x11,0x11,0x11,0x7E ; 65 'A'
    db 0x7F,0x49,0x49,0x49,0x36 ; 66 'B'
    db 0x3E,0x41,0x41,0x41,0x22 ; 67 'C'
    db 0x7F,0x41,0x41,0x22,0x1C ; 68 'D'
    db 0x7F,0x49,0x49,0x49,0x41 ; 69 'E'
    db 0x7F,0x09,0x09,0x09,0x01 ; 70 'F'
    db 0x3E,0x41,0x49,0x49,0x7A ; 71 'G'
    db 0x7F,0x08,0x08,0x08,0x7F ; 72 'H'
    db 0x00,0x41,0x7F,0x41,0x00 ; 73 'I'
    db 0x20,0x40,0x41,0x3F,0x01 ; 74 'J'
    db 0x7F,0x08,0x14,0x22,0x41 ; 75 'K'
    db 0x7F,0x40,0x40,0x40,0x40 ; 76 'L'
    db 0x7F,0x02,0x0C,0x02,0x7F ; 77 'M'
    db 0x7F,0x04,0x08,0x10,0x7F ; 78 'N'
    db 0x3E,0x41,0x41,0x41,0x3E ; 79 'O'
    db 0x7F,0x09,0x09,0x09,0x06 ; 80 'P'
    db 0x3E,0x41,0x51,0x21,0x5E ; 81 'Q'
    db 0x7F,0x09,0x19,0x29,0x46 ; 82 'R'
    db 0x46,0x49,0x49,0x49,0x31 ; 83 'S'
    db 0x01,0x01,0x7F,0x01,0x01 ; 84 'T'
    db 0x3F,0x40,0x40,0x40,0x3F ; 85 'U'
    db 0x1F,0x20,0x40,0x20,0x1F ; 86 'V'
    db 0x3F,0x40,0x38,0x40,0x3F ; 87 'W'
    db 0x63,0x14,0x08,0x14,0x63 ; 88 'X'
    db 0x07,0x08,0x70,0x08,0x07 ; 89 'Y'
    db 0x61,0x51,0x49,0x45,0x43 ; 90 'Z'
    db 0x00,0x7F,0x41,0x41,0x00 ; 91 '['
    db 0x02,0x04,0x08,0x10,0x20 ; 92 '\'
    db 0x00,0x41,0x41,0x7F,0x00 ; 93 ']'
    db 0x04,0x02,0x01,0x02,0x04 ; 94 '^'
    db 0x40,0x40,0x40,0x40,0x40 ; 95 '_'

; ============================================================
; gl16_text_gfx: draw string in graphics mode
; BX=x, DX=y, AL=colour, DS:SI=null-terminated string
; ============================================================
gl16_text_gfx:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov [_gt_x], bx
    mov [_gt_y], dx
    mov [_gt_col], al
.char_loop:
    lodsb
    test al, al
    jz .done
    cmp al, 32
    jb .next_char
    cmp al, 127
    jae .next_char
    sub al, 32
    cmp al, 95
    ja .next_char
    ; pointer into font: gl_font + al*5
    xor ah, ah
    mov di, ax
    shl di, 2
    add di, ax              ; di = al*5
    add di, gl_font
    mov cx, 5
    mov bx, [_gt_x]
.col_loop:
    test cx, cx
    jz .next_char
    push cx
    mov al, [di]
    inc di
    push bx
    mov cx, 7
    mov dx, [_gt_y]
.row_loop:
    test al, 1
    jz .no_dot
    push ax
    push cx
    push dx
    mov al, [_gt_col]
    call gl16_pix
    pop dx
    pop cx
    pop ax
.no_dot:
    shr al, 1
    inc dx
    loop .row_loop
    pop bx
    inc bx
    pop cx
    dec cx
    jmp .col_loop
.next_char:
    add word [_gt_x], 6
    jmp .char_loop
.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_gt_x:   dw 0
_gt_y:   dw 0
_gt_col: db 15

; ============================================================
; Sine table: sin_tab[i] = sin(i degrees) * 256, i=0..90
; ============================================================
sin_tab:
    dw    0,   4,   9,  13,  18,  22,  27,  31,  36,  40
    dw   44,  49,  53,  57,  62,  66,  70,  74,  79,  83
    dw   87,  91,  95,  99, 103, 107, 111, 115, 118, 122
    dw  126, 130, 133, 137, 141, 144, 148, 151, 154, 158
    dw  161, 164, 167, 171, 174, 177, 180, 182, 185, 188
    dw  191, 193, 196, 198, 201, 203, 205, 208, 210, 212
    dw  214, 216, 218, 220, 221, 223, 225, 226, 228, 229
    dw  231, 232, 233, 234, 235, 236, 237, 238, 239, 240
    dw  241, 241, 242, 242, 243, 243, 244, 244, 244, 245
    dw  245

; fsin16: AX=angle(deg, 0..359) -> AX=sin*256 (signed)
fsin16:
    push bx
    push cx
    ; Normalize
    cmp ax, 0
    jge .noneg
    add ax, 360
.noneg:
    mov bx, 360
    xor dx, dx
    div bx              ; AX = deg mod 360 (dx=remainder, but we use remainder)
    mov ax, dx
    ; Quadrant
    cmp ax, 90
    jle .q1
    cmp ax, 180
    jle .q2
    cmp ax, 270
    jle .q3
    ; Q4
    mov cx, 360
    sub cx, ax
    shl cx, 1
    mov bx, cx
    mov ax, [sin_tab + bx]
    neg ax
    jmp .fsin_done
.q1:
    shl ax, 1
    mov bx, ax
    mov ax, [sin_tab + bx]
    jmp .fsin_done
.q2:
    mov cx, 180
    sub cx, ax
    shl cx, 1
    mov bx, cx
    mov ax, [sin_tab + bx]
    jmp .fsin_done
.q3:
    sub ax, 180
    shl ax, 1
    mov bx, ax
    mov ax, [sin_tab + bx]
    neg ax
.fsin_done:
    pop cx
    pop bx
    ret

; fcos16: cos via sin(angle+90)
fcos16:
    push bx
    add ax, 90
    cmp ax, 360
    jb .ok
    sub ax, 360
.ok:
    call fsin16
    pop bx
    ret

; ============================================================
; gl16_cube_demo: animated rotating wireframe cube — FIXED
; Full Y-axis rotation matrix, correct projection
; ============================================================
cube_vx: dw -64,  64,  64, -64, -64,  64,  64, -64
cube_vy: dw -64, -64,  64,  64, -64, -64,  64,  64
cube_vz: dw -64, -64, -64, -64,  64,  64,  64,  64

cube_edges:
    db 0,1, 1,2, 2,3, 3,0
    db 4,5, 5,6, 6,7, 7,4
    db 0,4, 1,5, 2,6, 3,7

proj_x: times 8 dw 0
proj_y: times 8 dw 0

_cube_angle:    dw 0
_tmp_cos:       dw 256
_tmp_sin:       dw 0
_e_x0:          dw 0
_e_y0:          dw 0
_e_x1:          dw 0
_e_y1:          dw 0
_proj_z:        dw 0

gl16_cube_demo:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    call gl16_init
    mov word [_cube_angle], 0

.frame:
    call kbd_check
    jnz .exit_cube

    mov al, 1
    call gl16_clear

    mov bx, 40
    mov dx, 5
    mov al, 15
    mov si, str_gl_title
    call gl16_text_gfx

    ; Precompute cos/sin for this frame
    mov ax, [_cube_angle]
    call fcos16
    mov [_tmp_cos], ax
    mov ax, [_cube_angle]
    call fsin16
    mov [_tmp_sin], ax

    ; Project all 8 vertices
    mov cx, 8
    xor di, di
.proj_loop:
    push cx
    push di

    shl di, 1
    mov si, [cube_vx + di]  ; x
    mov ax, [cube_vy + di]  ; y (stored for later)
    push ax
    mov bx, [cube_vz + di]  ; z

    ; Rotate around Y: x' = x*cos + z*sin, z' = -x*sin + z*cos
    ; x' = (x*cos + z*sin) >> 8
    mov ax, si
    imul word [_tmp_cos]    ; dx:ax = x*cos
    mov [_proj_z], ax       ; save low word
    mov ax, bx
    imul word [_tmp_sin]    ; dx:ax = z*sin
    add ax, [_proj_z]
    sar ax, 8               ; ax = x' (screen x component)
    mov si, ax              ; si = x'

    ; z' = (-x*sin + z*cos) >> 8 + depth_offset
    mov ax, [cube_vx + di]
    neg ax
    imul word [_tmp_sin]    ; dx:ax = -x*sin
    mov [_proj_z], ax
    mov ax, bx
    imul word [_tmp_cos]    ; dx:ax = z*cos
    add ax, [_proj_z]
    sar ax, 8               ; ax = z'
    add ax, 200             ; perspective depth (z' + 200)
    cmp ax, 20
    jge .z_ok
    mov ax, 20
.z_ok:
    mov [_proj_z], ax       ; save z' for perspective divide

    pop ax                  ; restore y

    ; Perspective project:
    ; screen_x = 160 + x' * 128 / z'
    push ax
    mov ax, si
    imul word [_cub_fov]    ; dx:ax = x'*fov
    idiv word [_proj_z]
    add ax, 160
    pop cx                  ; cx = vertex index * 2 (di still shifted)
    push di
    mov di, cx
    mov [proj_x + di], ax

    ; screen_y = 100 + y * 128 / z'
    pop di
    push di
    mov ax, [cube_vy + di]  ; raw y
    neg ax
    imul word [_cub_fov]
    idiv word [_proj_z]
    add ax, 100
    mov bx, di
    mov [proj_y + bx], ax
    pop di

    pop di
    pop cx
    inc di
    dec cx
    jnz .proj_loop

    ; Draw 12 edges
    mov cx, 12
    mov si, cube_edges
.edge_loop:
    push cx
    push si
    movzx bx, byte [si]
    movzx dx, byte [si+1]
    shl bx, 1
    shl dx, 1
    push di
    mov di, bx
    mov ax, [proj_x + di]
    mov [gl_x0], ax
    mov ax, [proj_y + di]
    mov [gl_y0], ax
    mov di, dx
    mov ax, [proj_x + di]
    mov [gl_x1], ax
    mov ax, [proj_y + di]
    mov [gl_y1], ax
    pop di
    mov byte [gl_line_col], 14  ; yellow
    call gfx_line_mem
    pop si
    add si, 2
    pop cx
    loop .edge_loop

    ; Draw edge labels at corners
    mov bx, 80
    mov dx, 185
    mov al, 11
    mov si, str_gl_hint
    call gl16_text_gfx

    inc word [_cube_angle]
    cmp word [_cube_angle], 360
    jb .frame
    mov word [_cube_angle], 0
    jmp .frame

.exit_cube:
    call kbd_getkey
    call gl16_exit
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_cub_fov:   dw 128

str_gl_title: db "KSDOS OpenGL 16-bit - Rotating Cube [key=exit]", 0
str_gl_hint:  db "Press any key to exit", 0

; ============================================================
; gl16_triangle_demo: coloured filled triangle demo — FIXED
; ============================================================
gl16_triangle_demo:
    push ax
    push bx
    push cx
    push dx
    push si

    call gl16_init
    mov word [_tdemo_frame], 0

.tframe:
    call kbd_check
    jnz .texit

    mov al, 0
    call gl16_clear

    mov bx, 40
    mov dx, 5
    mov al, 14
    mov si, str_tri_title
    call gl16_text_gfx

    ; Draw 8 spinning coloured triangles
    mov cx, 8
    mov byte [_tdemo_c], 0
.tri_loop:
    push cx

    movzx ax, byte [_tdemo_c]
    mov bx, 45
    mul bx                  ; ax = c * 45 (base angle offset)
    add ax, [_tdemo_frame]
    mov [_tang], ax

    ; Vertex 0: center of screen
    mov word [tri_x0], 160
    mov word [tri_y0], 100

    ; Vertex 1: angle = _tang, r=80
    mov ax, [_tang]
    call fcos16
    imul word [_tdemo_r]    ; dx:ax = cos*r
    sar ax, 8
    add ax, 160
    mov [tri_x1], ax

    mov ax, [_tang]
    call fsin16
    imul word [_tdemo_r]
    sar ax, 8
    neg ax
    add ax, 100
    mov [tri_y1], ax

    ; Vertex 2: angle = _tang + 120
    mov ax, [_tang]
    add ax, 120
    cmp ax, 360
    jb .v2ok
    sub ax, 360
.v2ok:
    push ax
    call fcos16
    imul word [_tdemo_r]
    sar ax, 8
    add ax, 160
    mov [tri_x2], ax
    pop ax

    push ax
    call fsin16
    imul word [_tdemo_r]
    sar ax, 8
    neg ax
    add ax, 100
    mov [tri_y2], ax
    pop ax

    ; Colour cycling
    movzx ax, byte [_tdemo_c]
    add ax, 16
    add ax, [_tdemo_frame]
    and ax, 0xFF
    cmp al, 0
    jne .tc_ok
    mov al, 1
.tc_ok:
    mov [tri_col], al

    call gl16_tri

    inc byte [_tdemo_c]
    pop cx
    dec cx
    jnz .tri_loop

    add word [_tdemo_frame], 2
    cmp word [_tdemo_frame], 360
    jb .tframe
    mov word [_tdemo_frame], 0
    jmp .tframe

.texit:
    call kbd_getkey
    call gl16_exit
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_tdemo_frame:   dw 0
_tdemo_r:       dw 80
_tdemo_c:       db 0
_tang:          dw 0

str_tri_title: db "KSDOS OpenGL - Filled Triangle Demo [key=exit]", 0
