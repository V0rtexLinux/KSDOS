; =============================================================================
; CHECKERS.OVL  -  Checkers/Draughts vs CPU  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; 8x8 board, dark squares only. You are Red (r/R=king), CPU is Black
; (b/B=king). Diagonal moves; jump an adjacent enemy onto the empty square
; beyond to capture it. Reaching the far row crowns a king (moves either
; diagonal direction). Captures are optional (not forced), single jumps
; only (no multi-jump chaining) - a legitimate simplified ruleset.
; Enter moves as two coords: from then to (e.g. "B3" then "C4").
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

N        equ 8
EMPTY    equ 0
PC_RED   equ 1
PC_REDK  equ 2
PC_BLK   equ 3
PC_BLKK  equ 4

STRBUF board, N*N

STR str_title,  "CHECKERS - you are r (Red), CPU is b (Black)"
STR str_from,   "Move from: "
STR str_to,     "       to: "
STR str_bad,    "Illegal move."
STR str_cpu,    "CPU moves "
STR str_arrow,  " -> "
STR str_win,    "You win - all Black pieces captured!"
STR str_lose,   "CPU wins - all Red pieces captured!"
STR str_colhdr, "  A B C D E F G H"
STR str_again,  "Play again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    mov ah, 0x00
    int 0x1A
    mov [ck_rng], dx
    xor [ck_rng], cx

.new_game:
    call ck_setup_board

.turn:
    call ck_draw
    call ck_count
    cmp bx, 0
    je .win
    cmp ax, 0
    je .lose

    call ck_player_move
    call ck_draw
    call ck_count
    cmp bx, 0
    je .win

    call ck_cpu_move
    call ck_count
    cmp ax, 0
    je .lose
    jmp .turn

.win:
    call ck_draw
    Banner LTGREEN, str_win
    jmp .ask_again
.lose:
    call ck_draw
    Banner LTRED, str_lose
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
; U0 ck_setup_board()
; ---------------------------------------------------------------------------
ck_setup_board:
    push ax
    push bx
    push cx
    push si
    mov si, board
    mov cx, N*N
    xor al, al
.clr:
    mov [si], al
    inc si
    loop .clr

    ; Black on rows 0-2, Red on rows 5-7, dark squares only
    ; dark square when (row+col) is odd
    xor bx, bx
.row_setup:
    cmp bx, N
    jge .setup_done
    xor cx, cx
.col_setup:
    cmp cx, N
    jge .row_next
    mov ax, bx
    add ax, cx
    test ax, 1
    jz .col_next            ; light square, leave empty
    cmp bx, 3
    jle .maybe_black
    cmp bx, 4
    jge .maybe_red
    jmp .col_next
.maybe_black:
    call ck_addr
    mov byte [si], PC_BLK
    jmp .col_next
.maybe_red:
    call ck_addr
    mov byte [si], PC_RED
.col_next:
    inc cx
    jmp .col_setup
.row_next:
    inc bx
    jmp .row_setup
.setup_done:
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ck_addr: BX=row, CX=col -> SI = board address
ck_addr:
    push ax
    push dx
    mov ax, bx
    mov dx, N
    imul dx
    add ax, cx
    mov si, ax
    add si, board
    pop dx
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 ck_player_move()  -  prompt for from/to, validate, apply
; ---------------------------------------------------------------------------
ck_player_move:
.ask:
    Print str_from
    call ck_read_coord
    cmp ax, 0
    je .ask
    mov [_ck_fr], bx
    mov [_ck_fc], cx

    Print str_to
    call ck_read_coord
    cmp ax, 0
    je .ask
    mov [_ck_tr], bx
    mov [_ck_tc], cx

    call ck_try_move
    cmp ax, 0
    je .illegal
    ret
.illegal:
    call ck_draw
    PrintLn str_bad
    jmp .ask

; ck_read_coord: reads "A1".."H8" -> AX=1 valid (BX=row,CX=col) or AX=0
ck_read_coord:
    push dx
    GetKey
    call _uc_al
    NewLine
    cmp al, 'A'
    jb .bad
    cmp al, 'H'
    ja .bad
    sub al, 'A'
    movzx cx, al
    GetKey
    NewLine
    cmp al, '1'
    jb .bad
    cmp al, '8'
    ja .bad
    sub al, '1'
    movzx bx, al
    mov ax, 1
    jmp .rcdone
.bad:
    xor ax, ax
.rcdone:
    pop dx
    ret
_ck_fr: dw 0
_ck_fc: dw 0
_ck_tr: dw 0
_ck_tc: dw 0

