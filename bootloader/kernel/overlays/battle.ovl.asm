; =============================================================================
; BATTLE.OVL  -  Battleship (solo hunt vs a hidden CPU fleet)  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; 6x6 grid, 3 ships of length 2, placed randomly (straight, non-overlapping).
; Fire by typing a column letter (A-F) then a row digit (1-6), e.g. "C3".
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

GRID_N   equ 6
NUM_SHIPS equ 3
SHIP_LEN equ 2
TOTAL_CELLS equ NUM_SHIPS*SHIP_LEN

STRBUF board, GRID_N*GRID_N     ; 0=water, 1=ship(hidden), 2=miss, 3=hit
U16 bt_rng, 0x8642
U16 hits,   0

STR str_title,  "BATTLESHIP - fire at coords like C3.  3 ships of length 2."
STR str_prompt, "Fire at: "
STR str_hit,    "HIT!"
STR str_miss,   "Miss."
STR str_again_hit, "Already fired there."
STR str_win,    "All ships sunk - you win!"
STR str_hits,   "Hits: "
STR str_of,     " / "
STR str_colhdr, "  A B C D E F"
STR str_again,  "Play again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    mov ah, 0x00
    int 0x1A
    mov [bt_rng], dx
    xor [bt_rng], cx

.new_game:
    mov si, board
    mov cx, GRID_N*GRID_N
    xor al, al
.clr:
    mov [si], al
    inc si
    loop .clr
    mov word [hits], 0

    mov cx, NUM_SHIPS
.place_ship:
    push cx
    call bt_place_one
    pop cx
    loop .place_ship

.loop:
    call bt_draw
    mov ax, [hits]
    cmp ax, TOTAL_CELLS
    jge .win

    Print str_prompt
    GetKey
    call _uc_al
    NewLine
    cmp al, 'A'
    jb .loop
    cmp al, 'F'
    ja .loop
    sub al, 'A'
    movzx bx, al
    mov [_bt_col], bx

    GetKey
    NewLine
    cmp al, '1'
    jb .loop
    cmp al, '6'
    ja .loop
    sub al, '1'
    movzx bx, al
    mov [_bt_row], bx

    mov ax, [_bt_row]
    mov si, GRID_N
    imul si
    add ax, [_bt_col]
    mov si, ax

    mov al, [board + si]
    cmp al, 2
    je .already
    cmp al, 3
    je .already
    cmp al, 1
    je .hit
    mov byte [board + si], 2
    PrintLn str_miss
    GetKey
    jmp .loop
.hit:
    mov byte [board + si], 3
    inc word [hits]
    PrintLn str_hit
    GetKey
    jmp .loop
.already:
    PrintLn str_again_hit
    GetKey
    jmp .loop

.win:
    Banner LTGREEN, str_win
    Print str_again
    GetKey
    NewLine
    cmp al, 'y'
    je .new_game
    cmp al, 'Y'
    je .new_game
ENDFN
_bt_col: dw 0
_bt_row: dw 0

; ---------------------------------------------------------------------------
; U0 bt_place_one()  -  randomly place one straight 2-cell ship, retrying
; until it doesn't overlap an existing ship.
; ---------------------------------------------------------------------------
bt_place_one:
    push ax
    push bx
    push cx
    push dx
    push si
.retry:
    call bt_rand
    and ax, 1
    mov [_bt_horiz], ax

    call bt_rand
    xor dx, dx
    mov bx, GRID_N
    div bx
    mov [_bt_r0], dx

    call bt_rand
    xor dx, dx
    mov bx, GRID_N
    div bx
    mov [_bt_c0], dx

    mov ax, [_bt_r0]
    mov bx, [_bt_c0]
    cmp word [_bt_horiz], 0
    je .vert
    add bx, SHIP_LEN - 1
    jmp .calc2
.vert:
    add ax, SHIP_LEN - 1
.calc2:
    cmp ax, GRID_N
    jge .retry
    cmp bx, GRID_N
    jge .retry
    mov [_bt_r1], ax
    mov [_bt_c1], bx

    ; check both cells are free
    mov ax, [_bt_r0]
    mov si, GRID_N
    imul si
    add ax, [_bt_c0]
    mov si, ax
    cmp byte [board + si], 0
    jne .retry
    mov [_bt_i0], si

    mov ax, [_bt_r1]
    mov si, GRID_N
    imul si
    add ax, [_bt_c1]
    mov si, ax
    cmp byte [board + si], 0
    jne .retry
    mov [_bt_i1], si

    mov si, [_bt_i0]
    mov byte [board + si], 1
    mov si, [_bt_i1]
    mov byte [board + si], 1

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
_bt_horiz: dw 0
_bt_r0: dw 0
_bt_c0: dw 0
_bt_r1: dw 0
_bt_c1: dw 0
_bt_i0: dw 0
_bt_i1: dw 0

; ---------------------------------------------------------------------------
; U0 bt_draw()
; ---------------------------------------------------------------------------
bt_draw:
    push ax
    push bx
    push cx
    push si
    ClearScreen
    Banner CYAN, str_title
    NewLine
    Print str_hits
    mov ax, [hits]
    call print_word_dec
    Print str_of
    mov ax, TOTAL_CELLS
    call print_word_dec
    NewLine
    NewLine
    PrintLn str_colhdr

    xor bx, bx
.row:
    cmp bx, GRID_N
    jge .rowdone
    mov ax, bx
    inc ax
    call print_word_dec
    PrintChar ' '
    xor cx, cx
.col:
    cmp cx, GRID_N
    jge .coldone
    mov ax, bx
    mov si, GRID_N
    imul si
    add ax, cx
    mov si, ax
    mov al, [board + si]
    cmp al, 3
    je .ch_hit
    cmp al, 2
    je .ch_miss
    PrintChar '.'
    jmp .chdone
.ch_hit:
    SetColor LTRED
    PrintChar 'X'
    SetColor LTGRAY
    jmp .chdone
.ch_miss:
    PrintChar 'o'
.chdone:
    PrintChar ' '
    inc cx
    jmp .col
.coldone:
    NewLine
    inc bx
    jmp .row
.rowdone:
    NewLine
    pop si
    pop cx
    pop bx
    pop ax
    ret

bt_rand:
    push bx
    mov ax, [bt_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [bt_rng], ax
    pop bx
    ret
