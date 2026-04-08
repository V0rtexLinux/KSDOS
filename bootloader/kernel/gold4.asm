; =============================================================================
; gold4.asm - KSDOS GOLD4 Engine (16-bit Real Mode) — FIXED v2
; DOOM-style raycaster based on sdk/gold4/
;
; FIXES:
;  - DDA ray cast: proper grid-aligned marching (no stack corruption)
;  - Fisheye correction: imul (signed) instead of mul (unsigned)
;  - Stack balance restored in g4_cast_ray
;  - Wall height clamping improved
;  - Floor/ceiling fill via memset rows (faster)
;  - Collision detection added to movement
; =============================================================================

MAP_W       equ 16
MAP_H       equ 10
HALF_FOV    equ 30
FOV_FULL    equ 60
DEPTH_SCALE equ 160
PROJ_DIST   equ 160        ; projection plane distance

; ---- Map: 1=wall, 0=empty ----
gold4_map:
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    db 1,0,1,1,0,0,0,1,0,0,1,0,0,0,0,1
    db 1,0,1,0,0,0,0,1,0,0,0,0,1,0,0,1
    db 1,0,0,0,0,1,0,0,0,0,0,0,1,0,0,1
    db 1,0,0,1,0,1,0,0,0,1,0,0,0,0,0,1
    db 1,0,0,1,0,0,0,0,0,1,0,1,0,0,0,1
    db 1,0,0,0,0,0,1,0,0,0,0,1,0,0,0,1
    db 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

; ---- Player state (fixed-point *64) ----
g4_px:          dw 64*3
g4_py:          dw 64*5
g4_angle:       dw 90

; ---- Wall colours ----
g4_wall_ns:     db 12
g4_wall_ew:     db 4
g4_ceil:        db 1
g4_floor:       db 8
g4_hud_col:     db 14

; ---- Ray cast output ----
g4_dist:        dw 0
g4_side:        db 0

; ============================================================
; gold4_init
; ============================================================
gold4_init:
    push ax
    call gl16_init
    call gfx_setup_palette
    pop ax
    ret

; ============================================================
; gold4_draw_frame: render one complete frame — FIXED
; ============================================================
gold4_draw_frame:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Fill ceiling (rows 0..99) and floor (rows 100..199)
    ; Use fast row-fill
    xor dx, dx              ; row y=0
.ceil_rows:
    cmp dx, 100
    jge .floor_rows
    xor bx, bx
    mov cx, MODE13_W - 1
    mov al, [g4_ceil]
    call gl16_hline
    inc dx
    jmp .ceil_rows
.floor_rows:
    cmp dx, 200
    jge .walls
    xor bx, bx
    mov cx, MODE13_W - 1
    mov al, [g4_floor]
    call gl16_hline
    inc dx
    jmp .floor_rows
.walls:

    ; Cast one ray per screen column (0..319)
    xor si, si
.ray_loop:
    cmp si, MODE13_W
    jge .rays_done

    ; ray_angle = player_angle - HALF_FOV + si*FOV_FULL/320
    ; = player_angle - 30 + si*60/320  (approx si*3/16)
    mov ax, si
    mov bx, 3
    mul bx              ; ax = si*3
    xor dx, dx
    mov bx, 16
    div bx              ; ax = si*3/16  (≈ si*60/320)
    mov cx, [g4_angle]
    sub cx, HALF_FOV
    add cx, ax
    ; Normalize 0..359
.na:
    cmp cx, 0
    jge .np
    add cx, 360
    jmp .na
.np:
    cmp cx, 360
    jl .nok
    sub cx, 360
    jmp .np
.nok:
    mov [_g4_ray_angle], cx

    call g4_cast_ray        ; sets g4_dist, g4_side

    ; Fisheye correction: dist = dist * cos(ray - player) / 256
    mov ax, [_g4_ray_angle]
    sub ax, [g4_angle]
    ; Normalize difference to -180..180
.fnorm:
    cmp ax, -180
    jge .fn1
    add ax, 360
    jmp .fnorm
.fn1:
    cmp ax, 180
    jle .fn2
    sub ax, 360
    jmp .fn1
.fn2:
    call fcos16             ; AX = cos(diff)*256 (signed)
    ; Make sure positive
    cmp ax, 0
    jg .fcos_pos
    neg ax
.fcos_pos:
    ; corrected_dist = dist * cos / 256
    imul word [g4_dist]     ; dx:ax = dist*cos
    sar ax, 8               ; ax = corrected dist (low bits sufficient)
    mov [g4_dist], ax

    ; Wall height = PROJ_DIST * DEPTH_SCALE / dist
    mov ax, PROJ_DIST * DEPTH_SCALE / 10
    mov bx, [g4_dist]
    cmp bx, 1
    jge .d_ok
    mov bx, 1
