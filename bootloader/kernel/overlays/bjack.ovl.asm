; =============================================================================
; BJACK.OVL  -  Blackjack vs the house  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Standard rules: dealer hits until 17+, aces count as 11 or 1.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

U16 bj_rng,     0x1D2F
U16 p_total,    0
U16 p_aces,     0
U16 d_total,    0
U16 d_aces,     0
U16 chips,      100

STR str_title,  "BLACKJACK - H=hit  S=stand"
STR str_chips,  "Chips: "
STR str_bet,    "Bet: "
STR str_yours,  "Your hand total: "
STR str_dealer, "Dealer shows: "
STR str_dfinal, "Dealer's final total: "
STR str_card,   "Drew: "
STR str_bust,   "BUST!"
STR str_win,    "You win!"
STR str_lose,   "You lose."
STR str_push,   "Push (tie)."
STR str_broke,  "Out of chips - game over."
STR str_again,  "Play again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    mov ah, 0x00
    int 0x1A
    mov [bj_rng], dx
    xor [bj_rng], cx

.new_round:
    cmp word [chips], 0
    jle .broke

    ClearScreen
    Banner CYAN, str_title
    Print str_chips
    mov ax, [chips]
    call print_word_dec
    NewLine
    NewLine

    mov word [p_total], 0
    mov word [p_aces], 0
    mov word [d_total], 0
    mov word [d_aces], 0

    call bj_draw
    call bj_add_player
    call bj_draw
    call bj_add_player
    call bj_draw
    call bj_add_dealer

    Print str_dealer
    mov ax, [d_total]
    call print_word_dec
    NewLine

.player_loop:
    Print str_yours
    mov ax, [p_total]
    call print_word_dec
    NewLine
    cmp word [p_total], 21
    jge .player_done

    GetKey
    call _uc_al
    NewLine
    cmp al, 'H'
    je .hit
    cmp al, 'S'
    je .player_done
    jmp .player_loop
.hit:
    call bj_draw
    Print str_card
    mov ax, [_bj_card]
    call print_word_dec
    NewLine
    call bj_add_player
    cmp word [p_total], 21
    jg .bust
    jmp .player_loop

.bust:
    PrintLn str_bust
    sub word [chips], 10
    jmp .ask_again

.player_done:
    ; dealer plays
.dealer_loop:
    mov ax, [d_total]
    cmp ax, 17
    jge .dealer_done
    call bj_draw
    call bj_add_dealer
    jmp .dealer_loop
.dealer_done:
    Print str_dfinal
    mov ax, [d_total]
    call print_word_dec
    NewLine

    cmp word [d_total], 21
    jg .player_wins        ; dealer busts

    mov ax, [p_total]
    mov bx, [d_total]
    cmp ax, bx
    jg .player_wins
    je .tie
    jmp .dealer_wins

.player_wins:
    PrintLn str_win
    add word [chips], 10
    jmp .ask_again
.dealer_wins:
    PrintLn str_lose
    sub word [chips], 10
    jmp .ask_again
.tie:
    PrintLn str_push

.ask_again:
    Print str_again
    GetKey
    NewLine
    cmp al, 'y'
    je .new_round
    cmp al, 'Y'
    je .new_round
    jmp .done
.broke:
    PrintLn str_broke
    GetKey
.done:
ENDFN

; ---------------------------------------------------------------------------
; U0 bj_draw()  -  draw a card value 1-13 into _bj_card
; ---------------------------------------------------------------------------
bj_draw:
    push ax
    push bx
    push dx
    call bj_rand
    xor dx, dx
    mov bx, 13
    div bx
    inc dx
    mov [_bj_card], dx
    pop dx
    pop bx
    pop ax
    ret
_bj_card: dw 0

; ---------------------------------------------------------------------------
; U0 bj_add_player()  -  add _bj_card to player's total, ace-aware
; ---------------------------------------------------------------------------
bj_add_player:
    push ax
    call bj_card_value
    add [p_total], ax
    cmp word [_bj_is_ace], 0
    je .no_ace
    inc word [p_aces]
.no_ace:
.soften:
    mov ax, [p_total]
    cmp ax, 21
    jle .done
    cmp word [p_aces], 0
    je .done
    sub word [p_total], 10
    dec word [p_aces]
    jmp .soften
.done:
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 bj_add_dealer()  -  same as above, for the dealer
; ---------------------------------------------------------------------------
bj_add_dealer:
    push ax
    call bj_card_value
    add [d_total], ax
    cmp word [_bj_is_ace], 0
    je .no_ace
    inc word [d_aces]
.no_ace:
.soften:
    mov ax, [d_total]
    cmp ax, 21
    jle .done
    cmp word [d_aces], 0
    je .done
    sub word [d_total], 10
    dec word [d_aces]
    jmp .soften
.done:
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 bj_card_value()  -  from _bj_card (1-13) -> AX = blackjack value,
; sets _bj_is_ace
; ---------------------------------------------------------------------------
bj_card_value:
    mov word [_bj_is_ace], 0
    mov ax, [_bj_card]
    cmp ax, 1
    jne .not_ace
    mov word [_bj_is_ace], 1
    mov ax, 11
    ret
.not_ace:
    cmp ax, 10
    jle .ret
    mov ax, 10
.ret:
    ret
_bj_is_ace: dw 0

bj_rand:
    push bx
    mov ax, [bj_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [bj_rng], ax
    pop bx
    ret
