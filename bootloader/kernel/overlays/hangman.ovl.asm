; =============================================================================
; HANGMAN.OVL  -  Word guessing game  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

MAX_MISS    equ 7
WORD_MAXLEN equ 12

hm_words:
    dw hm_w0, hm_w1, hm_w2, hm_w3, hm_w4, hm_w5, hm_w6, hm_w7
NUM_WORDS equ 8
hm_w0: db "KERNEL", 0
hm_w1: db "ASSEMBLY", 0
hm_w2: db "OVERLAY", 0
hm_w3: db "COMPILER", 0
hm_w4: db "FLOPPY", 0
hm_w5: db "REALMODE", 0
hm_w6: db "BOOTLOADER", 0
hm_w7: db "PROCESSOR", 0

STRBUF hm_guessed, WORD_MAXLEN+1   ; guessed-so-far display, '_' for unknown
STRBUF hm_tried,   27              ; letters already tried this round
U16 hm_wlen, 0
U16 hm_wptr, 0
U16 hm_miss, 0
U16 hm_rng, 0x9E37

STR str_title,  "HANGMAN"
STR str_word,   "Word: "
STR str_miss,   "Wrong letters: "
STR str_left,   "Misses left: "
STR str_prompt, "Guess a letter: "
STR str_already,"Already tried that one."
STR str_win,    "You guessed it!"
STR str_lose,   "Out of guesses! The word was: "
STR str_again,  "Play again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
.new_game:
    ClearScreen
    Banner CYAN, str_title
    NewLine

    ; seed RNG
    mov ah, 0x00
    int 0x1A
    mov [hm_rng], dx
    xor [hm_rng], cx

    call hm_rand
    xor dx, dx
    mov bx, NUM_WORDS
    div bx
    mov bx, dx
    shl bx, 1
    mov ax, [hm_words + bx]
    mov [hm_wptr], ax

    ; measure length, init guessed buffer with '_'
    mov si, [hm_wptr]
    xor cx, cx
.len:
    cmp byte [si], 0
    je .lendone
    inc si
    inc cx
    jmp .len
.lendone:
    mov [hm_wlen], cx
    mov si, hm_guessed
    xor bx, bx
.fillu:
    cmp bx, cx
    jge .filldone
    mov byte [si+bx], '_'
    inc bx
    jmp .fillu
.filldone:
    mov byte [si+bx], 0

    mov word [hm_miss], 0
    mov byte [hm_tried], 0

.loop:
    call hm_draw
    Print str_prompt
    GetKey
    NewLine
    call _uc_al
    cmp al, 'A'
    jb .loop
    cmp al, 'Z'
    ja .loop

    ; already tried?
    mov si, hm_tried
.chk:
    mov ah, [si]
    test ah, ah
    jz .not_tried
    cmp ah, al
    je .tried
    inc si
    jmp .chk
.not_tried:
    mov [si], al
    mov byte [si+1], 0

    ; check word for this letter
    mov si, [hm_wptr]
    mov di, hm_guessed
    xor bx, bx
    xor cx, cx           ; cx = 1 if found
.scan:
    mov ah, [si+bx]
    test ah, ah
    jz .scandone
    cmp ah, al
    jne .scan_next
    mov [di+bx], al
    mov cx, 1
.scan_next:
    inc bx
    jmp .scan
.scandone:
    test cx, cx
    jnz .check_win
    inc word [hm_miss]
    mov ax, [hm_miss]
    cmp ax, MAX_MISS
    jge .lose
    jmp .loop

.check_win:
    mov si, hm_guessed
.wchk:
    mov al, [si]
    test al, al
    jz .win
    cmp al, '_'
    je .loop
    inc si
    jmp .wchk

.tried:
    call hm_draw
    PrintLn str_already
    GetKey
    jmp .loop

.win:
    call hm_draw
    PrintLn str_win
    jmp .ask_again
.lose:
    call hm_draw
    Print str_lose
    PrintLn [hm_wptr]
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
; U0 hm_draw()
; ---------------------------------------------------------------------------
hm_draw:
    push ax
    push si
    ClearScreen
    Banner CYAN, str_title
    NewLine

    Print str_word
    mov si, hm_guessed
    call hm_print_spaced
    NewLine
    NewLine

    Print str_miss
    mov si, hm_tried
    call vid_print
    NewLine

    Print str_left
    mov ax, MAX_MISS
    sub ax, [hm_miss]
    call print_word_dec
    NewLine
    NewLine

    call hm_draw_gallows

    pop si
    pop ax
    ret

; hm_print_spaced: print DS:SI with a space between each character
hm_print_spaced:
    push ax
.lp:
    mov al, [si]
    test al, al
    jz .done
    call vid_putchar
    mov al, ' '
    call vid_putchar
    inc si
    jmp .lp
.done:
    pop ax
    ret

; hm_draw_gallows: ASCII art scaled by [hm_miss]
hm_draw_gallows:
    push ax
    PrintLn str_g0
    mov ax, [hm_miss]
    cmp ax, 1
    jl .gd
    PrintLn str_g1
.gd:
    cmp word [hm_miss], 3
    jl .gd2
    PrintLn str_g2
.gd2:
    cmp word [hm_miss], 5
    jl .gd3
    PrintLn str_g3
.gd3:
    cmp word [hm_miss], 7
    jl .gd4
    PrintLn str_g4
.gd4:
    pop ax
    ret
STR str_g0, "  +---+"
STR str_g1, "  O   |"
STR str_g2, " /|\\  |"
STR str_g3, " / \\  |"
STR str_g4, "======="

hm_rand:
    push bx
    mov ax, [hm_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [hm_rng], ax
    pop bx
    ret
