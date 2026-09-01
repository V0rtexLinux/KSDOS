; =============================================================================
; REVERSI.OVL  -  Othello vs CPU  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; 8x8 board. You are Black (X), CPU is White (O). Standard flip rules.
; CPU plays greedily: the legal move that flips the most discs.
; Enter moves as column letter (A-H) then row digit (1-8), e.g. "D3".
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

N        equ 8
EMPTY    equ 0
DISC_B    equ 1
DISC_W    equ 2

STRBUF board, N*N

; 8 directions as (dcol,drow) signed byte pairs
dir_tab: db  0,-1,  0,1,  -1,0,  1,0,  -1,-1,  1,1,  -1,1,  1,-1

STR str_title,  "REVERSI - you are X (Black), CPU is O (White)"
STR str_prompt, "Your move (e.g. D3): "
STR str_bad,    "Illegal move."
STR str_pass_p, "No legal moves for you - passing."
STR str_pass_c, "No legal moves for CPU - passing."
STR str_score,  "You: "
STR str_score2, "   CPU: "
STR str_over,   "Game over!  "
STR str_youwin, "You win!"
STR str_cpuwin, "CPU wins!"
STR str_tie,    "It's a tie!"
STR str_colhdr, "  A B C D E F G H"
STR str_again,  "Play again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
.new_game:
    mov si, board
    mov cx, N*N
    xor al, al
.clr:
    mov [si], al
    inc si
    loop .clr
    mov byte [board + 3*N+3], DISC_W
    mov byte [board + 3*N+4], DISC_B
    mov byte [board + 4*N+3], DISC_B
    mov byte [board + 4*N+4], DISC_W

.turn_black:
    call rv_draw
    mov al, DISC_B
    call rv_any_legal
    cmp ax, 0
    je .black_pass
    call rv_player_move
    jmp .after_black
.black_pass:
    call rv_draw
    PrintLn str_pass_p
    GetKey
.after_black:

    call rv_draw
    mov al, DISC_W
    call rv_any_legal
    cmp ax, 0
    je .white_pass
    call rv_cpu_move
    jmp .after_white
.white_pass:
    call rv_draw
    PrintLn str_pass_c
    GetKey
.after_white:

    ; end if neither side has a legal move
    mov al, DISC_B
    call rv_any_legal
    mov bx, ax
    mov al, DISC_W
    call rv_any_legal
    or ax, bx
    cmp ax, 0
    je .game_over
    jmp .turn_black

.game_over:
    call rv_draw
    call rv_count
    Print str_over
    cmp ax, bx
    jg .p_win
    jl .c_win
    PrintLn str_tie
    jmp .ask_again
.p_win:
    PrintLn str_youwin
    jmp .ask_again
.c_win:
    PrintLn str_cpuwin
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
; U0 rv_player_move()  -  prompt until a legal move is entered, then apply
; ---------------------------------------------------------------------------
rv_player_move:
    push ax
    push bx
.ask:
    Print str_prompt
    GetKey
    call _uc_al
    NewLine
    cmp al, 'A'
    jb .ask
    cmp al, 'H'
    ja .ask
    sub al, 'A'
    movzx bx, al
    mov [_rv_col], bx

    GetKey
    NewLine
    cmp al, '1'
    jb .ask
    cmp al, '8'
    ja .ask
    sub al, '1'
    movzx bx, al
    mov [_rv_row], bx

    mov ax, [_rv_col]
    mov bx, [_rv_row]
    mov cl, DISC_B
    call rv_try_move
    cmp ax, 0
    je .illegal
    pop bx
    pop ax
    ret
.illegal:
    call rv_draw
    PrintLn str_bad
    jmp .ask
_rv_col: dw 0
_rv_row: dw 0

; ---------------------------------------------------------------------------
; U0 rv_cpu_move()  -  greedy: pick the legal move that flips the most
; ---------------------------------------------------------------------------
rv_cpu_move:
    push ax
    push bx
    push cx
    push dx

    mov word [_rv_best], -1
    xor dx, dx                  ; cell index 0..63
.scan:
    cmp dx, N*N
    jge .scandone
    mov ax, dx
    xor bx, bx
    xor cx, cx
.divloop:
    cmp ax, N
    jl .divdone
    sub ax, N
    inc cx
    jmp .divloop
.divdone:
    mov bx, ax                  ; bx=col, cx=row
    push dx
    mov ax, bx
    push cx
    call rv_flip_count_only
    pop cx
    pop dx
    cmp ax, [_rv_best]
    jle .scan_next
    mov [_rv_best], ax
    mov [_rv_bcol], bx
    mov [_rv_brow], cx