; ---------------------------------------------------------------------------
; U0 ck_try_move()  -  uses _ck_fr/_ck_fc/_ck_tr/_ck_tc.
; Returns AX=1 if the move was legal and applied (for the RED side).
; ---------------------------------------------------------------------------
ck_try_move:
    push bx
    push cx
    push dx
    push si
    push di

    mov bx, [_ck_fr]
    mov cx, [_ck_fc]
    call ck_addr
    mov al, [si]
    cmp al, PC_RED
    je .is_red
    cmp al, PC_REDK
    je .is_red
    jmp .illegal
.is_red:
    mov [_ck_piece], al

    mov bx, [_ck_tr]
    mov cx, [_ck_tc]
    call ck_addr
    cmp byte [si], EMPTY
    jne .illegal
    mov [_ck_toaddr], si

    ; row/col deltas
    mov ax, [_ck_tr]
    sub ax, [_ck_fr]
    mov [_ck_drow], ax
    mov ax, [_ck_tc]
    sub ax, [_ck_fc]
    mov [_ck_dcol], ax

    ; must move diagonally: |drow| == |dcol|, and == 1 (step) or == 2 (jump)
    mov ax, [_ck_drow]
    call ck_abs
    mov bx, ax
    mov ax, [_ck_dcol]
    call ck_abs
    cmp ax, bx
    jne .illegal
    cmp ax, 1
    je .is_step
    cmp ax, 2
    je .is_jump
    jmp .illegal

.is_step:
    ; non-kings may only move "forward" (red decreases row, black increases)
    cmp byte [_ck_piece], PC_RED
    jne .step_ok
    cmp word [_ck_drow], 0
    jl .step_ok
    jmp .illegal
.step_ok:
    call ck_apply_move
    mov ax, 1
    jmp .tmdone

.is_jump:
    cmp byte [_ck_piece], PC_RED
    jne .jump_ok
    cmp word [_ck_drow], 0
    jl .jump_ok
    jmp .illegal
.jump_ok:
    ; middle square must hold an enemy (black) piece
    ; midpoint = from + delta/2 (delta is always +-2 here)
    mov ax, [_ck_drow]
    sar ax, 1
    add ax, [_ck_fr]
    mov bx, ax
    mov ax, [_ck_dcol]
    sar ax, 1
    add ax, [_ck_fc]
    mov cx, ax
    call ck_addr
    mov al, [si]
    cmp al, PC_BLK
    je .have_enemy
    cmp al, PC_BLKK
    je .have_enemy
    jmp .illegal
.have_enemy:
    mov byte [si], EMPTY        ; remove captured piece
    call ck_apply_move
    mov ax, 1
    jmp .tmdone

.illegal:
    xor ax, ax
.tmdone:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
_ck_piece:  db 0
_ck_toaddr: dw 0
_ck_drow:   dw 0
_ck_dcol:   dw 0

; ck_apply_move: move _ck_piece from (from) to (_ck_toaddr), crown if needed
ck_apply_move:
    push ax
    push bx
    push cx
    push si
    mov bx, [_ck_fr]
    mov cx, [_ck_fc]
    call ck_addr
    mov byte [si], EMPTY

    mov al, [_ck_piece]
    ; crown check
    cmp al, PC_RED
    jne .not_redcrown
    cmp word [_ck_tr], 0
    jne .place
    mov al, PC_REDK
    jmp .place
.not_redcrown:
    cmp al, PC_BLK
    jne .place
    cmp word [_ck_tr], N-1
    jne .place
    mov al, PC_BLKK
.place:
    mov si, [_ck_toaddr]
    mov [si], al
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ck_abs: AX = |AX|
ck_abs:
    cmp ax, 0
    jge .abs_ok
    neg ax
.abs_ok:
    ret

; ---------------------------------------------------------------------------
; U0 ck_cpu_move()  -  greedy: prefer any legal jump (capture), else a
; random legal step. Scans all Black pieces.
; ---------------------------------------------------------------------------
ck_cpu_move:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; pass 1: look for any legal jump
    mov word [_cm_have_step], 0
    xor bx, bx
.scan1:
    cmp bx, N
    jge .pass1done
    xor cx, cx
.scan1c:
    cmp cx, N
    jge .scan1next
    call ck_addr
    mov al, [si]
    cmp al, PC_BLK
    je .p1_check
    cmp al, PC_BLKK
    jne .scan1cnext
.p1_check:
    call ck_try_black_jumps      ; tries all 4 jump dirs from (bx,cx)
    cmp ax, 1
    je .p1done
.scan1cnext:
    inc cx
    jmp .scan1c
.scan1next:
    inc bx
    jmp .scan1
.pass1done:
    jmp .try_steps
.p1done:
    jmp .cmdone