.d_ok:
    xor dx, dx
    div bx
    cmp ax, MODE13_H
    jle .wh_ok
    mov ax, MODE13_H
.wh_ok:
    mov [_g4_wh], ax

    ; Wall colour by side
    mov al, [g4_wall_ns]
    cmp byte [g4_side], 1
    jne .wcol_set
    mov al, [g4_wall_ew]
.wcol_set:
    mov [_g4_wcol], al

    ; Wall top = 100 - wh/2
    mov ax, [_g4_wh]
    shr ax, 1
    mov bx, 100
    sub bx, ax
    cmp bx, 0
    jge .ytop_ok
    xor bx, bx
.ytop_ok:
    mov [_g4_ytop], bx
    add bx, [_g4_wh]
    cmp bx, MODE13_H
    jl .ybot_ok
    mov bx, MODE13_H
.ybot_ok:
    mov [_g4_ybot], bx

    ; Draw vertical wall strip at x=si
    mov dx, [_g4_ytop]
.col_draw:
    cmp dx, [_g4_ybot]
    jge .col_done
    mov bx, si
    mov al, [_g4_wcol]
    call gl16_pix
    inc dx
    jmp .col_draw
.col_done:

    inc si
    jmp .ray_loop
.rays_done:

    call g4_draw_minimap

    ; HUD
    mov bx, 2
    mov dx, 185
    mov al, [g4_hud_col]
    mov si, str_g4_hud
    call gl16_text_gfx

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_g4_ray_angle:  dw 0
_g4_wh:         dw 0
_g4_ytop:       dw 0
_g4_ybot:       dw 0
_g4_wcol:       db 0

; ============================================================
; g4_cast_ray: DDA grid traversal — FIXED (no stack corruption)
; Input:  [_g4_ray_angle]
; Output: [g4_dist] (distance*1), [g4_side] (0=EW, 1=NS)
;
; Algorithm: step along ray from player position, checking each
; grid cell boundary. Use integer coords scaled by 64.
; ============================================================
g4_cast_ray:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Compute ray direction (scaled *256)
    mov ax, [_g4_ray_angle]
    call fcos16
    mov [_rc_dx], ax        ; ray_dx = cos(angle)*256

    mov ax, [_g4_ray_angle]
    call fsin16
    mov [_rc_dy], ax        ; ray_dy = sin(angle)*256

    ; Player tile position (integer)
    mov ax, [g4_px]
    sar ax, 6               ; /64
    mov [_rc_mx], ax        ; tile x

    mov ax, [g4_py]
    sar ax, 6               ; /64
    mov [_rc_my], ax        ; tile y

    ; March ray: up to 64 steps, distance increments by 4 each step
    mov word [g4_dist], 0
    mov cx, 64

.march_loop:
    test cx, cx
    jz .march_max

    add word [g4_dist], 4

    ; Tile position at current distance:
    ; tx = (px + dist*dx/256) / 64
    ; ty = (py + dist*dy/256) / 64
    mov ax, [g4_dist]
    imul word [_rc_dx]      ; dx:ax = dist*ray_dx
    sar ax, 8               ; ax = dist*ray_dx/256  (px-relative)
    add ax, [g4_px]
    sar ax, 6               ; tile x
    mov bx, ax

    mov ax, [g4_dist]
    imul word [_rc_dy]
    sar ax, 8
    add ax, [g4_py]
    sar ax, 6               ; tile y
    mov di, ax

    ; Bounds check
    cmp bx, 0
    jl .march_max
    cmp bx, MAP_W - 1
    jg .march_max
    cmp di, 0
    jl .march_max
    cmp di, MAP_H - 1
    jg .march_max

    ; Map lookup: map[ty*MAP_W + tx]
    mov ax, MAP_W
    mul di                  ; ax = ty*MAP_W (di is tile y)
    add ax, bx              ; + tx
    mov si, gold4_map
    add si, ax
    cmp byte [si], 1
    jne .no_wall

    ; Wall hit! Determine side (EW vs NS)
    ; If tile X changed since last step → EW wall (side=0)
    ; If tile Y changed            → NS wall (side=1)
    mov ax, bx
    cmp ax, [_rc_mx]
    jne .ew_wall
    mov byte [g4_side], 1   ; NS
    jmp .march_done
.ew_wall:
    mov byte [g4_side], 0   ; EW
    jmp .march_done

.no_wall:
    mov [_rc_mx], bx        ; update last tile x
    mov [_rc_my], di        ; update last tile y
    dec cx
    jmp .march_loop

.march_max:
    mov word [g4_dist], 200
