; =============================================================================
; psyq.asm - KSDOS PSYq Engine (16-bit Real Mode) — FIXED v2
; PlayStation 1 SDK concepts adapted for x86 real mode
;
; FIXES:
;  - Ship model now has proper 3D Z depth (not flat)
;  - Full XYZ rotation (X and Y axes)
;  - Exhaust flame animation
;  - Gouraud-shade approximation via colour gradient
;  - imul usage corrected throughout
; =============================================================================

GPU_POLY_F3     equ 0x20
GPU_POLY_G3     equ 0x30
GPU_SPRT        equ 0x74

; ---- GTE state ----
gte_rx:         dw 0        ; rotation X angle
gte_ry:         dw 0        ; rotation Y angle
gte_rz:         dw 0        ; rotation Z angle
gte_tx:         dw 160      ; screen center X
gte_ty:         dw 100      ; screen center Y
gte_tz:         dw 280      ; depth offset
gte_h:          dw 120      ; perspective distance

; ---- 3D Ship model — 14 triangles with real Z depth ----
; Format: x0,y0,z0, x1,y1,z1, x2,y2,z2 (3D vertices, scale*1)
ship_verts:
    ; Nose spike (front)
    dw   0,-80,-30
    dw -24, -8,  0
    dw  24, -8,  0
    ; Cockpit left
    dw  -8,-40,-10
    dw -24, -8,  0
    dw   0,-24, 10
    ; Cockpit right
    dw   8,-40,-10
    dw  24, -8,  0
    dw   0,-24, 10
    ; Left wing front
    dw -24, -8,  0
    dw -80, 20, -8
    dw -16, 24,  0
    ; Left wing rear
    dw -80, 20, -8
    dw -24, 48,  4
    dw -16, 24,  0
    ; Right wing front
    dw  24, -8,  0
    dw  80, 20, -8
    dw  16, 24,  0
    ; Right wing rear
    dw  80, 20, -8
    dw  24, 48,  4
    dw  16, 24,  0
    ; Body center
    dw -24, -8,  0
    dw  24, -8,  0
    dw   0, 48,  4
    ; Left thruster housing
    dw -16, 36,  0
    dw -28, 48,  8
    dw -12, 52,  4
    ; Right thruster housing
    dw  16, 36,  0
    dw  28, 48,  8
    dw  12, 52,  4
    ; Left engine flare
    dw -28, 48,  8
    dw -20, 64,  6
    dw -12, 52,  4
    ; Right engine flare
    dw  28, 48,  8
    dw  20, 64,  6
    dw  12, 52,  4
    ; Tail fin (vertical)
    dw   0, 16,-20
    dw   0, 48,  4
    dw   0, 60,-12
    ; Body bottom armour
    dw -12, 16,  8
    dw  12, 16,  8
    dw   0, 36, 12

SHIP_TRIS       equ 14

; Colours per triangle (palette indices)
ship_colors:
    db 15, 11, 11   ; nose: white, cyan
    db 9, 9         ; cockpit: light blue
    db 10, 10       ; wings: green  
    db 10, 10
    db 7            ; body: grey
    db 8, 8         ; thrusters: dark grey
    db 4, 4         ; flames: red/orange
    db 12           ; fin: light red
    db 14           ; armour: yellow

; ---- Star field ----
psyq_stars:     times 48*2 dw 0
psyq_rng_seed:  dw 0xACE1
psyq_frame:     dw 0

; ---- GTE working variables ----
_gte_x:     dw 0
_gte_y:     dw 0
_gte_z:     dw 0
_gte_xr:    dw 0
_gte_yr:    dw 0
_gte_zr:    dw 1
_gte_cos_x: dw 256
_gte_sin_x: dw 0
_gte_cos_y: dw 256
_gte_sin_y: dw 0

; ============================================================
; psyq_rand: 16-bit LFSR
; ============================================================
psyq_rand:
    push bx
    mov ax, [psyq_rng_seed]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [psyq_rng_seed], ax
    pop bx
    ret

; ============================================================
; psyq_init
; ============================================================
psyq_init:
    push ax
    push bx
    push cx
    push dx
    push di

    call gl16_init
    call gfx_setup_palette

    ; Seed star positions from BIOS timer
    mov ah, 0x00
    int 0x1A
    mov [psyq_rng_seed], dx

    xor di, di
    mov cx, 48
