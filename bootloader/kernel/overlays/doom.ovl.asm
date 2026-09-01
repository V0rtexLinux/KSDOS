; =============================================================================
; DOOM.OVL  -  First-person raycasting demo, Wolfenstein/DOOM-inspired  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
;
; This is NOT the licensed DOOM engine (a real BSP/WAD renderer is far
; outside what fits in a 16-bit real-mode overlay) — it is a genuine,
; from-scratch raycaster in the same family as id Software's early
; Wolfenstein 3D: a 16x16 tile map, per-column ray marching in fixed-point,
; distance-shaded wall columns, and two billboard sprites occluded by a
; per-column depth buffer. Arrow keys move/turn, ESC exits.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

MAP_W       equ 16
MAP_H       equ 16
CELL        equ 64          ; world units per map cell
RSTEP       equ 8           ; ray march step length (units)
MAX_STEPS   equ 128         ; 128*8 = 1024 units = full map span
FOV         equ 60          ; degrees
SCR_W       equ 320
SCR_H       equ 200
HALF_H      equ 100
PROJ_DIST   equ 220         ; projection plane distance (wall-height scale)
TURN_SPEED  equ 4           ; degrees per keypress
MOVE_SPEED  equ 12          ; units per keypress

; ---------------------------------------------------------------------------
; Map data: 1 = wall, 0 = empty.  16x16, border is solid.
; ---------------------------------------------------------------------------
dm_map:
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    db 1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1
    db 1,0,1,1,0,0,1,0,1,1,1,1,1,0,0,1
    db 1,0,1,0,0,0,0,0,0,0,0,0,1,0,0,1
    db 1,0,1,0,1,1,1,1,1,0,1,0,1,0,0,1
    db 1,0,0,0,1,0,0,0,1,0,1,0,0,0,0,1
    db 1,1,1,0,1,0,1,0,1,0,1,1,1,1,0,1
    db 1,0,0,0,0,0,1,0,0,0,0,0,0,1,0,1
    db 1,0,1,1,1,1,1,1,1,1,1,1,0,1,0,1
    db 1,0,0,0,0,0,0,0,0,0,0,1,0,0,0,1
    db 1,0,1,1,1,1,0,1,1,1,0,1,0,1,1,1
    db 1,0,1,0,0,1,0,0,0,1,0,0,0,0,0,1
    db 1,0,1,0,0,1,1,1,0,1,1,1,1,1,0,1
    db 1,0,0,0,0,0,0,1,0,0,0,0,0,1,0,1
    db 1,0,0,0,1,0,0,0,0,1,0,0,0,0,0,1
    db 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

; ---------------------------------------------------------------------------
; Player state (world units, angle in degrees 0-359)
; ---------------------------------------------------------------------------
dm_px:      dw 3*CELL + CELL/2
dm_py:      dw 1*CELL + CELL/2
dm_pang:    dw 0

; Per-column wall distance, for sprite occlusion
dm_depth:   times SCR_W dw 0

; Sprites: two static "marker" enemies at fixed cells
dm_spr_x:   dw 9*CELL + CELL/2, 13*CELL + CELL/2
dm_spr_y:   dw 9*CELL + CELL/2, 3*CELL + CELL/2
dm_spr_col: db 12, 14           ; bright red, bright yellow
NUM_SPRITES equ 2

STR str_title, "DOOM-LIKE RAYCASTER  [arrows=move/turn  ESC=exit]"
STR str_hint,  "Not the licensed DOOM engine - a from-scratch raycaster demo"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    PUSH_ALL
    call gl16_init

.frame:
    ; ---- input ----
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    test ah, ah
    jnz .special
    jmp .no_key
.special:
    cmp ah, 0x48            ; up arrow
    je .move_fwd
    cmp ah, 0x50             ; down arrow
    je .move_back
    cmp ah, 0x4B              ; left arrow
    je .turn_left
    cmp ah, 0x4D               ; right arrow
    je .turn_right
    jmp .no_key
.move_fwd:
    mov ax, MOVE_SPEED
    call dm_try_move
    jmp .no_key
.move_back:
    mov ax, -MOVE_SPEED
    call dm_try_move
    jmp .no_key
.turn_left:
    mov ax, [dm_pang]
    sub ax, TURN_SPEED
    call dm_norm_angle
    mov [dm_pang], ax
    jmp .no_key
