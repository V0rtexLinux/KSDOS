; =============================================================================
; MASTER.OVL  -  Mastermind code-breaking game  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Secret is 4 digits, each 1-6. Guess it in 10 tries. B=right digit+spot,
; W=right digit wrong spot.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

CODE_LEN  equ 4
NUM_COLORS equ 6
MAX_TRIES equ 10

STRBUF secret, CODE_LEN
STRBUF guess,  CODE_LEN
STRBUF fg,     NUM_COLORS+1     ; frequency of guess digits
STRBUF frs,     NUM_COLORS+1     ; frequency of secret digits
U16 mm_rng, 0xBEEF
U16 mm_try, 0

STR str_title,  "MASTERMIND - guess the 4-digit code (1-6)"
STR str_hint,   "B=right digit+spot  W=right digit, wrong spot"
STR str_try,    "Try "
STR str_of,     "/10: "
STR str_result, "  -> "
STR str_bblack, "B"
STR str_wwhite, "W"
STR str_win,    "Cracked it!"
STR str_lose,   "Out of tries. The code was: "
STR str_bad,    "Enter exactly 4 digits, each 1-6."
STR str_again,  "Play again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
.new_game:
    ClearScreen
    Banner CYAN, str_title
    PrintLn str_hint
    NewLine

    mov ah, 0x00
    int 0x1A
    mov [mm_rng], dx
    xor [mm_rng], cx

    mov si, secret
    mov cx, CODE_LEN
.mksecret:
    call mm_rand
    xor dx, dx
    mov bx, NUM_COLORS
    div bx
    inc dx
    mov [si], dl
    inc si
    loop .mksecret

    mov word [mm_try], 0

.loop:
    inc word [mm_try]
    mov ax, [mm_try]
    cmp ax, MAX_TRIES
    jg .lose

    Print str_try
    call print_word_dec
    Print str_of

.ask:
    ReadLine _mm_line, 8
    mov si, _mm_line
    mov di, guess
    xor cx, cx
.parse:
    cmp cx, CODE_LEN
    jge .parse_done
    mov al, [si]
    test al, al
    jz .badinput
    cmp al, '1'
    jb .badinput
    cmp al, '6'
    ja .badinput
    sub al, '0'
    mov [di], al
    inc di
    inc si
    inc cx
    jmp .parse
.parse_done:

    call mm_score
    mov cx, ax               ; black count
    mov dx, bx                ; white count
    Print str_result
.pb:
    test cx, cx
    jz .pw
    Print str_bblack
    dec cx
    jmp .pb
.pw:
    test dx, dx
    jz .pdone
    Print str_wwhite
    dec dx
    jmp .pw
.pdone:
    NewLine

    ; check win: black == CODE_LEN
    mov ax, [_mm_lastb]
    cmp ax, CODE_LEN
    je .win
    jmp .loop

.badinput:
    PrintLn str_bad
    jmp .ask

.win:
    Banner LTGREEN, str_win
    jmp .ask_again
.lose:
    Print str_lose
    mov si, secret
    mov cx, CODE_LEN
.showsecret:
    mov al, [si]
    xor ah, ah
    push cx
    push si
    call print_word_dec
    pop si
    pop cx
    inc si
    loop .showsecret
    NewLine
.ask_again:
    Print str_again
    GetKey
    NewLine
    cmp al, 'y'
    je .new_game
    cmp al, 'Y'
    je .new_game
ENDFN
STRBUF _mm_line, 8

; ---------------------------------------------------------------------------
; U0 mm_score() -> AX=black count, BX=white count (also stores AX in
; _mm_lastb for the caller's win check)
; ---------------------------------------------------------------------------
mm_score:
    push cx
    push dx
    push si
    push di

    mov si, fg
    mov cx, NUM_COLORS+1
    xor al, al
.clr1:
    mov [si], al
    inc si
    loop .clr1
    mov si, frs
    mov cx, NUM_COLORS+1
    xor al, al
.clr2:
    mov [si], al
    inc si
    loop .clr2

    xor bx, bx               ; black count
    xor dx, dx               ; loop index 0..3
.bloop:
    cmp dx, CODE_LEN
    jge .bdone
    mov si, dx
    mov al, [guess + si]
    mov ah, [secret + si]
    cmp al, ah
    jne .not_black
    inc bx
    jmp .bnext
.not_black:
    ; tally frequency for non-matching positions
    movzx si, al
    inc byte [fg + si]
    movzx si, ah
    inc byte [frs + si]
.bnext:
    inc dx
    jmp .bloop
.bdone:
    mov [_mm_lastb], bx

    ; white = sum over colors of min(fg[c],frs[c])
    xor dx, dx               ; white total
    mov si, 1
.wloop:
    cmp si, NUM_COLORS
    jg .wdone
    movzx ax, byte [fg + si]
    movzx cx, byte [frs + si]
    cmp ax, cx
    jle .use_ax
    mov ax, cx
.use_ax:
    add dx, ax
    inc si
    jmp .wloop
.wdone:
    mov bx, dx
    mov ax, [_mm_lastb]

    pop di
    pop si
    pop dx
    pop cx
    ret
_mm_lastb: dw 0

mm_rand:
    push bx
    mov ax, [mm_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [mm_rng], ax
    pop bx
    ret