.try_steps:
    ; pass 2: collect all legal single steps, pick one at random
    mov word [_cm_nsteps], 0
    xor bx, bx
.scan2:
    cmp bx, N
    jge .scan2done
    xor cx, cx
.scan2c:
    cmp cx, N
    jge .scan2next
    call ck_addr
    mov al, [si]
    cmp al, PC_BLK
    je .p2_check
    cmp al, PC_BLKK
    jne .scan2cnext
.p2_check:
    call ck_collect_black_steps
.scan2cnext:
    inc cx
    jmp .scan2c
.scan2next:
    inc bx
    jmp .scan2
.scan2done:
    cmp word [_cm_nsteps], 0
    je .cmdone
    call ck_rand
    xor dx, dx
    mov bx, [_cm_nsteps]
    div bx
    mov bx, dx
    shl bx, 3                    ; 4 words per record
    mov ax, [_cm_steps + bx]
    mov [_ck_fr], ax
    mov ax, [_cm_steps + bx + 2]
    mov [_ck_fc], ax
    mov ax, [_cm_steps + bx + 4]
    mov [_ck_tr], ax
    mov ax, [_cm_steps + bx + 6]
    mov [_ck_tc], ax
    call ck_apply_black_move

.cmdone:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
_cm_have_step: dw 0
_cm_nsteps:    dw 0
_cm_steps:     times 4*4 dw 0   ; up to 4 candidate steps, 4 words each

; ck_try_black_jumps: BX=row,CX=col of a black piece; tries all 4 diagonal
; jump directions, applies + announces the first legal one found.
; Returns AX=1 if a jump was made.
ck_try_black_jumps:
    push bx
    push cx
    push dx
    push si
    mov [_ck_fr], bx
    mov [_ck_fc], cx

    mov dx, 0
.dirloop:
    cmp dx, 4
    jge .none
    call ck_black_jump_dir       ; dx=direction index -> sets _ck_tr/_ck_tc
    cmp ax, 0
    jne .found
    inc dx
    jmp .dirloop
.found:
    call ck_apply_black_move
    mov ax, 1
    jmp .tbjdone
.none:
    xor ax, ax
.tbjdone:
    pop si
    pop dx
    pop cx
    pop bx
    ret

; ck_black_jump_dir: DX=0..3 direction; uses _ck_fr/_ck_fc; if a jump in
; that direction is legal, sets _ck_tr/_ck_tc, removes the captured piece,
; returns AX=1; else AX=0, board unchanged.
ck_black_jump_dir:
    push bx
    push cx
    push si
    mov ax, dx
    call ck_dir_delta            ; -> _ck_ddr,_ck_ddc = -1/1,-1/1

    mov ax, [_ck_fr]
    add ax, [_ck_ddr]
    add ax, [_ck_ddr]
    cmp ax, 0
    jl .no
    cmp ax, N
    jge .no
    mov bx, ax
    mov ax, [_ck_fc]
    add ax, [_ck_ddc]
    add ax, [_ck_ddc]
    cmp ax, 0
    jl .no
    cmp ax, N
    jge .no
    mov cx, ax
    push bx
    push cx
    call ck_addr
    cmp byte [si], EMPTY
    jne .no_pop
    ; middle square must hold a red piece
    mov bx, [_ck_fr]
    add bx, [_ck_ddr]
    mov cx, [_ck_fc]
    add cx, [_ck_ddc]
    call ck_addr
    mov al, [si]
    cmp al, PC_RED
    je .have_red
    cmp al, PC_REDK
    jne .no_pop
.have_red:
    mov byte [si], EMPTY
    pop cx
    pop bx
    mov [_ck_tr], bx
    mov [_ck_tc], cx
    mov ax, 1
    jmp .bjddone
.no_pop:
    pop cx
    pop bx
.no:
    xor ax, ax
.bjddone:
    pop si
    pop cx
    pop bx
    ret
_ck_ddr: dw 0
_ck_ddc: dw 0

; ck_dir_delta: AX=0..3 -> sets _ck_ddr,_ck_ddc to (-1,-1)/(-1,1)/(1,-1)/(1,1)
ck_dir_delta:
    cmp ax, 0
    jne .d1
    mov word [_ck_ddr], -1
    mov word [_ck_ddc], -1
    ret
.d1:
    cmp ax, 1
    jne .d2
    mov word [_ck_ddr], -1
    mov word [_ck_ddc], 1
    ret
.d2:
    cmp ax, 2
    jne .d3
    mov word [_ck_ddr], 1
    mov word [_ck_ddc], -1
    ret
.d3:
    mov word [_ck_ddr], 1
    mov word [_ck_ddc], 1
    ret

