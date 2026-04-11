; =============================================================================
; GOLF.OVL  -  Mini Golf / Putter  (KSDOS 16-bit)
; LEFT/RIGHT = aim, SPACE (hold) = power, SPACE (release) = shoot.
; Sink the ball in the hole in fewest strokes.  9 holes.  ESC = quit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

STR str_title,  "MINI GOLF  [<>=aim SPACE=power/shoot ESC=quit]"
STR str_hole,   "Hole:"
STR str_stroke, "Strokes:"
STR str_total,  "Total:"
STR str_par,    "Par:"
STR str_win,    "ROUND COMPLETE! Any key"
STRBUF sbuf, 8

; Ball state (fixed-point *16)
I16 ball_x, 30 * 16
I16 ball_y, 100 * 16
I16 ball_vx, 0
I16 ball_vy, 0
U16 ball_stopped, 1    ; 1=at rest

; Hole position
U16 hole_x, 280
U16 hole_y, 100
U16 hole_r, 8

U16 aim_ang, 0          ; 0=right, increases CW
U16 power, 0
U16 power_dir, 1        ; charging direction
U16 charging, 0
U16 strokes, 0
U16 total_strokes, 0
U16 cur_hole, 1

; Wall definitions per hole: 4 walls (x1,y1,x2,y2) each 8 bytes, 9 holes
; Each hole has: ball_sx, ball_sy, hole_hx, hole_hy, par
; Stored as pairs
hole_data:
    ; sx, sy, hx, hy, par
    dw  30, 100, 280, 100, 2
    dw  30, 100, 280, 160, 3
    dw  30,  50, 290, 150, 3
    dw  50, 180, 270,  20, 4
    dw  30, 100, 290, 100, 2
    dw  20,  50, 290, 150, 4
    dw  30, 100, 280,  90, 2
    dw  50, 150, 270,  50, 3
    dw  30, 100, 280, 100, 2

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call golf_load_hole

.frame:
    ; Input
    mov ah, 0x01
    int 0x16
    jz .physics
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp ah, 0x4B            ; LEFT: aim CCW
    jne .chk_right
    cmp word [ball_stopped], 0
    je .physics
    mov ax, [aim_ang]
    sub ax, 5
    cmp ax, 0
    jge .ao
    add ax, 360
.ao:
    mov [aim_ang], ax
    jmp .physics
.chk_right:
    cmp ah, 0x4D            ; RIGHT: aim CW
    jne .chk_sp
    cmp word [ball_stopped], 0
    je .physics
    mov ax, [aim_ang]
    add ax, 5
    cmp ax, 360
    jl .ao2
    sub ax, 360
.ao2:
    mov [aim_ang], ax
    jmp .physics
.chk_sp:
    cmp al, ' '
    jne .physics
    cmp word [ball_stopped], 0
    je .physics
    cmp word [charging], 0
    jne .release
    ; Start charging
    mov word [charging], 1
    mov word [power], 0
    mov word [power_dir], 1
    jmp .physics
.release:
    ; Shoot!
    mov word [charging], 0
    inc word [strokes]
    mov ax, [aim_ang]
    call fcos16
    ; Scale by power
    mov bx, [power]
    imul bx
    sar ax, 8
    mov [ball_vx], ax
    mov ax, [aim_ang]
    call fsin16
    neg ax
    mov bx, [power]
    imul bx
    sar ax, 8
    mov [ball_vy], ax
    mov word [ball_stopped], 0

.physics:
    ; Update power charging
    cmp word [charging], 1
    jne .move_ball
    mov ax, [power]
    add ax, [power_dir]
    cmp ax, 20
    jle .pw_ok
    mov word [power_dir], -1
    mov ax, 20
.pw_ok:
    cmp ax, 0
    jge .pw_ok2
    mov word [power_dir], 1
    xor ax, ax
.pw_ok2:
    mov [power], ax

.move_ball:
    cmp word [ball_stopped], 1
    je .draw

    ; Move ball
    mov ax, [ball_vx]
    add [ball_x], ax
    mov ax, [ball_vy]
    add [ball_y], ax

    ; Friction
    mov ax, [ball_vx]
    sar ax, 5
    sub [ball_vx], ax
    mov ax, [ball_vy]
    sar ax, 5
    sub [ball_vy], ax

    ; Wall bounces (screen edges)
    mov ax, [ball_x]
    cmp ax, 5 * 16
    jge .bx_ok
    neg word [ball_vx]
    mov word [ball_x], 5 * 16
    jmp .by
.bx_ok:
    cmp ax, 314 * 16
    jle .by
    neg word [ball_vx]
    mov word [ball_x], 314 * 16
.by:
    mov ax, [ball_y]
    cmp ax, 20 * 16
    jge .by_ok
    neg word [ball_vy]
    mov word [ball_y], 20 * 16
    jmp .stop_chk
.by_ok:
    cmp ax, 194 * 16
    jle .stop_chk
    neg word [ball_vy]
    mov word [ball_y], 194 * 16

.stop_chk:
    ; Stop if velocity near zero
    mov ax, [ball_vx]
    cmp ax, 1
    jg .not_stopped
    cmp ax, -1
    jl .not_stopped
    mov ax, [ball_vy]
    cmp ax, 1
    jg .not_stopped
    cmp ax, -1
    jl .not_stopped
    mov word [ball_vx], 0
    mov word [ball_vy], 0
    mov word [ball_stopped], 1

.not_stopped:
    ; Check if ball in hole
    mov ax, [ball_x]
    sar ax, 4
    sub ax, [hole_x]
    imul ax
    push ax
    mov ax, [ball_y]
    sar ax, 4
    sub ax, [hole_y]
    imul ax
    add ax, [esp]
    pop bx
    ; Compare to hole_r^2
    mov bx, [hole_r]
    imul bx
    cmp ax, bx
    jg .draw
    ; In hole!
    mov ax, [strokes]
    add [total_strokes], ax
    inc word [cur_hole]
    cmp word [cur_hole], 10
    jge .win
    call golf_load_hole
    jmp .draw