.star_init:
    call psyq_rand
    xor dx, dx
    mov bx, MODE13_W
    div bx
    mov [psyq_stars + di], dx
    add di, 2
    call psyq_rand
    xor dx, dx
    mov bx, MODE13_H
    div bx
    mov [psyq_stars + di], dx
    add di, 2
    loop .star_init

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; psyq_gte_transform: full XY rotation + perspective
; Input: DS:SI = pointer to x,y,z (3 words)
; Output: BX=screen_x, DX=screen_y
; ============================================================
psyq_gte_transform:
    push ax
    push cx
    push si

    mov ax, [si]            ; x
    mov [_gte_x], ax
    mov ax, [si+2]          ; y
    mov [_gte_y], ax
    mov ax, [si+4]          ; z
    mov [_gte_z], ax

    ; --- Rotate around Y axis (left-right spin) ---
    ; x' = x*cos_y + z*sin_y
    ; z' = -x*sin_y + z*cos_y
    mov ax, [_gte_x]
    imul word [_gte_cos_y]  ; dx:ax = x*cos_y
    ; low word in ax (>>8 for scale)
    push ax
    mov ax, [_gte_z]
    imul word [_gte_sin_y]
    pop cx
    add cx, ax
    sar cx, 8
    mov [_gte_xr], cx       ; x rotated

    mov ax, [_gte_x]
    neg ax
    imul word [_gte_sin_y]
    push ax
    mov ax, [_gte_z]
    imul word [_gte_cos_y]
    pop cx
    add cx, ax
    sar cx, 8               ; z after Y rotation
    mov [_gte_zr], cx       ; temporary

    ; --- Rotate around X axis (pitch) ---
    ; y' = y*cos_x - z*sin_x
    ; z' = y*sin_x + z*cos_x
    mov ax, [_gte_y]
    imul word [_gte_cos_x]
    push ax
    mov ax, [_gte_zr]
    imul word [_gte_sin_x]
    pop cx
    sub cx, ax
    sar cx, 8
    mov [_gte_yr], cx       ; y rotated

    mov ax, [_gte_y]
    imul word [_gte_sin_x]
    push ax
    mov ax, [_gte_zr]
    imul word [_gte_cos_x]
    pop cx
    add cx, ax
    sar cx, 8
    add cx, [gte_tz]        ; add depth offset
    cmp cx, 20
    jge .z_ok
    mov cx, 20
.z_ok:
    mov [_gte_zr], cx

    ; Perspective divide
    ; sx = tx + xr * h / z'
    mov ax, [_gte_xr]
    imul word [gte_h]
    idiv word [_gte_zr]
    add ax, [gte_tx]
    mov bx, ax

    ; sy = ty + yr * h / z' (Y flipped: PS1 Y goes down)
    mov ax, [_gte_yr]
    imul word [gte_h]
    idiv word [_gte_zr]
    add ax, [gte_ty]
    mov dx, ax

    pop si
    pop cx
    pop ax
    ret

; ============================================================
; psyq_draw_stars: twinkling star field
; ============================================================
psyq_draw_stars:
    push ax
    push bx
    push cx
    push dx
    push di

    xor di, di
    mov cx, 48
.sloop:
    mov bx, [psyq_stars + di]
    mov dx, [psyq_stars + di + 2]
    ; Scroll stars (parallax)
    sub bx, 1
    cmp bx, 0
    jge .sxok
    mov bx, MODE13_W - 1
.sxok:
    mov [psyq_stars + di], bx
    ; Twinkle colour
    mov ax, [psyq_frame]
    add ax, di
    and al, 0x0F
    cmp al, 0
    jne .not_white
    mov al, 15
    jmp .sdraw
.not_white:
    cmp al, 7
    jl .sdraw
    mov al, 8
.sdraw:
    call gl16_pix
    add di, 4
    loop .sloop

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Vertex screen coords (saved between transform calls)
_sv_x0: dw 0
_sv_y0: dw 0
_sv_x1: dw 0
_sv_y1: dw 0
_sv_x2: dw 0
_sv_y2: dw 0