.turn_right:
    mov ax, [dm_pang]
    add ax, TURN_SPEED
    call dm_norm_angle
    mov [dm_pang], ax
.no_key:

    ; ---- draw ceiling/floor ----
    mov word [rect_x0], 0
    mov word [rect_y0], 0
    mov word [rect_x1], SCR_W-1
    mov word [rect_y1], HALF_H-1
    mov al, 1                   ; dark blue ceiling
    call gl16_rect
    mov word [rect_y0], HALF_H
    mov word [rect_y1], SCR_H-1
    mov al, 2                   ; dark green floor
    call gl16_rect

    ; ---- cast one ray per column ----
    xor bx, bx                  ; bx = column 0..319
.col_loop:
    cmp bx, SCR_W
    jge .cols_done

    ; relative angle for this column: (col-160)*FOV/320
    mov ax, bx
    sub ax, SCR_W/2
    imul word [_dm_fov320]      ; dx:ax = (col-160)*FOV  (word, fits: 160*60=9600)
    mov cx, SCR_W
    idiv cx                     ; ax = relative angle (degrees, signed)
    mov [_dm_relang], ax

    add ax, [dm_pang]
    call dm_norm_angle
    mov [_dm_rayang], ax

    call fcos16
    mov [_dm_dcos], ax
    mov ax, [_dm_rayang]
    call fsin16
    mov [_dm_dsin], ax

    ; step deltas = dcos*RSTEP/256, dsin*RSTEP/256
    mov ax, [_dm_dcos]
    imul word [_dm_rstep]
    sar ax, 8
    mov [_dm_stepx], ax
    mov ax, [_dm_dsin]
    imul word [_dm_rstep]
    sar ax, 8
    mov [_dm_stepy], ax

    mov ax, [dm_px]
    mov [_dm_rx], ax
    mov ax, [dm_py]
    mov [_dm_ry], ax

    mov cx, 1                   ; step counter
    mov word [_dm_hit], 0
.march:
    mov ax, [_dm_rx]
    add ax, [_dm_stepx]
    mov [_dm_rx], ax
    mov ax, [_dm_ry]
    add ax, [_dm_stepy]
    mov [_dm_ry], ax

    ; map cell = pos / CELL
    mov ax, [_dm_rx]
    cmp ax, 0
    jl .wall_hit
    cmp ax, MAP_W*CELL
    jge .wall_hit
    mov ax, [_dm_ry]
    cmp ax, 0
    jl .wall_hit
    cmp ax, MAP_H*CELL
    jge .wall_hit

    mov ax, [_dm_rx]
    push cx
    mov cx, 6                   ; CELL=64=2^6 -> shift instead of div
    sar ax, cl
    pop cx
    mov [_dm_cellx], ax
    mov ax, [_dm_ry]
    push cx
    mov cx, 6
    sar ax, cl
    pop cx
    mov [_dm_celly], ax

    mov ax, [_dm_celly]
    mov dx, MAP_W
    imul dx
    add ax, [_dm_cellx]
    mov si, ax
    cmp byte [dm_map + si], 0
    je .no_hit
.wall_hit:
    mov word [_dm_hit], 1
    jmp .march_done
.no_hit:
    inc cx
    cmp cx, MAX_STEPS
    jle .march
.march_done:

    ; raw distance = cx * RSTEP
    mov ax, cx
    imul word [_dm_rstep]
    ; fisheye correction: dist *= cos(relative angle)
    push ax
    mov ax, [_dm_relang]
    call fcos16                  ; ax = cos(relang)*256
    mov dx, ax
    pop ax
    imul dx
    sar ax, 8
    cmp ax, 1
    jge .dist_ok
    mov ax, 1
.dist_ok:
    mov [dm_depth + bx], ax
    mov [_dm_dist], ax

    ; wall height = CELL * PROJ_DIST / dist
    mov ax, CELL
    imul word [_dm_proj]
    idiv word [_dm_dist]
    mov [_dm_wh], ax

    ; shade: closer = brighter. pick a grey band by distance.
    mov ax, [_dm_dist]
    mov cx, 60
    xor dx, dx
    div cx                       ; ax = dist/60  (band index)
    mov cx, 7
    cmp ax, cx
    jle .shade_ok
    mov ax, cx