; ck_collect_black_steps: BX=row,CX=col of a black piece; appends any
; legal single diagonal steps (into _cm_steps) - forward only unless king.
ck_collect_black_steps:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov [_ck_fr], bx
    mov [_ck_fc], cx
    call ck_addr
    mov al, [si]

    mov dx, 0
.dloop:
    cmp dx, 4
    jge .csdone
    cmp al, PC_BLK
    jne .try_dir
    ; non-king black only moves forward (increasing row): dirs 2,3
    cmp dx, 2
    jl .dnext
.try_dir:
    push ax
    mov ax, dx
    call ck_dir_delta
    pop ax
    mov bx, [_ck_fr]
    add bx, [_ck_ddr]
    cmp bx, 0
    jl .dnext
    cmp bx, N
    jge .dnext
    mov cx, [_ck_fc]
    add cx, [_ck_ddc]
    cmp cx, 0
    jl .dnext
    cmp cx, N
    jge .dnext
    push ax
    call ck_addr
    pop ax
    cmp byte [si], EMPTY
    jne .dnext
    ; record candidate
    mov di, [_cm_nsteps]
    cmp di, 4
    jge .dnext
    shl di, 3
    mov si, [_ck_fr]
    mov [_cm_steps + di], si
    mov si, [_ck_fc]
    mov [_cm_steps + di + 2], si
    mov [_cm_steps + di + 4], bx
    mov [_cm_steps + di + 6], cx
    inc word [_cm_nsteps]
.dnext:
    inc dx
    jmp .dloop
.csdone:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ck_apply_black_move: uses _ck_fr/_ck_fc/_ck_tr/_ck_tc, moves the black
; piece there (crowning on the bottom row), announces the move.
ck_apply_black_move:
    push ax
    push bx
    push cx
    push si

    mov bx, [_ck_fr]
    mov cx, [_ck_fc]
    call ck_addr
    mov al, [si]
    mov byte [si], EMPTY

    cmp al, PC_BLK
    jne .place
    cmp word [_ck_tr], N-1
    jne .place
    mov al, PC_BLKK
.place:
    mov bx, [_ck_tr]
    mov cx, [_ck_tc]
    call ck_addr
    mov [si], al

    Print str_cpu
    mov ax, [_ck_fc]
    add al, 'A'
    call vid_putchar
    mov ax, [_ck_fr]
    add al, '1'
    call vid_putchar
    Print str_arrow
    mov ax, [_ck_tc]
    add al, 'A'
    call vid_putchar
    mov ax, [_ck_tr]
    add al, '1'
    call vid_putchar
    NewLine
    GetKey

    pop si
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 ck_count() -> AX=red piece count, BX=black piece count
; ---------------------------------------------------------------------------
ck_count:
    push cx
    push si
    xor ax, ax
    xor bx, bx
    mov si, board
    mov cx, N*N
.cnt:
    mov dl, [si]
    cmp dl, PC_RED
    je .isr
    cmp dl, PC_REDK
    je .isr
    cmp dl, PC_BLK
    je .isb
    cmp dl, PC_BLKK
    je .isb
    jmp .cntnext
.isr:
    inc ax
    jmp .cntnext
.isb:
    inc bx
.cntnext:
    inc si
    loop .cnt
    pop si
    pop cx
    ret

; ---------------------------------------------------------------------------
; U0 ck_draw()
; ---------------------------------------------------------------------------
ck_draw:
    push ax
    push bx
    push cx
    push si
    ClearScreen
    Banner CYAN, str_title
    call ck_count
    NewLine
    PrintLn str_colhdr

    xor bx, bx
.row:
    cmp bx, N
    jge .rowdone
    mov ax, bx
    inc ax
    call print_word_dec
    PrintChar ' '
    xor cx, cx
.col:
    cmp cx, N
    jge .coldone
    call ck_addr
    mov al, [si]
    cmp al, PC_RED
    je .isred
    cmp al, PC_REDK
    je .isredk
    cmp al, PC_BLK
    je .isblk
    cmp al, PC_BLKK
    je .isblkk
    PrintChar '.'
    jmp .chdone
.isred:
    SetColor LTRED
    PrintChar 'r'
    SetColor LTGRAY
    jmp .chdone
.isredk:
    SetColor LTRED
    PrintChar 'R'
    SetColor LTGRAY
    jmp .chdone
.isblk:
    SetColor YELLOW
    PrintChar 'b'
    SetColor LTGRAY
    jmp .chdone
.isblkk:
    SetColor YELLOW
    PrintChar 'B'
    SetColor LTGRAY
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

U16 ck_rng, 0x3E19
ck_rand:
    push bx
    mov ax, [ck_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [ck_rng], ax
    pop bx
    ret
