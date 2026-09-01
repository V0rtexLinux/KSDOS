; =============================================================================
; MATRIX.OVL  -  Matrix Digital Rain demo  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
;
; Direct VGA text buffer writes (0xB800:0000) - no BIOS teletype calls in
; the animation loop, so every character gets an exact attribute byte.
; 80 independently falling columns, each with its own speed and restart
; point, tracked entirely in a small state table (no heap use).
; ESC exits back to the shell.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

MTX_COLS    equ 80
MTX_ROWS    equ 25
MTX_TRAIL   equ 9           ; visible length of a falling stream
VGA_SEG     equ 0xB800

; ---------------------------------------------------------------------------
; Per-column state (word row lets a stream start above row 0)
; ---------------------------------------------------------------------------
mtx_row:    times MTX_COLS dw 0
mtx_speed:  times MTX_COLS db 0
mtx_timer:  times MTX_COLS db 0
mtx_rng:    dw 0xACE1

STR str_banner, "MATRIX - Digital Rain  [ESC=exit]"

; ---------------------------------------------------------------------------
; U16 mtx_rand()  -  16-bit LFSR, returns AX
; ---------------------------------------------------------------------------
FN U0, mtx_rand
    push bx
    mov ax, [mtx_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [mtx_rng], ax
    pop bx
ENDFN

; ---------------------------------------------------------------------------
; U0 mtx_putc(BX=col, DX=row, AL=char, AH=attr)
; ---------------------------------------------------------------------------
FN U0, mtx_putc
    push ax
    push bx
    push cx
    push di
    push es
    mov cx, VGA_SEG
    mov es, cx
    push ax
    mov ax, dx
    mov cx, MTX_COLS * 2
    mul cx                  ; ax = row * 160
    mov di, ax
    pop ax
    shl bx, 1
    add di, bx
    mov es:[di], al
    mov es:[di+1], ah
    pop es
    pop di
    pop cx
    pop bx
    pop ax
ENDFN

; ---------------------------------------------------------------------------
; U0 mtx_reset_col(BX=col)  -  clobbers AX, CX, DX, SI
; ---------------------------------------------------------------------------
FN U0, mtx_reset_col
    call mtx_rand
    xor dx, dx
    mov cx, 18
    div cx                  ; dx = 0..17 -- stagger start above the screen
    neg dx
    mov si, bx
    shl si, 1
    mov [mtx_row + si], dx

    call mtx_rand
    and ax, 3
    inc ax                  ; speed 1..4
    mov [mtx_speed + bx], al
    mov [mtx_timer + bx], al
ENDFN

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    PUSH_ALL

    ; Seed RNG from BIOS timer tick
    mov ah, 0x00
    int 0x1A
    mov [mtx_rng], dx
    xor [mtx_rng], cx

    ; Clear to black and show the banner briefly
    call vid_clear
    Banner GREEN, str_banner

    ; Init every column
    xor bx, bx
.init_loop:
    cmp bx, MTX_COLS
    jge .init_done
    call mtx_reset_col
    inc bx
    jmp .init_loop
.init_done:

.frame:
    ; Non-blocking ESC check
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .exit

.no_key:
    xor bx, bx
.col_loop:
    cmp bx, MTX_COLS
    jge .col_done

    dec byte [mtx_timer + bx]
    jnz .col_next
    mov al, [mtx_speed + bx]
    mov [mtx_timer + bx], al

    mov si, bx
    shl si, 1
    mov dx, [mtx_row + si]

    ; Erase the tail (row - TRAIL)
    mov cx, dx
    sub cx, MTX_TRAIL
    cmp cx, 0
    jl .no_erase
    cmp cx, MTX_ROWS
    jge .no_erase
    push dx
    mov dx, cx
    mov al, ' '
    mov ah, 0x00
    call mtx_putc
    pop dx
.no_erase:

    ; Dim the previous head (row - 1) to plain green
    mov cx, dx
    dec cx
    cmp cx, 0
    jl .no_dim
    cmp cx, MTX_ROWS
    jge .no_dim
    push dx
    call mtx_rand
    and al, 0x3F
    add al, 0x30
    mov ah, 0x02            ; green on black
    mov dx, cx
    call mtx_putc
    pop dx
.no_dim:

    ; Draw the bright leading character (row)
    cmp dx, 0
    jl .no_head
    cmp dx, MTX_ROWS
    jge .no_head
    push dx
    call mtx_rand
    and al, 0x3F
    add al, 0x30
    mov ah, 0x0F             ; bright white leading glyph
    call mtx_putc
    pop dx
.no_head:

    inc dx
    mov si, bx
    shl si, 1
    mov [mtx_row + si], dx
    mov cx, dx
    sub cx, MTX_TRAIL
    cmp cx, MTX_ROWS
    jl .col_next
    call mtx_reset_col

.col_next:
    inc bx
    jmp .col_loop
.col_done:

    ; Small delay so the animation is readable
    push cx
    mov cx, 0x0300
.delay:
    loop .delay
    pop cx

    jmp .frame

.exit:
    call vid_clear
    POP_ALL
ENDFN