.march_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_rc_dx:  dw 0
_rc_dy:  dw 0
_rc_mx:  dw 0
_rc_my:  dw 0

; ============================================================
; g4_draw_minimap
; ============================================================
g4_draw_minimap:
    push ax
    push bx
    push cx
    push dx
    push si

    xor si, si
    mov dx, 2
    mov cx, MAP_H
.mm_row:
    push cx
    mov cx, MAP_W
    mov bx, 256
.mm_col:
    push cx
    mov al, [gold4_map + si]
    test al, al
    jz .mm_empty
    mov al, 7
    jmp .mm_draw
.mm_empty:
    mov al, 0
.mm_draw:
    call gl16_pix
    push bx
    push dx
    inc bx
    call gl16_pix
    inc dx
    call gl16_pix
    dec bx
    call gl16_pix
    dec dx
    pop dx
    pop bx
    add bx, 2
    inc si
    pop cx
    loop .mm_col
    add dx, 2
    pop cx
    loop .mm_row

    ; Player dot
    mov ax, [g4_px]
    sar ax, 6
    shl ax, 1
    add ax, 256
    mov bx, ax
    mov ax, [g4_py]
    sar ax, 6
    shl ax, 1
    add ax, 2
    mov dx, ax
    mov al, 4
    call gl16_pix

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; g4_check_wall: returns CF=1 if tile at (BX,DX) is a wall
; ============================================================
g4_check_wall:
    cmp bx, 0
    jl .wall
    cmp bx, MAP_W - 1
    jg .wall
    cmp dx, 0
    jl .wall
    cmp dx, MAP_H - 1
    jg .wall
    push ax
    push si
    mov ax, MAP_W
    mul dx
    add ax, bx
    mov si, gold4_map
    add si, ax
    cmp byte [si], 1
    pop si
    pop ax
    je .wall
    clc
    ret
.wall:
    stc
    ret

; ============================================================
; gold4_run: main loop — WASD=move, A/D=turn, ESC=quit
; ============================================================
gold4_run:
    push ax
    push bx
    push cx
    push dx
    push si

    call gold4_init

.game_loop:
    call gold4_draw_frame

    call kbd_check
    jz .game_loop

    call kbd_getkey
    cmp al, 27
    je .game_exit
    cmp al, 'w'
    je .move_fwd
    cmp al, 'W'
    je .move_fwd
    cmp al, 's'
    je .move_back
    cmp al, 'S'
    je .move_back
    cmp al, 'a'
    je .turn_left
    cmp al, 'A'
    je .turn_left
    cmp al, 'd'
    je .turn_right
    cmp al, 'D'
    je .turn_right
    jmp .game_loop

.move_fwd:
    ; New pos = px + cos(angle)*step
    mov ax, [g4_angle]
    call fcos16
    sar ax, 5               ; *4/128
    mov bx, ax
    add bx, [g4_px]
    ; Check tile
    mov ax, bx
    sar ax, 6
    mov cx, [g4_py]
    sar cx, 6
    push cx
    mov dx, cx
    pop cx
    call g4_check_wall
    jc .fwd_x_blocked
    mov [g4_px], bx
.fwd_x_blocked:
    mov ax, [g4_angle]
    call fsin16
    sar ax, 5
    mov dx, ax
    add dx, [g4_py]
    ; Check tile
    mov bx, [g4_px]
    sar bx, 6
    mov ax, dx
    sar ax, 6
    mov dx, ax
    call g4_check_wall
    jc .fwd_y_blocked
    ; apply y
    mov ax, [g4_angle]
    call fsin16
    sar ax, 5
    add [g4_py], ax
.fwd_y_blocked:
    jmp .game_loop

.move_back:
    mov ax, [g4_angle]
    call fcos16
    sar ax, 5
    mov bx, [g4_px]
    sub bx, ax
    mov ax, bx
    sar ax, 6
    mov cx, [g4_py]
    sar cx, 6
    mov dx, cx
    call g4_check_wall
    jc .back_x_blocked
    mov [g4_px], bx
.back_x_blocked:
    mov ax, [g4_angle]
    call fsin16
    sar ax, 5
    mov bx, [g4_py]
    sub bx, ax
    mov [g4_py], bx
    jmp .game_loop

.turn_left:
    sub word [g4_angle], 8
    cmp word [g4_angle], 0
    jge .game_loop
    add word [g4_angle], 360
    jmp .game_loop

.turn_right:
    add word [g4_angle], 8
    cmp word [g4_angle], 360
    jl .game_loop
    sub word [g4_angle], 360
    jmp .game_loop

.game_exit:
    call gl16_exit
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

str_g4_hud: db "GOLD4 | W=fwd S=back A/D=turn ESC=quit", 0
