; =============================================================================
; NIM.OVL  -  The game of Nim vs CPU  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Three piles. Take any number (>=1) of objects from one pile on your turn.
; Whoever takes the last object WINS. CPU plays the optimal nim-sum strategy.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

WORDBUF piles, 3
STRBUF nbuf, 6

STR str_title,  "NIM - take objects, last one to move WINS"
STR str_pile,   "Pile "
STR str_colon,  ": "
STR str_pnum,   "Which pile (1-3)? "
STR str_take,   "How many to take? "
STR str_bad,    "Invalid move."
STR str_cpu,    "CPU takes "
STR str_from,   " from pile "
STR str_win,    "You took the last one - you WIN!"
STR str_lose,   "CPU took the last one - CPU wins."
STR str_again,  "Play again? (Y/N): "
STR str_star,   "*"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
.new_game:
    ClearScreen
    Banner CYAN, str_title
    NewLine
    mov word [piles+0], 3
    mov word [piles+2], 5
    mov word [piles+4], 7

.turn:
    call nim_draw
    call nim_total
    cmp ax, 0
    je .cpu_wins_check     ; shouldn't happen at start of a turn, safety

    ; ---- player's move ----
.ask_pile:
    Print str_pnum
    GetKey
    NewLine
    cmp al, '1'
    jb .ask_pile
    cmp al, '3'
    ja .ask_pile
    sub al, '1'
    movzx bx, al
    shl bx, 1
    cmp word [piles+bx], 0
    je .ask_pile
    mov [_nim_pbx], bx

.ask_take:
    Print str_take
    call nim_read_num
    cmp ax, 0
    jle .bad_take
    cmp ax, [piles+bx]
    jg .bad_take
    mov bx, [_nim_pbx]
    sub [piles+bx], ax
    jmp .after_player
.bad_take:
    PrintLn str_bad
    jmp .ask_take

.after_player:
    call nim_total
    cmp ax, 0
    je .player_wins

    ; ---- CPU move (optimal nim-sum strategy) ----
    call nim_cpu_move
    call nim_total
    cmp ax, 0
    je .cpu_wins
    jmp .turn

.cpu_wins_check:
    jmp .turn

.player_wins:
    call nim_draw
    PrintLn str_win
    jmp .ask_again
.cpu_wins:
    call nim_draw
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
_nim_pbx: dw 0

; ---------------------------------------------------------------------------
; U0 nim_draw()
; ---------------------------------------------------------------------------
nim_draw:
    push ax
    push bx
    push cx
    ClearScreen
    Banner CYAN, str_title
    NewLine

    xor bx, bx
.ploop:
    cmp bx, 3
    jge .pdone
    Print str_pile
    mov ax, bx
    inc ax
    call print_word_dec
    Print str_colon
    mov si, bx
    shl si, 1
    mov cx, [piles+si]
.stars:
    test cx, cx
    jz .starsdone
    Print str_star
    dec cx
    jmp .stars
.starsdone:
    Print str_colon
    mov si, bx
    shl si, 1
    mov ax, [piles+si]
    call print_word_dec
    NewLine
    inc bx
    jmp .ploop
.pdone:
    NewLine
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 nim_total() -> AX = sum of all piles
; ---------------------------------------------------------------------------
nim_total:
    push bx
    xor ax, ax
    add ax, [piles+0]
    add ax, [piles+2]
    add ax, [piles+4]
    pop bx
    ret

; ---------------------------------------------------------------------------
; U0 nim_read_num() -> AX = number typed (0 on empty/invalid)
; ---------------------------------------------------------------------------
nim_read_num:
    push si
    push cx
    push dx
    ReadLine nbuf, 5
    mov si, nbuf
    xor ax, ax
.rd:
    mov dl, [si]
    test dl, dl
    jz .rdone
    cmp dl, '0'
    jb .bad
    cmp dl, '9'
    ja .bad
    mov cx, 10
    mul cx
    sub dl, '0'
    xor dh, dh
    add ax, dx
    inc si
    jmp .rd
.bad:
    xor ax, ax
.rdone:
    pop dx
    pop cx
    pop si
    ret

; ---------------------------------------------------------------------------
; U0 nim_cpu_move()  -  optimal strategy: find pile/amount that zeroes the
; nim-sum (XOR of all pile sizes); if already zero (losing position),
; just take 1 from the largest nonempty pile.
; ---------------------------------------------------------------------------
nim_cpu_move:
    push ax
    push bx
    push cx
    push dx

    mov ax, [piles+0]
    xor ax, [piles+2]
    xor ax, [piles+4]
    mov [_nim_sum], ax
    test ax, ax
    jz .fallback

    xor bx, bx                  ; pile index
.try_pile:
    cmp bx, 3
    jge .fallback
    mov si, bx
    shl si, 1
    mov cx, [piles+si]
    ; target size for this pile = pile XOR nimsum; if target < current size,
    ; taking (current-target) is the winning move
    mov ax, cx
    xor ax, [_nim_sum]
    cmp ax, cx
    jge .next_pile
    mov dx, cx
    sub dx, ax                  ; amount to take
    mov [piles+si], ax
    mov [_nim_cpile], bx
    mov [_nim_ctake], dx
    jmp .announce
.next_pile:
    inc bx
    jmp .try_pile

.fallback:
    ; take 1 from the largest nonempty pile
    xor bx, bx
    mov word [_nim_cpile], -1
    mov word [_nim_best], -1
.fb_loop:
    cmp bx, 3
    jge .fb_done
    mov si, bx
    shl si, 1
    mov ax, [piles+si]
    cmp ax, [_nim_best]
    jle .fb_next
    mov [_nim_best], ax
    mov [_nim_cpile], bx
.fb_next:
    inc bx
    jmp .fb_loop
.fb_done:
    mov bx, [_nim_cpile]
    mov si, bx
    shl si, 1
    dec word [piles+si]
    mov word [_nim_ctake], 1

.announce:
    Print str_cpu
    mov ax, [_nim_ctake]
    call print_word_dec
    Print str_from
    mov ax, [_nim_cpile]
    inc ax
    call print_word_dec
    NewLine
    GetKey

    pop dx
    pop cx
    pop bx
    pop ax
    ret
_nim_sum:   dw 0
_nim_cpile: dw 0
_nim_ctake: dw 0
_nim_best:  dw 0
