; =============================================================================
; TICTAC.OVL  -  Tic-Tac-Toe vs CPU  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; You are X, CPU is O. CPU tries to win, then blocks, then picks a cell.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

STRBUF board, 9          ; 0=empty, 'X', 'O'
U16 tt_rng, 0xACE1

STR str_title,  "TIC-TAC-TOE - you are X, CPU is O"
STR str_prompt, "Pick a cell (1-9): "
STR str_win,    "You win!"
STR str_lose,   "CPU wins!"
STR str_draw,   "Draw!"
STR str_bad,    "Cell taken, try again."
STR str_again,  "Play again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
.new_game:
    ClearScreen
    Banner CYAN, str_title
    mov si, board
    mov cx, 9
    xor al, al
.clr:
    mov [si], al
    inc si
    loop .clr

.turn_loop:
    call tt_draw
    call tt_check
    cmp al, 0
    jne .game_over

    ; player move
.ask:
    Print str_prompt
    GetKey
    NewLine
    cmp al, '1'
    jb .ask
    cmp al, '9'
    ja .ask
    sub al, '1'
    movzx bx, al
    cmp byte [board + bx], 0
    jne .taken
    mov byte [board + bx], 'X'
    jmp .after_player
.taken:
    PrintLn str_bad
    jmp .ask
.after_player:
    call tt_draw
    call tt_check
    cmp al, 0
    jne .game_over

    call tt_cpu_move
    jmp .turn_loop

.game_over:
    cmp al, 1
    je .p_win
    cmp al, 2
    je .p_lose
    PrintLn str_draw
    jmp .ask_again
.p_win:
    PrintLn str_win
    jmp .ask_again
.p_lose:
    PrintLn str_lose
.ask_again:
    Print str_again
    GetKey
    NewLine
    cmp al, 'y'
    je .new_game
    cmp al, 'Y'
    je .new_game
ENDFN

; ---------------------------------------------------------------------------
; U0 tt_draw()
; ---------------------------------------------------------------------------
tt_draw:
    push ax
    push bx
    push cx
    push dx
    mov dh, 2
    mov dl, 0
    call vid_set_cursor
    xor bx, bx
    mov cx, 0
.row:
    cmp cx, 3
    jge .rdone
    push cx
    mov cx, 3
.col:
    cmp cx, 0
    je .colend
    mov al, [board + bx]
    test al, al
    jnz .have_char
    mov al, bl
    add al, '1'
.have_char:
    call vid_putchar
    inc bx
    dec cx
    cmp cx, 0
    je .colend
    Print str_sep
    jmp .col
.colend:
    pop cx
    NewLine
    inc cx
    cmp cx, 3
    jge .rdone
    PrintLn str_line
    jmp .row
.rdone:
    NewLine
    pop dx
    pop cx
    pop bx
    pop ax
    ret
STR str_sep, " | "
STR str_line, "---------"

; ---------------------------------------------------------------------------
; U0 tt_check() -> AL: 0=ongoing, 1=X wins, 2=O wins, 3=draw
; ---------------------------------------------------------------------------
tt_check:
    push bx
    push cx
    push si
    mov si, tt_lines
    mov cx, 8
.lp:
    push cx
    movzx bx, byte [si]
    mov al, [board + bx]
    test al, al
    jz .next
    movzx bx, byte [si+1]
    cmp al, [board + bx]
    jne .next
    movzx bx, byte [si+2]
    cmp al, [board + bx]
    jne .next
    ; winner found in al ('X' or 'O')
    pop cx
    cmp al, 'X'
    je .xwin
    mov al, 2
    jmp .cdone
.xwin:
    mov al, 1
    jmp .cdone
.next:
    pop cx
    add si, 3
    loop .lp
    ; no winner - check draw (no empty cells)
    xor bx, bx
    mov cx, 9
.dchk:
    cmp byte [board + bx], 0
    je .not_draw
    inc bx
    loop .dchk
    mov al, 3
    jmp .cdone
.not_draw:
    xor al, al
.cdone:
    pop si
    pop cx
    pop bx
    ret

tt_lines:
    db 0,1,2, 3,4,5, 6,7,8, 0,3,6, 1,4,7, 2,5,8, 0,4,8, 2,4,6

; ---------------------------------------------------------------------------
; U0 tt_cpu_move()  -  try win, then block, then first free cell
; ---------------------------------------------------------------------------
tt_cpu_move:
    push ax
    push bx

    mov al, 'O'
    call tt_find_winning_move
    cmp bx, -1
    jne .place

    mov al, 'X'
    call tt_find_winning_move
    cmp bx, -1
    jne .place

    xor bx, bx
.scan:
    cmp byte [board + bx], 0
    je .place
    inc bx
    cmp bx, 9
    jl .scan
    jmp .cpu_done
.place:
    mov byte [board + bx], 'O'
.cpu_done:
    pop bx
    pop ax
    ret

; tt_find_winning_move: AL=mark to check for; returns BX=cell or -1
tt_find_winning_move:
    push ax
    push cx
    push dx
    push si
    mov [_tt_mark], al
    mov si, tt_lines
    mov cx, 8
.lp:
    push cx
    movzx bx, byte [si]
    movzx dx, byte [si+1]
    movzx cx, byte [si+2]
    call tt_test_line
    cmp bx, -1
    pop cx
    jne .found
    add si, 3
    loop .lp
    mov bx, -1
.found:
    pop si
    pop dx
    pop cx
    pop ax
    ret
_tt_mark: db 0

; tt_test_line: BX,DX,CX = three cell indices; returns BX = empty cell that
; completes a two-in-a-row of [_tt_mark], or -1 (BX is otherwise unused as
; a value register here, so it doubles as both an input index and the
; return slot without conflict)
tt_test_line:
    push ax
    push si

    mov al, [board + bx]
    mov [_tt_v0], al
    mov si, dx
    mov al, [board + si]
    mov [_tt_v1], al
    mov si, cx
    mov al, [board + si]
    mov [_tt_v2], al

    mov al, [_tt_mark]
    mov ah, [_tt_v0]
    cmp ah, al
    jne .case_c
    mov ah, [_tt_v1]
    cmp ah, al
    jne .case_b
    ; v0==mark && v1==mark -> need v2 empty
    cmp byte [_tt_v2], 0
    jne .t_none
    mov bx, cx
    jmp .t_found
.case_b:
    ; v0==mark, v1 differs -> maybe v0==mark && v2==mark && v1 empty
    mov ah, [_tt_v2]
    cmp ah, al
    jne .t_none
    cmp byte [_tt_v1], 0
    jne .t_none
    mov bx, dx
    jmp .t_found
.case_c:
    ; v0 differs -> maybe v1==mark && v2==mark && v0 empty
    mov ah, [_tt_v1]
    cmp ah, al
    jne .t_none
    mov ah, [_tt_v2]
    cmp ah, al
    jne .t_none
    cmp byte [_tt_v0], 0
    jne .t_none
    jmp .t_found            ; bx is still idx0, untouched since entry
.t_none:
    mov bx, -1
.t_found:
    pop si
    pop ax
    ret
_tt_v0: db 0
_tt_v1: db 0
_tt_v2: db 0