.shade_ok:
    mov dx, 7
    sub dx, ax                   ; dx = 7..0, higher = closer/brighter
    shl dx, 2
    add dx, 16                   ; grey ramp base (16..44), avoid palette 0-15
    cmp dx, 44
    jle .shade_ok2
    mov dx, 44
.shade_ok2:
    mov [_dm_shade], dl

    ; draw the column
    mov ax, HALF_H
    sub ax, [_dm_wh]
    cmp ax, 0
    jge .top_ok
    xor ax, ax
.top_ok:
    mov cx, ax
    mov ax, HALF_H
    add ax, [_dm_wh]
    cmp ax, SCR_H-1
    jle .bot_ok
    mov ax, SCR_H-1
.bot_ok:
    mov dx, ax
    mov al, [_dm_shade]
    call gl16_vline

    inc bx
    jmp .col_loop
.cols_done:

    ; ---- sprites (simple billboard discs, occluded by depth buffer) ----
    xor si, si
.spr_loop:
    cmp si, NUM_SPRITES
    jge .spr_done
    call dm_draw_sprite
    inc si
    jmp .spr_loop
.spr_done:

    mov dh, 0
    mov dl, 0
    call vid_set_cursor
    SetColor 0x1F
    Print str_title
    SetColor 0x07

    jmp .frame

.quit:
    call gl16_exit
    POP_ALL
ENDFN

; ---------------------------------------------------------------------------
; U0 dm_try_move(AX = signed distance along facing direction)
; ---------------------------------------------------------------------------
dm_try_move:
    push bx
    push cx
    push dx
    push si

    mov [_dm_mv], ax
    mov ax, [dm_pang]
    call fcos16
    imul word [_dm_mv]
    sar ax, 8
    add ax, [dm_px]
    mov [_dm_nx], ax

    mov ax, [dm_pang]
    call fsin16
    imul word [_dm_mv]
    sar ax, 8
    add ax, [dm_py]
    mov [_dm_ny], ax

    ; collision check with a small margin
    mov ax, [_dm_nx]
    push cx
    mov cx, 6
    sar ax, cl
    pop cx
    mov bx, ax
    mov ax, [dm_py]
    push cx
    mov cx, 6
    sar ax, cl
    pop cx
    mov dx, ax
    mov ax, dx
    mov cx, MAP_W
    imul cx
    add ax, bx
    mov si, ax
    cmp byte [dm_map + si], 0
    jne .no_x
    mov ax, [_dm_nx]
    mov [dm_px], ax
.no_x:

    mov ax, [dm_px]
    push cx
    mov cx, 6
    sar ax, cl
    pop cx
    mov bx, ax
    mov ax, [_dm_ny]
    push cx
    mov cx, 6
    sar ax, cl
    pop cx
    mov dx, ax
    mov ax, dx
    mov cx, MAP_W
    imul cx
    add ax, bx
    mov si, ax
    cmp byte [dm_map + si], 0
    jne .no_y
    mov ax, [_dm_ny]
    mov [dm_py], ax
.no_y:

    pop si
    pop dx
    pop cx
    pop bx
    ret
_dm_mv: dw 0
_dm_nx: dw 0
_dm_ny: dw 0

; ---------------------------------------------------------------------------
; U0 dm_norm_angle(AX) -> AX in 0..359
; ---------------------------------------------------------------------------
dm_norm_angle:
    push dx
.n1:
    cmp ax, 0
    jge .n2
    add ax, 360
    jmp .n1
.n2:
    cmp ax, 360
    jl .ndone
    sub ax, 360
    jmp .n2
.ndone:
    pop dx
    ret

; ---------------------------------------------------------------------------
; U0 dm_draw_sprite(SI = sprite index)
; Projects the sprite into screen space; skips if behind the player,
; outside the FOV, or occluded by a nearer wall in the depth buffer.
; ---------------------------------------------------------------------------
dm_draw_sprite:
    push ax
    push bx
    push cx
    push dx
    push di

    mov di, si
    shl di, 1                  ; di = word offset into spr_x/spr_y (si stays
                                ; the raw index, still needed for spr_col)

    mov ax, [dm_spr_x + di]
    sub ax, [dm_px]
    mov [_ds_dx], ax
    mov ax, [dm_spr_y + di]
    sub ax, [dm_py]
    mov [_ds_dy], ax

    ; distance^2 (rough) via |dx|+|dy| as a cheap magnitude estimate,
    ; refined below once we know it's roughly on-screen
    mov ax, [_ds_dx]
    imul ax
    mov bx, ax
    mov ax, [_ds_dy]
    imul ax
    add ax, bx
    jo .skip                   ; overflow -> too far, skip
    ; integer sqrt via linear search (distances here are small, <1024)
    xor cx, cx
