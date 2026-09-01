; =============================================================================
; WORDLE.OVL  -  5-letter word guessing game  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; 6 guesses. Green = right letter/spot, Yellow = right letter/wrong spot,
; Gray = not in the word. Handles duplicate letters like the original.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

WLEN     equ 5
MAX_GUESS equ 6
NUM_WORDS equ 10

wl_words:
    dw ww0, ww1, ww2, ww3, ww4, ww5, ww6, ww7, ww8, ww9
ww0: db "KRNEL", 0        ; padded/stylised 5-letter tech words
ww1: db "DISKS", 0
ww2: db "BOOTS", 0
ww3: db "SHELL", 0
ww4: db "FLOPY", 0
ww5: db "STACK", 0
ww6: db "TRACE", 0
ww7: db "VIDEO", 0
ww8: db "MOUSE", 0
ww9: db "CACHE", 0

STRBUF secret,   WLEN
STRBUF secfreq,  27      ; remaining letter-frequency scratch (A-Z)
STRBUF guess,    8
STRBUF result,   WLEN    ; 0=gray 1=yellow 2=green
U16 wl_rng, 0x1357
U16 wl_try, 0

STR str_title,  "WORDLE - guess the 5-letter word (6 tries)"
STR str_hint,   "Green=right spot  Yellow=in word  Gray=not in word"
STR str_prompt, "Guess: "
STR str_bad,    "Enter exactly 5 letters."
STR str_win,    "You got it!"
STR str_lose,   "Out of guesses. The word was: "
STR str_again,  "Play again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    mov ah, 0x00
    int 0x1A
    mov [wl_rng], dx
    xor [wl_rng], cx

.new_game:
    ClearScreen
    mov dh, 0
    mov dl, 0
    call vid_set_cursor
    SetColor 0x1F
    PrintLn str_title
    SetColor 0x07
    PrintLn str_hint
    NewLine

    call wl_rand
    xor dx, dx
    mov bx, NUM_WORDS
    div bx
    mov bx, dx
    shl bx, 1
    mov ax, [wl_words + bx]
    mov [_wl_wptr], ax
    mov si, ax
    mov di, secret
    mov cx, WLEN
    rep movsb

    mov word [wl_try], 0

.loop:
    inc word [wl_try]
    mov ax, [wl_try]
    cmp ax, MAX_GUESS
    jg .lose

.ask:
    Print str_prompt
    ReadLine guess, 7
    call _uc_str
    mov si, guess
    xor cx, cx
.lenchk:
    cmp byte [si], 0
    je .lenchkdone
    inc si
    inc cx
    jmp .lenchk
.lenchkdone:
    cmp cx, WLEN
    jne .badinput

    call wl_score
    NewLine
    NewLine

    ; win if all 5 results are green(2)
    mov si, result
    xor bx, bx
.wchk:
    cmp bx, WLEN
    jge .win
    cmp byte [si+bx], 2
    jne .loop
    inc bx
    jmp .wchk

.badinput:
    PrintLn str_bad
    jmp .ask

.win:
    Banner LTGREEN, str_win
    jmp .ask_again
.lose:
    Print str_lose
    PrintLn secret
.ask_again:
    Print str_again
    GetKey
    NewLine
    cmp al, 'y'
    je .new_game
    cmp al, 'Y'
    je .new_game
ENDFN
_wl_wptr: dw 0

; ---------------------------------------------------------------------------
; U0 _uc_str()  -  uppercase DS:SI in place
; ---------------------------------------------------------------------------
_uc_str:
    push ax
    push si
    mov si, guess
.lp:
    mov al, [si]
    test al, al
    jz .done
    cmp al, 'a'
    jb .next
    cmp al, 'z'
    ja .next
    sub al, 32
    mov [si], al
.next:
    inc si
    jmp .lp
.done:
    pop si
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 wl_score()  -  compares `guess` against `secret`, fills `result`,
; and prints the guess coloured by the result.
; ---------------------------------------------------------------------------
wl_score:
    push ax
    push bx
    push cx
    push si
    push di

    ; init letter-frequency scratch to 0
    mov si, secfreq
    mov cx, 26
    xor al, al
.clr:
    mov [si], al
    inc si
    loop .clr

    ; pass 1: mark greens, tally remaining (non-green) secret letters
    xor bx, bx
.p1:
    cmp bx, WLEN
    jge .p1done
    mov al, [guess + bx]
    mov ah, [secret + bx]
    cmp al, ah
    jne .not_green
    mov byte [result + bx], 2
    jmp .p1next
.not_green:
    mov byte [result + bx], 0
    movzx si, ah
    sub si, 'A'
    inc byte [secfreq + si]
.p1next:
    inc bx
    jmp .p1

.p1done:
    ; pass 2: for non-green cells, check remaining frequency for yellow
    xor bx, bx
.p2:
    cmp bx, WLEN
    jge .p2done
    cmp byte [result + bx], 2
    je .p2next
    mov al, [guess + bx]
    movzx si, al
    sub si, 'A'
    cmp si, 26
    jae .p2next            ; non-letter guard
    cmp byte [secfreq + si], 0
    je .p2next
    mov byte [result + bx], 1
    dec byte [secfreq + si]
.p2next:
    inc bx
    jmp .p2
.p2done:

    ; print the guess, coloured per result[]
    xor bx, bx
.pr:
    cmp bx, WLEN
    jge .prdone
    mov al, [result + bx]
    cmp al, 2
    je .grn
    cmp al, 1
    je .yel
    SetColor 0x78          ; gray on gray-ish (dark grey bg, light grey fg)
    jmp .prput
.grn:
    SetColor 0x2F
    jmp .prput
.yel:
    SetColor 0x6F
.prput:
    mov al, [guess + bx]
    call vid_putchar
    inc bx
    jmp .pr
.prdone:
    SetColor 0x07

    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

wl_rand:
    push bx
    mov ax, [wl_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [wl_rng], ax
    pop bx
    ret
