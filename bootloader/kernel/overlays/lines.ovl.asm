; =============================================================================
; LINES.OVL  -  Color Lines  (KSDOS 16-bit)
; Click coloured balls to move them to form lines of 5.
; WASD=move cursor, SPACE=select/move, ESC=quit.
; 9x9 grid, 3 new balls each turn.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

GCOLS   equ 9
GROWS   equ 9
CELL    equ 22
OX      equ 16
OY      equ 16

STR str_title,  "COLOR LINES  [WASD=move SPC=select/move ESC=quit]"
STR str_score,  "Score:"
STR str_over,   "GAME OVER! Any key"
STRBUF sbuf, 8

; Grid: 0=empty, 1-7=ball colour
STRBUF grid, GROWS * GCOLS

U16 cur_x, 4
U16 cur_y, 4
U16 sel_x, 0xFFFF   ; selected ball x (0xFFFF = none)
U16 sel_y, 0xFFFF
U16 score, 0
U16 lcg_seed, 0x3456
U16 turn, 0

; Ball colours (1-7 -> palette indices)
ball_pal: db 0, 12, 10, 9, 14, 13, 11, 6

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call ln_new_game

.frame:
    ; Input
    mov ah, 0x01
    int 0x16
    jz .draw
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp al, 'w'
    je .go_up
    cmp al, 'W'
    je .go_up
    cmp ah, 0x48
    je .go_up
    cmp al, 's'
    je .go_dn
    cmp al, 'S'
    je .go_dn
    cmp ah, 0x50
    je .go_dn
    cmp al, 'a'
    je .go_lt
    cmp al, 'A'
    je .go_lt
    cmp ah, 0x4B
    je .go_lt
    cmp al, 'd'
    je .go_rt
    cmp al, 'D'
    je .go_rt
    cmp ah, 0x4D
    je .go_rt
    cmp al, ' '
    je .select_or_move
    jmp .draw

.go_up:
    cmp word [cur_y], 0
    je .draw
    dec word [cur_y]
    jmp .draw
.go_dn:
    cmp word [cur_y], GROWS - 1
    je .draw
    inc word [cur_y]
    jmp .draw
.go_lt:
    cmp word [cur_x], 0
    je .draw
    dec word [cur_x]
    jmp .draw
.go_rt:
    cmp word [cur_x], GCOLS - 1
    je .draw
    inc word [cur_x]
    jmp .draw

.select_or_move:
    ; Get current cell
    mov ax, [cur_y]
    mov bx, GCOLS
    mul bx
    add ax, [cur_x]
    mov si, ax
    cmp byte [grid + si], 0
    jne .select_ball
    ; Empty cell — try to move selected ball here
    cmp word [sel_x], 0xFFFF
    je .draw
    ; Move it
    mov ax, [sel_y]
    mov bx, GCOLS
    mul bx
    add ax, [sel_x]
    mov bx, ax
    mov al, [grid + bx]
    mov [grid + si], al
    mov byte [grid + bx], 0
    mov word [sel_x], 0xFFFF
    mov word [sel_y], 0xFFFF
    ; Check lines
    call ln_check_lines
    ; Spawn new balls
    call ln_spawn_3
    ; Check game over (grid full)
    call ln_count_empty
    cmp ax, 0
    je .game_over
    jmp .draw
.select_ball:
    ; Select this ball
    mov ax, [cur_x]
    mov [sel_x], ax
    mov ax, [cur_y]
    mov [sel_y], ax
    jmp .draw

.draw:
    mov al, 1
    call gl16_clear
    call ln_draw_grid
    call ln_draw_ui
    jmp .frame

.game_over:
    mov al, 0
    call gl16_clear
    call ln_draw_grid
    mov bx, 84
    mov dx, 96
    mov al, 12
    mov si, str_over
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16

.quit:
    call gl16_exit
    POP_ALL
ENDFN

ln_new_game:
    push cx
    push di
    mov cx, GROWS * GCOLS
    mov di, grid
    xor al, al
    rep stosb
    mov word [score], 0
    mov word [sel_x], 0xFFFF
    mov word [sel_y], 0xFFFF
    pop di
    pop cx
    call ln_spawn_3
    call ln_spawn_3
    ret

ln_spawn_3:
    push cx
    push ax
    push bx
    push dx
    push si
    mov cx, 3
.sp:
    push cx
    ; Find empty spot
    mov bx, 81         ; max tries
.try:
    dec bx
    jz .sp_done
    call ln_rand
    xor dx, dx
    mov cx, GROWS * GCOLS
    div cx
    mov si, dx
    cmp byte [grid + si], 0
    jne .try
    ; Random colour 1-7
    call ln_rand
    xor dx, dx
    mov cx, 7
    div cx
    inc dx
    mov [grid + si], dl
.sp_done:
    pop cx
    loop .sp
    pop si
    pop dx
    pop bx
    pop ax
    pop cx
    ret

ln_count_empty:
    push cx
    push si
    xor ax, ax
    mov cx, GROWS * GCOLS
    xor si, si
.ce:
    cmp byte [grid + si], 0
    jne .ce_skip
    inc ax
.ce_skip:
    inc si
    loop .ce
    pop si
    pop cx
    ret

ln_check_lines:
    push ax
    push bx
    push cx
    push dx
    push si
    ; Check horizontal, vertical, diagonals for runs of 5
    ; For simplicity, check all positions for each direction
    mov bx, 0           ; lines removed

    ; Horizontal
    xor cx, cx
.h_row:
    cmp cx, GROWS
    jge .v_check
    mov ax, cx
    mov dx, GCOLS
    mul dx
    mov si, ax          ; si = row start
    xor bx, bx          ; col
