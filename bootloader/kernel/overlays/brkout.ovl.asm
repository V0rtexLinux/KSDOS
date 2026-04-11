; =============================================================================
; BRKOUT.OVL  -  Breakout / Arkanoid  (KSDOS 16-bit)
; LEFT/RIGHT arrows to move paddle.  ESC = quit.
; 8 rows x 14 cols of bricks.  Ball bounces.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

PAD_W   equ 40
PAD_H   equ 6
PAD_Y   equ 185
BRK_W   equ 20
BRK_H   equ 8
BRK_COLS equ 14
BRK_ROWS equ 8
BRK_OX  equ 20     ; brick area left X
BRK_OY  equ 20     ; brick area top Y
BALL_R  equ 3

STR str_title,   "BRKOUT  [<> move  ESC quit]"
STR str_score,   "Score:"
STR str_lives,   "Lives:"
STR str_win,     "YOU WIN! Any key"
STR str_lose,    "GAME OVER Any key"
STRBUF sbuf, 6

U16 pad_x,   140
I16 ball_x,  160
I16 ball_y,  160
I16 ball_vx,  2
I16 ball_vy, -2
U16 score,    0
U16 lives,    3
U16 bricks_left, BRK_COLS * BRK_ROWS
U16 lcg_seed, 0x5678

; Brick map: BRK_ROWS x BRK_COLS bytes (0=gone, 1-7=colour)
STRBUF brkmap, BRK_ROWS * BRK_COLS

; Brick colours per row
brk_cols: db 12,12,6,6,10,10,11,11

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call brk_init

.frame:
    ; Key input
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp ah, 0x4B        ; LEFT
    jne .chk_right
    mov ax, [pad_x]
    cmp ax, 2
    jle .no_key
    sub word [pad_x], 4
    jmp .no_key
.chk_right:
    cmp ah, 0x4D        ; RIGHT
    jne .no_key
    mov ax, [pad_x]
    add ax, PAD_W
    cmp ax, 318
    jge .no_key
    add word [pad_x], 4

.no_key:
    ; Move ball
    mov ax, [ball_x]
    add ax, [ball_vx]
    mov [ball_x], ax
    mov ax, [ball_y]
    add ax, [ball_vy]
    mov [ball_y], ax

    ; Wall bounces
    mov ax, [ball_x]
    cmp ax, BALL_R
    jge .wall_r
    neg word [ball_vx]
    mov word [ball_x], BALL_R
    jmp .wall_done
.wall_r:
    cmp ax, 319 - BALL_R
    jle .wall_done
    neg word [ball_vx]
    mov word [ball_x], 319 - BALL_R
.wall_done:

    ; Top bounce
    mov ax, [ball_y]
    cmp ax, BALL_R
    jge .top_done
    neg word [ball_vy]
    mov word [ball_y], BALL_R
.top_done:

    ; Paddle collision
    mov ax, [ball_y]
    cmp ax, PAD_Y - BALL_R
    jl .brk_check
    cmp ax, PAD_Y + PAD_H
    jg .ball_lost
    mov bx, [ball_x]
    cmp bx, [pad_x]
    jl .brk_check
    mov cx, [pad_x]
    add cx, PAD_W
    cmp bx, cx
    jg .brk_check
    neg word [ball_vy]
    mov word [ball_y], PAD_Y - BALL_R - 1
    jmp .brk_check

.ball_lost:
    dec word [lives]
    cmp word [lives], 0
    jle .lose
    ; Reset ball
    mov word [ball_x], 160
    mov word [ball_y], 150
    mov word [ball_vx], 2
    mov word [ball_vy], -2
    jmp .draw

.brk_check:
    ; Check brick collision
    call brk_check_ball

.draw:
    mov al, 1
    call gl16_clear
    call brk_draw_bricks
    ; Draw paddle
    mov bx, [pad_x]
    mov dx, PAD_Y
    mov cx, PAD_H
