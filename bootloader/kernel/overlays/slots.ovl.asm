; =============================================================================
; SLOTS.OVL  -  Slot machine  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Three reels, six symbols. Match 3 = jackpot, match 2 = small win.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

NUM_SYMBOLS equ 6
STRBUF reel, 3

sym_names:
    dw sym0, sym1, sym2, sym3, sym4, sym5
sym0: db " CHERRY ", 0
sym1: db "  BELL  ", 0
sym2: db "  BAR   ", 0
sym3: db " LEMON  ", 0
sym4: db "  STAR  ", 0
sym5: db " SEVEN  ", 0

U16 sl_rng,  0xF00D
U16 chips,   100

STR str_title,  "SLOT MACHINE - SPACE to spin (10 chips/spin), ESC to quit"
STR str_chips,  "Chips: "
STR str_bar,    "+--------+--------+--------+"
STR str_pipe,   "|"
STR str_jackpot,"*** JACKPOT! +100 ***"
STR str_pair,   "Pair! +20"
STR str_nowin,  "No match."
STR str_broke,  "Out of chips - game over."

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    mov ah, 0x00
    int 0x1A
    mov [sl_rng], dx
    xor [sl_rng], cx

.loop:
    cmp word [chips], 0
    jle .broke
    ClearScreen
    Banner CYAN, str_title
    Print str_chips
    mov ax, [chips]
    call print_word_dec
    NewLine
    NewLine
    call sl_draw_reels

    GetKey
    cmp al, 27
    je .done
    cmp al, ' '
    jne .loop

    sub word [chips], 10
    mov si, reel
    mov cx, 3
.spin:
    call sl_rand
    xor dx, dx
    mov bx, NUM_SYMBOLS
    div bx
    mov [si], dl
    inc si
    loop .spin

    ClearScreen
    Banner CYAN, str_title
    Print str_chips
    mov ax, [chips]
    call print_word_dec
    NewLine
    NewLine
    call sl_draw_reels

    movzx ax, byte [reel+0]
    movzx bx, byte [reel+1]
    movzx cx, byte [reel+2]
    cmp ax, bx
    jne .not_all
    cmp bx, cx
    jne .not_all
    PrintLn str_jackpot
    add word [chips], 100
    jmp .after
.not_all:
    cmp ax, bx
    je .pair
    cmp bx, cx
    je .pair
    cmp ax, cx
    je .pair
    PrintLn str_nowin
    jmp .after
.pair:
    PrintLn str_pair
    add word [chips], 20
.after:
    GetKey
    jmp .loop

.broke:
    PrintLn str_broke
    GetKey
.done:
ENDFN

; ---------------------------------------------------------------------------
; U0 sl_draw_reels()
; ---------------------------------------------------------------------------
sl_draw_reels:
    push ax
    push bx
    push si
    PrintLn str_bar
    Print str_pipe
    xor bx, bx
.rl:
    cmp bx, 3
    jge .rldone
    movzx ax, byte [reel+bx]
    shl ax, 1
    mov si, ax
    mov si, [sym_names + si]
    Print si
    Print str_pipe
    inc bx
    jmp .rl
.rldone:
    NewLine
    PrintLn str_bar
    NewLine
    pop si
    pop bx
    pop ax
    ret

sl_rand:
    push bx
    mov ax, [sl_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [sl_rng], ax
    pop bx
    ret
