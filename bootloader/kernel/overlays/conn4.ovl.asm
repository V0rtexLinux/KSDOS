; =============================================================================
; CONN4.OVL  -  Connect Four  (KSDOS 16-bit)
; A/D = move selector, SPACE = drop.  ESC = quit.
; 7 cols x 6 rows.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

CCOLS   equ 7
CROWS   equ 6
CELL    equ 36
OX      equ 14
OY      equ 30

STR str_title,  "CONNECT 4  [AD=move SPC=drop ESC=quit]"
STR str_p1,     "P1 (Red) wins! Any key"
STR str_p2,     "P2 (Yellow) wins! Any key"
STR str_draw,   "DRAW! Any key"
STR str_p1t,    "P1 RED"
STR str_p2t,    "P2 YELLOW"
STR str_turn,   "Turn:"
STRBUF sbuf, 4

; Board: CROWS * CCOLS bytes (0=empty, 1=P1/red, 2=P2/yellow)
STRBUF board, CROWS * CCOLS

U16 cur_col, 3       ; selector column
U16 cur_player, 1    ; 1 or 2
U16 pieces, 0        ; total pieces played
U16 ai_delay, 0

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call c4_new_game

.frame:
    ; Input
    mov ah, 0x01
    int 0x16
    jz .draw
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp al, 'a'
    je .mv_left
    cmp al, 'A'
    je .mv_left
    cmp ah, 0x4B
    je .mv_left
    cmp al, 'd'
    je .mv_right
    cmp al, 'D'
    je .mv_right
    cmp ah, 0x4D
    je .mv_right
    cmp al, ' '
    je .drop
    jmp .draw

.mv_left:
    cmp word [cur_col], 0
    je .draw
    dec word [cur_col]
    jmp .draw

.mv_right:
    cmp word [cur_col], CCOLS - 1
    je .draw
    inc word [cur_col]
    jmp .draw

.drop:
    call c4_drop
    cmp ax, 0           ; AX = 0 if column full
    je .draw
    ; Check win
    call c4_check_win
    cmp ax, 1
    je .p1_win
    cmp ax, 2
    je .p2_win
    ; Check draw
    cmp word [pieces], CCOLS * CROWS
    je .draw_game
    ; Switch player
    xor word [cur_player], 3    ; toggle 1<->2
    jmp .draw

.draw:
    mov al, 1
    call gl16_clear
    call c4_draw_board
    call c4_draw_selector
    call c4_draw_ui
    jmp .frame

.p1_win:
    mov al, 0
    call gl16_clear
    call c4_draw_board
    mov bx, 72
    mov dx, 96
    mov al, 12
    mov si, str_p1
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    jmp .quit

.p2_win:
    mov al, 0
    call gl16_clear
    call c4_draw_board
    mov bx, 64
    mov dx, 96
    mov al, 14
    mov si, str_p2
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    jmp .quit

.draw_game:
    mov al, 0
    call gl16_clear
    call c4_draw_board
    mov bx, 108
    mov dx, 96
    mov al, 7
    mov si, str_draw
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16

.quit:
    call gl16_exit
    POP_ALL
ENDFN

c4_new_game:
    push cx
    push di
    mov cx, CROWS * CCOLS
    mov di, board
    xor al, al
    rep stosb
    mov word [cur_col], 3
    mov word [cur_player], 1
    mov word [pieces], 0
    pop di
    pop cx
    ret

; c4_drop: drop piece in cur_col, returns AX=1 if placed, 0 if full
c4_drop:
    push bx
    push cx
    push dx
    push si
    mov bx, [cur_col]
    ; Find lowest empty row in this column
    mov cx, CROWS - 1
.find_row:
    cmp cx, 0
    jl .full
    ; Index = cx * CCOLS + bx
    mov ax, cx
    mov dx, CCOLS
    mul dx
    add ax, bx
    mov si, ax
    cmp byte [board + si], 0
    je .place
    dec cx
    jmp .find_row
.full:
    pop si
    pop dx
    pop cx
    pop bx
    xor ax, ax
    ret
.place:
    mov al, byte [cur_player]
    mov [board + si], al
    inc word [pieces]
    pop si
    pop dx
    pop cx
    pop bx
    mov ax, 1
    ret

; c4_check_win: check if last move won; returns AX=winning player or 0
c4_check_win:
    push bx
    push cx
    push dx
    push si
    push di
    ; Check all horizontal, vertical, diagonal runs of 4
    ; Brute force: scan all cells
    mov ax, [cur_player]
    push ax
    xor cx, cx          ; row