.draw:
    mov al, 2
    call gl16_clear

    ; Draw green border
    xor bx, bx
    mov cx, 319
    mov dx, 18
    mov al, 10
    call gl16_hline
    mov dx, 198
    call gl16_hline

    ; Draw hole
    mov bx, [hole_x]
    sub bx, [hole_r]
    mov dx, [hole_y]
    sub dx, [hole_r]
    mov cx, [hole_r]
    shl cx, 1
.hole_row:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, [hole_r]
    add cx, [hole_r]
    xor al, al
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .hole_row
    ; Hole marker (white dot)
    mov bx, [hole_x]
    mov dx, [hole_y]
    mov al, 15
    call gl16_pix
    inc bx
    call gl16_pix

    ; Draw aim line if stopped and not charging
    cmp word [ball_stopped], 1
    jne .draw_ball
    cmp word [charging], 1
    je .draw_power
    ; Aim line
    mov ax, [ball_x]
    sar ax, 4
    mov bx, ax
    mov ax, [ball_y]
    sar ax, 4
    mov dx, ax
    ; Draw 30px line in aim direction
    mov cx, 15
.aim_draw:
    push cx
    push bx
    push dx
    mov ax, [aim_ang]
    call fcos16
    sar ax, 4
    mul cx
    sar ax, 0
    add bx, ax
    mov ax, [aim_ang]
    call fsin16
    neg ax
    sar ax, 4
    mul cx
    sar ax, 0
    add dx, ax
    pop dx
    pop bx
    ; Draw at bx+(fcos*cx/8), dx-(fsin*cx/8)
    ; Simplified: just draw at bx+cx, dx
    push cx
    mov ax, [aim_ang]
    call fcos16
    sar ax, 5
    push ax
    mov ax, [aim_ang]
    call fsin16
    neg ax
    sar ax, 5
    pop cx
    ; use cx=fcos, ax=fsin
    mov si, [esp + 2]   ; the original cx loop counter
    imul si
    add ax, dx          ; ay = dx + fsin * si
    pop cx
    push ax
    mov ax, cx
    imul si
    add ax, bx          ; ax = bx + fcos * si
    mov bx, ax
    pop dx
    mov al, 15
    call gl16_pix
    pop dx
    pop bx
    pop cx
    inc cx
    loop .aim_draw
    jmp .draw_ball

.draw_power:
    ; Power bar
    mov bx, 10
    mov dx, 185
    push bx
    push dx
    mov ax, [power]
    mov cx, ax
    shl cx, 3           ; power * 8 pixels wide
    push cx
    mov cx, bx
    add cx, [esp]
    dec cx
    mov al, 12
    call gl16_hline
    pop cx
    pop dx
    pop bx

.draw_ball:
    ; Draw ball (white circle)
    mov ax, [ball_x]
    sar ax, 4
    sub ax, 4
    mov bx, ax
    mov ax, [ball_y]
    sar ax, 4
    sub ax, 4
    mov dx, ax
    mov cx, 8
.ball_row:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, 7
    mov al, 15
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .ball_row

    ; UI text
    mov bx, 4
    mov dx, 2
    mov al, 15
    mov si, str_hole
    call gl16_text_gfx
    mov ax, [cur_hole]
    mov si, sbuf
    call golf_itoa
    mov bx, 40
    mov dx, 2
    mov al, 14
    mov si, sbuf
    call gl16_text_gfx
    mov bx, 80
    mov dx, 2
    mov al, 7
    mov si, str_stroke
    call gl16_text_gfx
    mov ax, [strokes]
    mov si, sbuf
    call golf_itoa
    mov bx, 136
    mov dx, 2
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx

    jmp .frame

.win:
    mov al, 0
    call gl16_clear
    mov bx, 72
    mov dx, 96
    mov al, 10
    mov si, str_win
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16

.quit:
    call gl16_exit
    POP_ALL
ENDFN

golf_load_hole:
    push ax
    push bx
    push si
    ; Compute index into hole_data (5 words per hole)
    mov ax, [cur_hole]
    dec ax
    mov bx, 10          ; 5 words = 10 bytes per entry
    mul bx
    mov si, ax
    ; Load ball start
    mov ax, [hole_data + si]
    shl ax, 4
    mov [ball_x], ax
    mov ax, [hole_data + si + 2]
    shl ax, 4
    mov [ball_y], ax
    ; Load hole position
    mov ax, [hole_data + si + 4]
    mov [hole_x], ax
    mov ax, [hole_data + si + 6]
    mov [hole_y], ax
    ; Reset state
    mov word [ball_vx], 0
    mov word [ball_vy], 0
    mov word [ball_stopped], 1
    mov word [strokes], 0
    mov word [aim_ang], 0
    mov word [charging], 0
    mov word [power], 0
    pop si
    pop bx
    pop ax
    ret

golf_itoa:
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, si
    add bx, 7
    mov byte [bx], 0
    dec bx
    test ax, ax
    jnz .d
    mov byte [bx], '0'
    dec bx
    jmp .dn
.d:
    test ax, ax
    jz .dn
    xor dx, dx
    mov cx, 10
    div cx
    add dl, '0'
    mov [bx], dl
    dec bx
    jmp .d
.dn:
    inc bx
    mov di, si
.cp:
    mov al, [bx]
    mov [di], al
    test al, al
    jz .cpd
    inc bx
    inc di
    jmp .cp
.cpd:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

%include "../opengl.asm"
