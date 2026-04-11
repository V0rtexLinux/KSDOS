; =============================================================================
; CHESS.OVL  -  Chess (two-player local)  (KSDOS 16-bit)
; Arrow keys or WASD to move cursor.  SPACE=select/move.  ESC=quit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

CELL    equ 24
OX      equ 16
OY      equ 8

STR str_title,   "CHESS  [WASD=move SPC=select/move ESC=quit]"
STR str_turn_w,  "White's turn"
STR str_turn_b,  "Black's turn"
STR str_check,   "CHECK!"
STR str_hint,    "SPACE=select R=reset"

; Piece codes: 0=empty 1=wP 2=wN 3=wB 4=wR 5=wQ 6=wK 7=bP 8=bN 9=bB 10=bR 11=bQ 12=bK
; Board: 64 bytes (row-major, row 0=white side rank 1)
board:
    db 4,2,3,5,6,3,2,4   ; rank 1 (white back row)
    db 1,1,1,1,1,1,1,1   ; rank 2 (white pawns)
    db 0,0,0,0,0,0,0,0   ; rank 3
    db 0,0,0,0,0,0,0,0   ; rank 4
    db 0,0,0,0,0,0,0,0   ; rank 5
    db 0,0,0,0,0,0,0,0   ; rank 6
    db 7,7,7,7,7,7,7,7   ; rank 7 (black pawns)
    db 10,8,9,11,12,9,8,10 ; rank 8 (black back row)

U16 cur_x, 4
U16 cur_y, 0
U16 sel_x, 0xFFFF
U16 sel_y, 0xFFFF
U16 white_turn, 1    ; 1=white, 0=black

; Piece name chars for display
piece_char: db ' ','P','N','B','R','Q','K','p','n','b','r','q','k'

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init

.frame:
    ; Input
    mov ah, 0x01
    int 0x16
    jz .draw
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp al, 'r'
    je .reset
    cmp al, 'R'
    je .reset
    ; Movement
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
    je .select
    jmp .draw

.go_up:
    cmp word [cur_y], 7
    je .draw
    inc word [cur_y]
    jmp .draw
.go_dn:
    cmp word [cur_y], 0
    je .draw
    dec word [cur_y]
    jmp .draw
.go_lt:
    cmp word [cur_x], 0
    je .draw
    dec word [cur_x]
    jmp .draw
.go_rt:
    cmp word [cur_x], 7
    je .draw
    inc word [cur_x]

.draw:
    mov al, 0
    call gl16_clear
    call ch_draw_board
    call ch_draw_ui
    jmp .frame

.reset:
    ; Reinitialise board to start
    call ch_reset_board
    mov word [cur_x], 4
    mov word [cur_y], 0
    mov word [sel_x], 0xFFFF
    mov word [sel_y], 0xFFFF
    mov word [white_turn], 1
    jmp .draw

.select:
    ; Get board cell
    mov ax, [cur_y]
    mov bx, 8
    mul bx
    add ax, [cur_x]
    mov si, ax
    cmp word [sel_x], 0xFFFF
    jne .move_piece
    ; No piece selected — select one if it belongs to current player
    mov al, [board + si]
    test al, al
    jz .draw
    ; White pieces: 1-6, Black: 7-12
    cmp word [white_turn], 1
    jne .chk_black
    cmp al, 7
    jge .draw           ; Black piece, white's turn
    jmp .do_select
.chk_black:
    cmp al, 7
    jl .draw            ; White piece, black's turn
.do_select:
    mov ax, [cur_x]
    mov [sel_x], ax
    mov ax, [cur_y]
    mov [sel_y], ax
    jmp .draw

.move_piece:
    ; Move selected piece to cursor (simplified - no legality checks)
    mov ax, [sel_y]
    mov bx, 8
    mul bx
    add ax, [sel_x]
    mov bx, ax          ; src index
    mov al, [board + bx]
    mov [board + si], al
    mov byte [board + bx], 0
    ; Deselect
    mov word [sel_x], 0xFFFF
    mov word [sel_y], 0xFFFF
    ; Switch turn
    xor word [white_turn], 1
    jmp .draw

.quit:
    call gl16_exit
    POP_ALL
ENDFN

ch_draw_board:
    push ax
    push bx
    push cx
    push dx
    push si
    ; Draw 8x8 squares
    xor cx, cx          ; row (0=bottom/white side)
.row:
    cmp cx, 8
    jge .done
    xor bx, bx