.pad_row:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, PAD_W - 1
    mov al, 14
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .pad_row
    ; Draw ball
    mov bx, [ball_x]
    sub bx, BALL_R
    mov dx, [ball_y]
    sub dx, BALL_R
    mov cx, BALL_R * 2
.ball_row:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, BALL_R * 2
    mov al, 15
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .ball_row
    ; UI
    mov bx, 4
    mov dx, 4
    mov al, 7
    mov si, str_title
    call gl16_text_gfx
    call brk_delay
    ; Check win
    cmp word [bricks_left], 0
    je .win
    jmp .frame

.win:
    mov al, 0
    call gl16_clear
    mov bx, 76
    mov dx, 96
    mov al, 10
    mov si, str_win
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    jmp .quit

.lose:
    mov al, 0
    call gl16_clear
    mov bx, 64
    mov dx, 96
    mov al, 12
    mov si, str_lose
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16

.quit:
    call gl16_exit
    POP_ALL
ENDFN

brk_init:
    push ax
    push bx
    push cx
    ; Fill brick map
    mov cx, BRK_ROWS * BRK_COLS
    mov di, brkmap
    mov bx, 0           ; row counter
    mov si, 0           ; col counter
.fill:
    mov al, [brk_cols + bx]
    stosb
    inc si
    cmp si, BRK_COLS
    jl .fill_next
    mov si, 0
    inc bx
.fill_next:
    loop .fill
    mov word [bricks_left], BRK_ROWS * BRK_COLS
    pop cx
    pop bx
    pop ax
    ret

brk_draw_bricks:
    push ax
    push bx
    push cx
    push dx
    push si
    xor si, si
    xor cx, cx          ; row
.row:
    cmp cx, BRK_ROWS
    jge .bd_done
    xor bx, bx          ; col
.col:
    cmp bx, BRK_COLS
    jge .bd_next_row
    mov al, [brkmap + si]
    test al, al
    jz .bd_skip
    ; Compute pixel coords
    push ax
    push bx
    push cx
    mov ax, bx
    mov dx, BRK_W
    mul dx
    add ax, BRK_OX
    push ax             ; px
    mov ax, cx
    mul dx
    add ax, BRK_OY
    mov dx, ax          ; py
    pop bx              ; px -> bx
    pop ax
    push ax
    push bx
    push si
    ; Draw BRK_H rows of hline
    mov cx, BRK_H
.brow:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, BRK_W - 2
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .brow
    pop si
    pop bx
    pop cx
    pop ax
.bd_skip:
    inc si
    inc bx
    jmp .col
.bd_next_row:
    inc cx
    jmp .row
.bd_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

brk_check_ball:
    push ax
    push bx
    push cx
    push dx
    push si
    mov ax, [ball_x]
    sub ax, BRK_OX
    cmp ax, 0
    jl .bc_done
    cmp ax, BRK_COLS * BRK_W
    jge .bc_done
    mov bx, [ball_y]
    sub bx, BRK_OY
    cmp bx, 0
    jl .bc_done
    cmp bx, BRK_ROWS * BRK_H
    jge .bc_done
    ; Compute row and col
    xor dx, dx
    mov cx, BRK_W
    div cx
    mov cx, ax          ; col
    mov ax, bx
    xor dx, dx
    mov bx, BRK_H
    div bx
    mov bx, ax          ; row
    ; Index into brkmap
    push cx
    mov ax, bx
    mov cx, BRK_COLS
    mul cx
    pop cx
    add ax, cx
    mov si, ax
    cmp byte [brkmap + si], 0
    je .bc_done
    ; Break this brick
    mov byte [brkmap + si], 0
    dec word [bricks_left]
    add word [score], 10
    neg word [ball_vy]
.bc_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

brk_delay:
    push cx
    mov cx, 0x2000
.d:
    loop .d
    pop cx
    ret

%include "../opengl.asm"
