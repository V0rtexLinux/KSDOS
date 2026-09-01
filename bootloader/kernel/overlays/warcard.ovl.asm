; =============================================================================
; WARCARD.OVL  -  The card game War, vs CPU  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Each round both sides draw a card (1=Ace low .. 13=King); higher wins a
; point. Ties trigger a "War": both re-draw, the new higher card wins.
; First to WIN_TARGET points wins the match.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

WIN_TARGET equ 10

U16 wc_rng,  0x7777
U16 p_score, 0
U16 c_score, 0

STR str_title,  "WAR - press any key to draw  (first to 10 wins)"
STR str_you,    "You: "
STR str_cpu,    "CPU: "
STR str_you_win,"You win the round!"
STR str_cpu_win,"CPU wins the round!"
STR str_tie,    "WAR! Both draw again..."
STR str_score,  "Score  You: "
STR str_score2, "  CPU: "
STR str_match_win, "*** You win the match! ***"
STR str_match_lose,"*** CPU wins the match! ***"
STR str_again,  "Play again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    mov ah, 0x00
    int 0x1A
    mov [wc_rng], dx
    xor [wc_rng], cx

.new_game:
    mov word [p_score], 0
    mov word [c_score], 0

.round:
    ClearScreen
    Banner CYAN, str_title
    NewLine
    Print str_score
    mov ax, [p_score]
    call print_word_dec
    Print str_score2
    mov ax, [c_score]
    call print_word_dec
    NewLine
    NewLine
    GetKey

.draw:
    call wc_rand
    xor dx, dx
    mov bx, 13
    div bx
    inc dx
    mov [_wc_pc], dx

    call wc_rand
    xor dx, dx
    mov bx, 13
    div bx
    inc dx
    mov [_wc_cc], dx

    Print str_you
    mov ax, [_wc_pc]
    call print_word_dec
    Print str_cpu
    mov ax, [_wc_cc]
    call print_word_dec
    NewLine

    mov ax, [_wc_pc]
    mov bx, [_wc_cc]
    cmp ax, bx
    je .war
    jg .p_wins
    jmp .c_wins

.war:
    PrintLn str_tie
    GetKey
    jmp .draw

.p_wins:
    PrintLn str_you_win
    inc word [p_score]
    jmp .after
.c_wins:
    PrintLn str_cpu_win
    inc word [c_score]
.after:
    mov ax, [p_score]
    cmp ax, WIN_TARGET
    jge .match_p_win
    mov ax, [c_score]
    cmp ax, WIN_TARGET
    jge .match_c_win
    jmp .round

.match_p_win:
    Banner LTGREEN, str_match_win
    jmp .ask_again
.match_c_win:
    Banner LTRED, str_match_lose
.ask_again:
    Print str_again
    GetKey
    NewLine
    cmp al, 'y'
    je .new_game
    cmp al, 'Y'
    je .new_game
ENDFN
_wc_pc: dw 0
_wc_cc: dw 0

wc_rand:
    push bx
    mov ax, [wc_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [wc_rng], ax
    pop bx
    ret