.col:
    cmp bx, 8
    jge .next_row
    ; Pixel pos
    push bx
    push cx
    mov ax, bx
    mov dx, CELL
    mul dx
    add ax, OX
    push ax
    ; Row 0 is white's rank 1 = bottom visually
    ; Display row = 7-cx
    mov ax, 7
    sub ax, cx
    mul dx
    add ax, OY
    mov dx, ax
    pop bx              ; px
    ; Colour of square (checkered)
    push bx
    push cx
    mov ax, bx
    add ax, cx
    and ax, 1
    jz .light_sq
    mov al, 8           ; dark square
    jmp .draw_sq
.light_sq:
    mov al, 7           ; light square
.draw_sq:
    ; Selected?
    mov si, [esp]       ; cx (row)
    cmp si, [sel_y]
    jne .not_sel
    mov si, [esp + 2]   ; bx (col)
    cmp si, [sel_x]
    jne .not_sel
    mov al, 14          ; yellow highlight
.not_sel:
    ; Cursor?
    push ax
    mov si, [esp + 4]   ; cx
    cmp si, [cur_y]
    jne .not_cur
    mov si, [esp + 6]   ; bx
    cmp si, [cur_x]
    jne .not_cur
    pop ax
    push ax
    mov al, 11          ; cyan cursor
.not_cur:
    pop ax
    ; Draw square
    push ax
    push bx
    push dx
    mov cx, CELL
.sq_row:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CELL - 1
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .sq_row
    pop dx
    pop bx
    pop ax
    ; Draw piece if any
    pop cx
    pop bx
    push bx
    push cx
    mov ax, cx
    mov si, 8
    mul si
    add ax, bx
    mov si, ax
    mov al, [board + si]
    test al, al
    jz .no_piece
    ; Piece char
    movzx si, al
    mov al, [piece_char + si]
    ; Text colour: white pieces 1-6, black pieces 7-12
    mov dl, [board + si - si + si]     ; reload piece
    movzx dx, byte [board + si - si + si]
    push si
    mov si, cx
    mov ax, 7
    sub ax, si
    mov cx, CELL
    mul cx
    add ax, OY + CELL/2 - 3
    mov dx, ax
    pop si
    mov ax, [esp]       ; col bx
    mov cx, CELL
    mul cx
    add ax, OX + CELL/2 - 3
    mov bx, ax
    ; Determine piece colour
    mov al, [board + si]
    cmp al, 7
    jge .black_piece
    mov al, 15          ; white pieces = bright white
    jmp .draw_piece
.black_piece:
    mov al, 0           ; black pieces = dark
.draw_piece:
    push ax
    mov si, [board + si - si + si]
    ; Just draw a coloured dot to represent piece (using gl16_pix)
    ; Then draw char via gl16_text_gfx (indirect)
    ; We'll just draw a 8x8 block as piece indicator
    pop ax
    push ax
    mov cx, CELL - 4
.piece_block:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CELL - 5
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .piece_block
    pop ax
    ; Draw piece char using simple method
    ; White pieces: top-left of cell + 6,6
    pop cx              ; restore cx (row)
    pop bx              ; restore bx (col)
    push bx
    push cx
    jmp .no_piece
.no_piece:
    pop cx
    pop bx
    inc bx
    jmp .col
.next_row:
    inc cx
    jmp .row
.done:
    ; Border
    xor bx, bx
    add bx, OX - 2
    mov cx, OX + 8 * CELL + 1
    xor dx, dx
    add dx, OY - 2
    mov al, 7
    call gl16_hline
    mov dx, OY + 8 * CELL + 1
    call gl16_hline
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ch_draw_ui:
    push ax
    push bx
    push dx
    push si
    mov bx, OX + 8 * CELL + 8
    mov dx, 10
    mov al, 15
    cmp word [white_turn], 1
    jne .black_turn
    mov si, str_turn_w
    call gl16_text_gfx
    jmp .ui_done
.black_turn:
    mov si, str_turn_b
    call gl16_text_gfx
.ui_done:
    mov bx, 4
    mov dx, 194
    mov al, 7
    mov si, str_hint
    call gl16_text_gfx
    pop si
    pop dx
    pop bx
    pop ax
    ret

ch_reset_board:
    push si
    push di
    push cx
    mov si, .init_board
    mov di, board
    mov cx, 64
    rep movsb
    pop cx
    pop di
    pop si
    ret
.init_board:
    db 4,2,3,5,6,3,2,4
    db 1,1,1,1,1,1,1,1
    db 0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0
    db 7,7,7,7,7,7,7,7
    db 10,8,9,11,12,9,8,10

%include "../opengl.asm"