.scan_next:
    inc dx
    jmp .scan
.scandone:
    cmp word [_rv_best], -1
    je .done
    mov ax, [_rv_bcol]
    mov bx, [_rv_brow]
    mov cl, DISC_W
    call rv_try_move
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
_rv_best: dw 0
_rv_bcol: dw 0
_rv_brow: dw 0

; rv_flip_count_only: AX=col, CX=row -> AX = flips DISC_W would get there
; (0 if illegal). Non-destructive probe.
rv_flip_count_only:
    push bx
    push cx
    push dx
    mov bx, cx
    mov cl, DISC_W
    mov dl, 1                    ; probe mode (don't mutate board)
    call rv_eval_move
    pop dx
    pop cx
    pop bx
    ret

; ---------------------------------------------------------------------------
; U0 rv_try_move(AX=col, BX=row, CL=colour) -> AX=1 applied, 0 illegal
; ---------------------------------------------------------------------------
rv_try_move:
    push bx
    push cx
    push dx
    mov dl, 0                    ; apply mode
    call rv_eval_move
    cmp ax, 0
    je .illegal
    mov ax, 1
    jmp .tmdone
.illegal:
    xor ax, ax
.tmdone:
    pop dx
    pop cx
    pop bx
    ret

; ---------------------------------------------------------------------------
; U0 rv_eval_move(AX=col, BX=row, CL=colour, DL=probe(1)/apply(0))
; Returns AX = total discs that would be/were flipped (0 = illegal).
; Checks the target cell is empty, then walks all 8 directions looking for
; a run of the opposite colour terminated by our own colour.
; ---------------------------------------------------------------------------
rv_eval_move:
    push bx
    push cx
    push dx
    push si
    push di

    mov [_re_col], ax
    mov [_re_row], bx
    mov [_re_mine], cl
    mov [_re_probe], dl
    mov word [_re_total], 0

    ; target cell must be on-board and empty
    cmp ax, 0
    jl .em_illegal
    cmp ax, N
    jge .em_illegal
    cmp bx, 0
    jl .em_illegal
    cmp bx, N
    jge .em_illegal
    mov ax, bx
    mov si, N
    imul si
    add ax, [_re_col]
    mov si, ax
    cmp byte [board + si], EMPTY
    jne .em_illegal

    mov byte [_re_dir], 0
.dir_loop:
    cmp byte [_re_dir], 8
    jge .dirs_done
    movzx si, byte [_re_dir]
    shl si, 1
    movzx ax, byte [dir_tab + si]
    ; sign-extend the byte delta (values are -1,0,1)
    cmp al, 128
    jb .dc_ok
    or ah, 0xFF
.dc_ok:
    mov [_re_dcol], ax
    movzx ax, byte [dir_tab + si + 1]
    cmp al, 128
    jb .dr_ok
    or ah, 0xFF
.dr_ok:
    mov [_re_drow], ax

    call rv_scan_dir
    add [_re_total], ax

    inc byte [_re_dir]
    jmp .dir_loop
.dirs_done:
    mov ax, [_re_total]
    cmp ax, 0
    je .em_illegal
    cmp byte [_re_probe], 1
    je .em_ret               ; probe mode: don't mutate the board

    ; apply mode: place our disc and flip along every winning direction
    mov ax, [_re_row]
    mov si, N
    imul si
    add ax, [_re_col]
    mov si, ax
    mov al, [_re_mine]
    mov [board + si], al

    mov byte [_re_dir], 0
.apply_loop:
    cmp byte [_re_dir], 8
    jge .em_ret
    movzx si, byte [_re_dir]
    shl si, 1
    movzx ax, byte [dir_tab + si]
    cmp al, 128
    jb .adc_ok
    or ah, 0xFF
.adc_ok:
    mov [_re_dcol], ax
    movzx ax, byte [dir_tab + si + 1]
    cmp al, 128
    jb .adr_ok
    or ah, 0xFF
.adr_ok:
    mov [_re_drow], ax
    mov byte [_re_apply], 1
    call rv_scan_dir
    inc byte [_re_dir]
    jmp .apply_loop

.em_illegal:
    xor ax, ax
.em_ret:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
_re_col:   dw 0
_re_row:   dw 0
_re_mine:  db 0
_re_probe: db 0
_re_dir:   db 0
_re_dcol:  dw 0
_re_drow:  dw 0
_re_total: dw 0
_re_apply: db 0

; ---------------------------------------------------------------------------
; U0 rv_scan_dir() -> AX = number of opposite-colour discs that would be
; flipped walking (_re_dcol,_re_drow) from (_re_col,_re_row). If
; _re_apply=1, actually flips them on the board (and resets the flag).
; ---------------------------------------------------------------------------
rv_scan_dir:
    push bx
    push cx
    push dx
    push si
    push di

    mov ax, [_re_col]
    mov bx, [_re_row]
    xor cx, cx                   ; run length of opposite colour seen
.step:
    add ax, [_re_dcol]
    add bx, [_re_drow]
    cmp ax, 0
    jl .fail
    cmp ax, N
    jge .fail
    cmp bx, 0
    jl .fail
    cmp bx, N
    jge .fail

    ; index = row*N + col, computed without losing ax(col)/bx(row)
    mov di, ax
    mov ax, bx
    mov si, N
    imul si
    add ax, di
    mov si, ax
    mov ax, di

    mov dl, [board + si]
    cmp dl, EMPTY
    je .fail
    cmp dl, [_re_mine]
    je .maybe_flip
    inc cx
    jmp .step
.maybe_flip:
    test cx, cx
    jz .fail                     ; adjacent own colour, no run to flip
    cmp byte [_re_apply], 1
    jne .succeed
    ; apply: walk back and flip
    push ax
    push bx
    mov ax, [_re_col]
    mov bx, [_re_row]
.flipback:
    add ax, [_re_dcol]
    add bx, [_re_drow]
    mov di, ax
    mov ax, bx
    mov si, N
    imul si
    add ax, di
    mov si, ax
    mov ax, di
    mov dl, [board + si]
    cmp dl, [_re_mine]
    je .flipdone
    mov dl, [_re_mine]
    mov [board + si], dl
    jmp .flipback
.flipdone:
    pop bx
    pop ax
    mov byte [_re_apply], 0
.succeed:
    mov ax, cx
    jmp .sd_ret
.fail:
    xor ax, ax
.sd_ret:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

; ---------------------------------------------------------------------------
; U0 rv_any_legal(AL=colour) -> AX=1 if any legal move exists for colour
; ---------------------------------------------------------------------------
rv_any_legal:
    push bx
    push cx
    push dx
    mov [_ral_col], al
    xor dx, dx
.scan:
    cmp dx, N*N
    jge .none
    mov ax, dx
    xor bx, bx
    xor cx, cx
.divloop:
    cmp ax, N
    jl .divdone
    sub ax, N
    inc cx
    jmp .divloop
.divdone:
    ; ax=col, cx=row
    push dx
    push cx
    mov bx, cx
    mov cl, [_ral_col]
    mov dl, 1
    call rv_eval_move
    pop cx
    pop dx
    cmp ax, 0
    jne .found
    inc dx
    jmp .scan
.none:
    xor ax, ax
    jmp .raldone
.found:
    mov ax, 1
.raldone:
    pop dx
    pop cx
    pop bx
    ret
_ral_col: db 0

; ---------------------------------------------------------------------------
; U0 rv_count() -> AX=black count, BX=white count
; ---------------------------------------------------------------------------
rv_count:
    push cx
    push si
    xor ax, ax
    xor bx, bx
    mov si, board
    mov cx, N*N
.cnt:
    cmp byte [si], DISC_B
    jne .notb
    inc ax
.notb:
    cmp byte [si], DISC_W
    jne .notw
    inc bx
.notw:
    inc si
    loop .cnt
    pop si
    pop cx
    ret

; ---------------------------------------------------------------------------
; U0 rv_draw()
; ---------------------------------------------------------------------------
rv_draw:
    push ax
    push bx
    push cx
    push si
    ClearScreen
    Banner CYAN, str_title
    NewLine
    call rv_count
    Print str_score
    call print_word_dec
    Print str_score2
    mov ax, bx
    call print_word_dec
    NewLine
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
    mov ax, bx
    mov si, N
    imul si
    add ax, cx
    mov si, ax
    mov al, [board + si]
    cmp al, DISC_B
    je .isblack
    cmp al, DISC_W
    je .iswhite
    PrintChar '.'
    jmp .chdone
.isblack:
    SetColor YELLOW
    PrintChar 'X'
    SetColor LTGRAY
    jmp .chdone
.iswhite:
    SetColor WHITE
    PrintChar 'O'
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