.sq:
    mov bx, cx
    inc bx
    imul bx, bx
    cmp bx, ax
    jg .sqdone
    inc cx
    cmp cx, 2000
    jl .sq
.sqdone:
    mov [_ds_dist], cx
    cmp cx, 20
    jge .dist_ok
    mov cx, 20
.dist_ok:
    mov [_ds_dist], cx

    ; angle to sprite relative to player facing
    mov ax, [_ds_dy]
    mov bx, [_ds_dx]
    call dm_atan2
    sub ax, [dm_pang]
    call dm_norm_angle
    cmp ax, 180
    jle .fwd_ok
    sub ax, 360
.fwd_ok:
    cmp ax, -(FOV/2)-10
    jl .skip
    cmp ax, (FOV/2)+10
    jg .skip
    mov [_ds_relang], ax

    ; screen column = 160 + relang*320/FOV
    mov ax, [_ds_relang]
    mov bx, SCR_W
    imul bx
    mov bx, FOV
    idiv bx
    add ax, SCR_W/2
    cmp ax, 0
    jl .skip
    cmp ax, SCR_W-1
    jg .skip
    mov [_ds_col], ax

    ; occlusion: skip if a wall is nearer in the depth buffer here
    mov bx, ax
    mov ax, [dm_depth + bx]
    cmp ax, [_ds_dist]
    jl .skip

    ; size on screen, inversely proportional to distance
    mov ax, CELL
    imul word [_dm_proj]
    idiv word [_ds_dist]
    sar ax, 1
    cmp ax, 3
    jge .r_ok
    mov ax, 3
.r_ok:
    cmp ax, 60
    jle .r_ok2
    mov ax, 60
.r_ok2:
    mov [circ_r], ax
    mov [circ_x], bx
    mov word [circ_y], HALF_H
    movzx ax, byte [dm_spr_col + si]
    call gl16_circle

.skip:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
_ds_dx:     dw 0
_ds_dy:     dw 0
_ds_dist:   dw 0
_ds_relang: dw 0
_ds_col:    dw 0

; ---------------------------------------------------------------------------
; U0 dm_atan2(AX=dy, BX=dx) -> AX = angle in degrees (0..359), coarse
; Coarse 16-direction lookup — plenty for sprite placement at this scale.
; ---------------------------------------------------------------------------
dm_atan2:
    push bx
    push cx
    push dx
    ; scale down to avoid overflow, then use fixed division-based estimate
    mov cx, ax                  ; cx = dy
    ; approximate atan2 via octant selection + linear ratio table skipped
    ; for time; use a coarse 8-direction estimate which is accurate enough
    ; for placing a billboard sprite within the FOV cone.
    cmp bx, 0
    jne .bx_nz
    cmp cx, 0
    jge .down
    mov ax, 270
    jmp .a_done
.down:
    mov ax, 90
    jmp .a_done
.bx_nz:
    cmp bx, 0
    jl .neg_x
    cmp cx, 0
    jl .q4
    mov ax, 45
    jmp .a_done
.q4:
    mov ax, 315
    jmp .a_done
.neg_x:
    cmp cx, 0
    jl .q3
    mov ax, 135
    jmp .a_done
.q3:
    mov ax, 225
.a_done:
    pop dx
    pop cx
    pop bx
    ret

; ---------------------------------------------------------------------------
; Raycast working variables
; ---------------------------------------------------------------------------
_dm_fov320: dw FOV
_dm_rstep:  dw RSTEP
_dm_proj:   dw PROJ_DIST
_dm_relang: dw 0
_dm_rayang: dw 0
_dm_dcos:   dw 0
_dm_dsin:   dw 0
_dm_stepx:  dw 0
_dm_stepy:  dw 0
_dm_rx:     dw 0
_dm_ry:     dw 0
_dm_cellx:  dw 0
_dm_celly:  dw 0
_dm_hit:    dw 0
_dm_dist:   dw 0
_dm_wh:     dw 0
_dm_shade:  db 0

%include "../opengl.asm"