.cr:
    cmp cx, CROWS
    jge .no_win
    xor bx, bx          ; col
.cc:
    cmp bx, CCOLS
    jge .cc_next_row
    ; Get player at (cx, bx)
    push bx
    push cx
    mov ax, cx
    mov dx, CCOLS
    mul dx
    add ax, bx
    mov si, ax
    mov al, [board + si]
    test al, al
    jz .cc_skip
    push ax
    ; Check right (horizontal)
    mov di, bx
    add di, 3
    cmp di, CCOLS
    jge .no_h
    push cx
    push bx
    mov dx, bx
.hloop:
    inc dx
    cmp dx, bx
    jl .no_h
    ; check if same as al at (cx, dx)
    mov bx, cx
    push ax
    mov ax, bx
    mov bx, CCOLS
    mul bx
    add ax, dx
    mov si, ax
    pop ax
    cmp [board + si], al
    jne .no_h_l
    cmp dx, [esp]
    add dx, 0
    jmp .hloop
.no_h_l:
    pop bx
    pop cx
.no_h:
    ; Check down (vertical)
    ; ...simplified: just check 4 in each direction via separate loops
    pop ax
.cc_skip:
    pop cx
    pop bx
.cc_next:
    inc bx
    jmp .cc
.cc_next_row:
    inc cx
    jmp .cr
.no_win:
    ; Simplified approach: scan all 4-in-a-row possibilities
    pop ax
    ; Scan board for 4-in-a-row
    mov ax, [cur_player]
    ; Horizontal
    xor cx, cx
.sh:
    cmp cx, CROWS
    jge .sv
    xor bx, bx
.shc:
    mov di, bx
    add di, 3
    cmp di, CCOLS
    jg .sh_next
    ; Check 4 in row cx starting at col bx
    push bx
    push cx
    push ax
    mov dx, cx
    mul word [.ccols_val]
    add ax, bx
    mov si, ax
    pop ax
    mov dl, [board + si]
    cmp dl, 0
    je .sh_skip
    cmp [board + si + 1], dl
    jne .sh_skip
    cmp [board + si + 2], dl
    jne .sh_skip
    cmp [board + si + 3], dl
    jne .sh_skip
    movzx ax, dl
    pop cx
    pop bx
    jmp .win_found
.sh_skip:
    pop cx
    pop bx
.sh_next:
    inc bx
    jmp .shc
.sv_next_row:
    inc cx
    jmp .sh
; dummy label
.ccols_val: dw CCOLS

.sv:
    ; Vertical
    xor bx, bx
.svc:
    cmp bx, CCOLS
    jge .sd1
    xor cx, cx
.svr:
    mov di, cx
    add di, 3
    cmp di, CROWS
    jg .sv_next_col
    push bx
    push cx
    mov ax, cx
    mov dx, CCOLS
    mul dx
    add ax, bx
    mov si, ax
    mov dl, [board + si]
    cmp dl, 0
    je .sv_skip
    add si, CCOLS
    cmp [board + si], dl
    jne .sv_skip
    add si, CCOLS
    cmp [board + si], dl
    jne .sv_skip
    add si, CCOLS
    cmp [board + si], dl
    jne .sv_skip
    movzx ax, dl
    pop cx
    pop bx
    jmp .win_found
.sv_skip:
    pop cx
    pop bx
    inc cx
    jmp .svr
.sv_next_col:
    inc bx
    jmp .svc

.sd1:
    ; Diagonal \
    xor cx, cx
.sd1r:
    cmp cx, CROWS - 3
    jg .sd2
    xor bx, bx
.sd1c:
    cmp bx, CCOLS - 3
    jg .sd1_next_row
    push bx
    push cx
    mov ax, cx
    mov dx, CCOLS
    mul dx
    add ax, bx
    mov si, ax
    mov dl, [board + si]
    cmp dl, 0
    je .sd1_skip
    add si, CCOLS + 1
    cmp [board + si], dl
    jne .sd1_skip
    add si, CCOLS + 1
    cmp [board + si], dl
    jne .sd1_skip
    add si, CCOLS + 1
    cmp [board + si], dl
    jne .sd1_skip
    movzx ax, dl
    pop cx
    pop bx
    jmp .win_found
.sd1_skip:
    pop cx
    pop bx
    inc bx
    jmp .sd1c
.sd1_next_row:
    inc cx
    jmp .sd1r

.sd2:
    ; Diagonal /
    xor cx, cx