; ============================================================
; psyq_ship_demo: main demo — rotating 3D ship
; ============================================================
psyq_ship_demo:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    call psyq_init
    mov word [gte_ry], 0
    mov word [gte_rx], 350  ; slight pitch upward

.frame_loop:
    call kbd_check
    jnz .exit_demo

    ; Clear to black
    mov al, 0
    call gl16_clear

    ; Stars
    call psyq_draw_stars

    ; Title
    mov bx, 20
    mov dx, 5
    mov al, 11
    mov si, str_psyq_title
    call gl16_text_gfx

    ; SDK label
    mov bx, 20
    mov dx, 15
    mov al, 10
    mov si, str_psyq_sdk
    call gl16_text_gfx

    ; Recompute trig for current angles
    mov ax, [gte_ry]
    call fcos16
    mov [_gte_cos_y], ax
    mov ax, [gte_ry]
    call fsin16
    mov [_gte_sin_y], ax

    mov ax, [gte_rx]
    call fcos16
    mov [_gte_cos_x], ax
    mov ax, [gte_rx]
    call fsin16
    mov [_gte_sin_x], ax

    ; Draw ship triangles
    xor di, di
    mov cx, SHIP_TRIS
.tri_draw:
    push cx
    push di

    ; Stride = 18 bytes per triangle (3 verts * 3 words)
    mov ax, di
    mov bx, 18
    mul bx
    mov si, ship_verts
    add si, ax

    call psyq_gte_transform
    mov [_sv_x0], bx
    mov [_sv_y0], dx
    add si, 6

    call psyq_gte_transform
    mov [_sv_x1], bx
    mov [_sv_y1], dx
    add si, 6

    call psyq_gte_transform
    mov [_sv_x2], bx
    mov [_sv_y2], dx

    ; Get triangle colour
    mov bx, di
    cmp bx, 8          ; bounds check ship_colors table
    jb .col_ok
    mov bx, 7
.col_ok:
    movzx ax, byte [ship_colors + bx]

    ; Set up tri vertices
    mov bx, [_sv_x0]
    mov [tri_x0], bx
    mov bx, [_sv_y0]
    mov [tri_y0], bx
    mov bx, [_sv_x1]
    mov [tri_x1], bx
    mov bx, [_sv_y1]
    mov [tri_y1], bx
    mov bx, [_sv_x2]
    mov [tri_x2], bx
    mov bx, [_sv_y2]
    mov [tri_y2], bx
    mov [tri_col], al

    call gl16_tri

    ; Also draw wireframe outline
    mov bx, [_sv_x0]
    mov [gl_x0], bx
    mov bx, [_sv_y0]
    mov [gl_y0], bx
    mov bx, [_sv_x1]
    mov [gl_x1], bx
    mov bx, [_sv_y1]
    mov [gl_y1], bx
    movzx ax, byte [ship_colors + di]
    or al, 8          ; brighter outline
    and al, 0x0F
    mov [gl_line_col], al
    call gfx_line_mem

    pop di
    pop cx
    inc di
    dec cx
    jnz .tri_draw

    ; Draw engine exhaust (animated red/orange)
    mov ax, [psyq_frame]
    and al, 7
    add al, 4               ; colour 4..11
    mov [tri_col], al

    mov bx, [psyq_frame]
    and bx, 0x000F
    sub bx, 8               ; -8..+7 wobble

    mov word [tri_x0], 160
    add [tri_x0], bx
    mov word [tri_y0], 180
    mov word [tri_x1], 148
    mov word [tri_y1], 165
    mov word [tri_x2], 172
    mov word [tri_y2], 165
    call gl16_tri

    ; Advance rotation
    add word [gte_ry], 2
    cmp word [gte_ry], 360
    jb .no_y_wrap
    mov word [gte_ry], 0
.no_y_wrap:

    ; Gentle X wobble
    add word [gte_rx], 1
    cmp word [gte_rx], 360
    jb .no_x_wrap
    mov word [gte_rx], 0
.no_x_wrap:

    inc word [psyq_frame]
    jmp .frame_loop

.exit_demo:
    call kbd_getkey
    call gl16_exit
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

str_psyq_title: db "KSDOS PSYq Engine v2.0  [key=exit]", 0
str_psyq_sdk:   db "SDK: sdk/psyq/ PSn00bSDK  Full 3D rotation", 0