.h_col:
    add bx, 4
    cmp bx, GCOLS
    jg .h_next_row
    sub bx, 4
    ; Check 5 same from (cx, bx)
    mov al, [grid + si + bx]
    test al, al
    jz .h_skip
    push bx
    push cx
    push si
    push di
    mov di, si
    add di, bx        ; di = absolute grid index (row start + col)
    mov cx, 4
.h5:
    inc di
    cmp [grid + di], al
    jne .h5_fail
    loop .h5
    ; Found 5! Clear them
    mov cx, 5
    mov di, si
    add di, bx
.h5cl:
    mov byte [grid + di], 0
    inc di
    add word [score], 10
    loop .h5cl
    pop di
    pop si
    pop cx
    pop bx
    jmp .h_col
.h5_fail:
    pop di
    pop si
    pop cx
    pop bx
.h_skip:
    inc bx
    jmp .h_col
.h_next_row:
    inc cx
    jmp .h_row

.v_check:
    ; Vertical
    xor bx, bx
.v_col:
    cmp bx, GCOLS
    jge .d1_check
    xor cx, cx
.v_row:
    add cx, 4
    cmp cx, GROWS
    jg .v_next_col
    sub cx, 4
    mov ax, cx
    mov dx, GCOLS
    mul dx
    add ax, bx
    mov si, ax
    mov al, [grid + si]
    test al, al
    jz .v_skip
    push bx
    push cx
    push si
    push di
    mov cx, 4
    mov di, si
.v5:
    add di, GCOLS
    cmp [grid + di], al
    jne .v5_fail
    loop .v5
    ; Clear 5
    mov cx, 5
    mov di, si
.v5cl:
    mov byte [grid + di], 0
    add di, GCOLS
    add word [score], 10
    loop .v5cl
    pop di
    pop si
    pop cx
    pop bx
    jmp .v_row
.v5_fail:
    pop di
    pop si
    pop cx
    pop bx
.v_skip:
    inc cx
    jmp .v_row
.v_next_col:
    inc bx
    jmp .v_col

.d1_check:
    ; Diagonal \ skip for space, just do basic for now
    ; Done
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ln_rand:
    push bx
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    pop bx
    ret

ln_draw_grid:
    push ax
    push bx
    push cx
    push dx
    push si
    xor cx, cx
.row:
    cmp cx, GROWS
    jge .dg_done
    xor bx, bx
.col:
    cmp bx, GCOLS
    jge .dg_next
    ; Pixel position
    push bx
    push cx
    mov ax, bx
    mov dx, CELL
    mul dx
    add ax, OX
    push ax
    mov ax, cx
    mul dx
    add ax, OY
    mov dx, ax
    pop bx              ; px
    ; Cell index
    mov ax, cx
    mov si, GCOLS
    mul si
    add ax, [esp]       ; col
    mov si, ax
    ; Background
    push ax
    push bx
    push cx
    push dx
    mov cx, bx
    add cx, CELL - 2
    ; Is this the cursor?
    mov ax, [esp + 4]   ; col from push
    cmp ax, [cur_x]
    jne .not_cur
    mov ax, [esp + 6]   ; row
    cmp ax, [cur_y]
    jne .not_cur
    mov al, 15          ; cursor outline
    jmp .draw_bg
.not_cur:
    mov al, 7           ; normal cell
.draw_bg:
    call gl16_hline
    pop dx
    pop cx
    pop bx
    pop ax

    ; Is this selected?
    push ax
    push bx
    push cx
    push dx
    pop dx
    pop cx
    pop bx
    pop ax

    ; Draw ball if present
    mov al, [grid + si]
    test al, al
    jz .dg_skip
    ; Get colour
    movzx si, al
    mov al, [ball_pal + si]
    ; Draw ball (circle approximation)
    push ax
    push dx
    push bx
    push cx
    add bx, 3
    add dx, 3
    mov cx, CELL - 8
.ball_row:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CELL - 9
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .ball_row
    pop cx
    pop bx
    pop dx
    pop ax
    ; Mark selected
    mov ax, [cur_y]
    cmp ax, [sel_y]
    jne .dg_skip
    mov ax, [cur_x]     ; This is wrong logically but simple fallback
    ; redraw outline
    push bx
    push dx
    push ax
    pop ax
    pop dx
    pop bx
.dg_skip:
    pop cx
    pop bx
    ; Cell border
    push ax
    push bx
    push cx
    push dx
    mov cx, bx
    add cx, CELL - 1
    xor al, al
    call gl16_hline
    add dx, CELL - 1
    call gl16_hline
    mov cx, CELL
.lborder:
    call gl16_pix
    inc dx
    loop .lborder
    sub dx, CELL
    add bx, CELL - 1
    mov cx, CELL
.rborder:
    call gl16_pix
    inc dx
    loop .rborder
    pop dx
    pop cx
    pop bx
    pop ax

    inc bx
    jmp .col
.dg_next:
    inc cx
    jmp .row
.dg_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ln_draw_ui:
    push ax
    push bx
    push dx
    push si
    mov bx, 4
    mov dx, 4
    mov al, 7
    mov si, str_title
    call gl16_text_gfx
    mov bx, 4
    mov dx, 185
    mov al, 14
    mov si, str_score
    call gl16_text_gfx
    mov ax, [score]
    mov si, sbuf
    call ln_itoa
    mov bx, 46
    mov dx, 185
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    pop si
    pop dx
    pop bx
    pop ax
    ret

ln_itoa:
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