.sd2r:
    cmp cx, CROWS - 3
    jg .done_win
    mov bx, 3
.sd2c:
    cmp bx, CCOLS
    jge .sd2_next_row
    push bx
    push cx
    mov ax, cx
    mov dx, CCOLS
    mul dx
    add ax, bx
    mov si, ax
    mov dl, [board + si]
    cmp dl, 0
    je .sd2_skip
    add si, CCOLS - 1
    cmp [board + si], dl
    jne .sd2_skip
    add si, CCOLS - 1
    cmp [board + si], dl
    jne .sd2_skip
    add si, CCOLS - 1
    cmp [board + si], dl
    jne .sd2_skip
    movzx ax, dl
    pop cx
    pop bx
    jmp .win_found
.sd2_skip:
    pop cx
    pop bx
    inc bx
    jmp .sd2c
.sd2_next_row:
    inc cx
    jmp .sd2r

.done_win:
    xor ax, ax
.win_found:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

c4_draw_board:
    push ax
    push bx
    push cx
    push dx
    push si
    ; Background
    mov bx, OX - 4
    mov cx, OX + CCOLS * CELL + 4
    mov dx, OY - 4
    mov al, 1
    push dx
    push bx
    push cx
    mov cx, CROWS * CELL + 8
.bg:
    pop cx
    pop bx
    push bx
    push cx
    call gl16_hline
    inc dx
    loop .bg
    pop cx
    pop bx
    pop dx
    ; Draw circles for each cell
    xor cx, cx
.row:
    cmp cx, CROWS
    jge .db_done
    xor bx, bx
.col:
    cmp bx, CCOLS
    jge .next_row
    ; Centre pixel
    push bx
    push cx
    mov ax, bx
    mov dx, CELL
    mul dx
    add ax, OX + CELL/2
    mov bx, ax          ; cx_pix
    mov ax, cx
    mul dx
    add ax, OY + CELL/2
    mov dx, ax          ; cy_pix
    ; Get piece
    mov ax, cx
    push bx
    push dx
    mov bx, CCOLS
    mul bx
    pop dx
    pop bx
    push bx
    push dx
    add ax, [esp + 8]   ; col (original bx from push)
    ; actually recompute
    pop dx
    pop bx
    pop cx
    pop bx
    push bx
    push cx
    mov ax, cx
    mov si, CCOLS
    mul si
    add ax, bx
    mov si, ax
    mov al, [board + si]
    ; Colour based on player
    cmp al, 1
    je .col_red
    cmp al, 2
    je .col_yel
    mov al, 8           ; dark grey empty
    jmp .draw_circle
.col_red:
    mov al, 12
    jmp .draw_circle
.col_yel:
    mov al, 14
.draw_circle:
    ; Draw filled circle (approx rectangle CELL-8 x CELL-8)
    push ax
    ; Recompute pixel centre
    mov ax, bx
    mov si, CELL
    mul si
    add ax, OX
    push ax
    mov ax, cx
    mul si
    add ax, OY
    mov dx, ax
    pop bx
    add bx, 4
    add dx, 4
    pop ax
    push ax
    ; Draw CELL-8 rows
    mov cx, CELL - 8
.dr:
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
    loop .dr
    pop ax
    pop cx
    pop bx
    inc bx
    jmp .col
.next_row:
    inc cx
    jmp .row
.db_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

c4_draw_selector:
    push ax
    push bx
    push cx
    push dx
    mov bx, [cur_col]
    mov ax, CELL
    mul bx
    add ax, OX + CELL/2 - 4
    mov bx, ax
    mov dx, OY - 16
    ; Arrow indicator
    mov cx, 8
.ar:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, 7
    cmp word [cur_player], 1
    je .ar_r
    mov al, 14
    jmp .ar_draw
.ar_r:
    mov al, 12
.ar_draw:
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .ar
    pop dx
    pop cx
    pop bx
    pop ax
    ret

c4_draw_ui:
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
    mov al, str_turn - str_turn   ; 0 trick — just use label
    mov al, 7
    mov si, str_turn
    call gl16_text_gfx
    cmp word [cur_player], 1
    jne .p2
    mov bx, 44
    mov dx, 185
    mov al, 12
    mov si, str_p1t
    call gl16_text_gfx
    jmp .ui_done
.p2:
    mov bx, 44
    mov dx, 185
    mov al, 14
    mov si, str_p2t
    call gl16_text_gfx
.ui_done:
    pop si
    pop dx
    pop bx
    pop ax
    ret

%include "../opengl.asm"
