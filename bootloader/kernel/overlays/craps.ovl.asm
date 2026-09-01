; =============================================================================
; CRAPS.OVL  -  Dice game Craps  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Come-out roll: 7 or 11 wins instantly, 2/3/12 loses instantly. Any other
; total becomes "the point" - keep rolling until you hit the point again
; (win) or roll a 7 (lose).
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

U16 cr_rng,  0x4321
U16 chips,   100
U16 point,   0

STR str_title,  "CRAPS - press any key to roll the dice"
STR str_chips,  "Chips: "
STR str_roll,   "You rolled: "
STR str_plus,   " + "
STR str_eq,     " = "
STR str_natural,"Natural! You win!"
STR str_craps,  "Craps! You lose."
STR str_point,  "Point is set to "
STR str_hit,    "Point hit - you win!"
STR str_seven,  "Seven out - you lose."
STR str_broke,  "Out of chips - game over."
STR str_again,  "Roll again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    mov ah, 0x00
    int 0x1A
    mov [cr_rng], dx
    xor [cr_rng], cx

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
    GetKey

    mov word [point], 0
    call cr_roll2
    mov ax, [_cr_sum]
    cmp ax, 7
    je .natural
    cmp ax, 11
    je .natural
    cmp ax, 2
    je .craps
    cmp ax, 3
    je .craps
    cmp ax, 12
    je .craps

    mov [point], ax
    Print str_point
    call print_word_dec
    NewLine

.point_loop:
    GetKey
    call cr_roll2
    mov ax, [_cr_sum]
    cmp ax, [point]
    je .hit
    cmp ax, 7
    je .seven_out
    jmp .point_loop

.natural:
    PrintLn str_natural
    add word [chips], 10
    jmp .ask_again
.craps:
    PrintLn str_craps
    sub word [chips], 10
    jmp .ask_again
.hit:
    PrintLn str_hit
    add word [chips], 10
    jmp .ask_again
.seven_out:
    PrintLn str_seven
    sub word [chips], 10
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
; U0 cr_roll2()  -  roll two dice (1-6 each), prints them, stores sum
; ---------------------------------------------------------------------------
cr_roll2:
    push ax
    push bx
    push dx

    call cr_rand
    xor dx, dx
    mov bx, 6
    div bx
    inc dx
    mov [_cr_d1], dx

    call cr_rand
    xor dx, dx
    mov bx, 6
    div bx
    inc dx
    mov [_cr_d2], dx

    mov ax, [_cr_d1]
    add ax, [_cr_d2]
    mov [_cr_sum], ax

    Print str_roll
    mov ax, [_cr_d1]
    call print_word_dec
    Print str_plus
    mov ax, [_cr_d2]
    call print_word_dec
    Print str_eq
    mov ax, [_cr_sum]
    call print_word_dec
    NewLine

    pop dx
    pop bx
    pop ax
    ret
_cr_d1:  dw 0
_cr_d2:  dw 0
_cr_sum: dw 0

cr_rand:
    push bx
    mov ax, [cr_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [cr_rng], ax
    pop bx
    ret
