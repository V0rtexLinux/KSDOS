; =============================================================================
; HANOI.OVL  -  Tower of Hanoi  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; 5 disks, 3 pegs A/B/C. Move all disks to peg C, never placing a larger
; disk on a smaller one. Type source peg then destination peg (e.g. "AC").
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

NUM_DISKS equ 5

; Each peg: 5-byte stack of disk sizes (0 = empty slot), plus a count
STRBUF peg_a, NUM_DISKS
STRBUF peg_b, NUM_DISKS
STRBUF peg_c, NUM_DISKS
U16 cnt_a, 0
U16 cnt_b, 0
U16 cnt_c, 0
U16 moves, 0

STR str_title,  "TOWER OF HANOI - move all disks to peg C"
STR str_prompt, "Move (e.g. AC): "
STR str_bad,    "Illegal move."
STR str_moves,  "Moves: "
STR str_win,    "Solved! Moves used: "
STR str_optimal," (optimal = "
STR str_paren,  ")"
STR str_again,  "Play again? (Y/N): "
STR peg_lbl_a,  " A "
STR peg_lbl_b,  " B "
STR peg_lbl_c,  " C "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
.new_game:
    ClearScreen
    Banner CYAN, str_title
    NewLine

    mov si, peg_a
    mov cx, NUM_DISKS
    mov al, NUM_DISKS
.initp:
    mov [si], al
    inc si
    dec al
    loop .initp
    mov word [cnt_a], NUM_DISKS
    mov word [cnt_b], 0
    mov word [cnt_c], 0
    mov word [moves], 0

.loop:
    call hn_draw
    call hn_check_win
    cmp ax, 1
    je .won

    Print str_prompt
    GetKey
    call _uc_al
    mov [_hn_src], al
    NewLine
    GetKey
    call _uc_al
    mov [_hn_dst], al
    NewLine

    mov al, [_hn_src]
    call hn_peg_ptr        ; -> BX=stack ptr, SI=count ptr
    mov [_hn_src_stk], bx
    mov [_hn_src_cnt], si

    mov al, [_hn_dst]
    call hn_peg_ptr
    mov [_hn_dst_stk], bx
    mov [_hn_dst_cnt], si

    ; source must be nonempty
    mov si, [_hn_src_cnt]
    mov cx, [si]
    cmp cx, 0
    je .illegal

    ; top disk of source = stack[count-1]
    mov bx, [_hn_src_stk]
    mov di, cx
    dec di
    mov al, [bx+di]

    ; dest: if nonempty, top must be larger
    mov si, [_hn_dst_cnt]
    mov dx, [si]
    cmp dx, 0
    je .move_ok
    mov bx, [_hn_dst_stk]
    mov di, dx
    dec di
    mov ah, [bx+di]
    cmp al, ah
    ja .illegal

.move_ok:
    ; pop from source
    mov si, [_hn_src_cnt]
    dec word [si]
    ; push to dest
    mov si, [_hn_dst_cnt]
    mov di, [si]
    mov bx, [_hn_dst_stk]
    mov [bx+di], al
    inc word [si]
    inc word [moves]
    jmp .loop

.illegal:
    call hn_draw
    PrintLn str_bad
    GetKey
    jmp .loop

.won:
    call hn_draw
    Print str_win
    mov ax, [moves]
    call print_word_dec
    Print str_optimal
    mov ax, 1
    mov cx, NUM_DISKS
.pw:
    shl ax, 1
    loop .pw
    dec ax
    call print_word_dec
    PrintLn str_paren
    Print str_again
    GetKey
    NewLine
    cmp al, 'y'
    je .new_game
    cmp al, 'Y'
    je .new_game
ENDFN
_hn_src:     db 0
_hn_dst:     db 0
_hn_src_stk: dw 0
_hn_src_cnt: dw 0
_hn_dst_stk: dw 0
_hn_dst_cnt: dw 0

; ---------------------------------------------------------------------------
; U0 hn_peg_ptr(AL='A'/'B'/'C') -> BX=stack buffer, SI=count variable addr
; ---------------------------------------------------------------------------
hn_peg_ptr:
    cmp al, 'A'
    jne .try_b
    mov bx, peg_a
    mov si, cnt_a
    ret
.try_b:
    cmp al, 'B'
    jne .try_c
    mov bx, peg_b
    mov si, cnt_b
    ret
.try_c:
    mov bx, peg_c
    mov si, cnt_c
    ret

; ---------------------------------------------------------------------------
; U0 hn_check_win() -> AX=1 if all disks on peg C
; ---------------------------------------------------------------------------
hn_check_win:
    push cx
    mov ax, 0
    mov cx, [cnt_c]
    cmp cx, NUM_DISKS
    jne .no
    mov ax, 1
.no:
    pop cx
    ret

; ---------------------------------------------------------------------------
; U0 hn_draw()
; ---------------------------------------------------------------------------
hn_draw:
    push ax
    push bx
    push cx
    push dx
    ClearScreen
    Banner CYAN, str_title
    NewLine

    ; draw from top row (row=NUM_DISKS-1, largest possible height) down
    mov dx, NUM_DISKS
    dec dx
.row:
    cmp dx, 0
    jl .rowdone
    push dx
    call hn_draw_row
    pop dx
    dec dx
    jmp .row
.rowdone:
    PrintLn str_line
    Print peg_lbl_a
    Print peg_lbl_b
    PrintLn peg_lbl_c
    NewLine
    Print str_moves
    mov ax, [moves]
    call print_word_dec
    NewLine

    pop dx
    pop cx
    pop bx
    pop ax
    ret
STR str_line, "-------------"

; hn_draw_row: DX = row index from bottom (0..NUM_DISKS-1), draws one text
; row across all three pegs
hn_draw_row:
    push ax
    push bx
    push cx
    push si

    mov bx, peg_a
    mov si, cnt_a
    call hn_row_seg
    mov bx, peg_b
    mov si, cnt_b
    call hn_row_seg
    mov bx, peg_c
    mov si, cnt_c
    call hn_row_seg
    NewLine

    pop si
    pop cx
    pop bx
    pop ax
    ret

; hn_row_seg: BX=peg stack, SI=count addr, DX=row index -> print 5-char cell
hn_row_seg:
    push ax
    push cx
    push di
    mov cx, [si]
    cmp dx, cx
    jl .has_disk
    Print str_empty
    jmp .segdone
.has_disk:
    mov di, dx
    mov al, [bx+di]
    call hn_print_disk
.segdone:
    pop di
    pop cx
    pop ax
    ret
STR str_empty, "  |  "

; hn_print_disk: AL=disk size (1..NUM_DISKS) -> print centred bar
hn_print_disk:
    push ax
    push cx
    movzx cx, al
    mov ax, NUM_DISKS
    sub ax, cx
.lpad:
    test ax, ax
    jz .lpaddone
    PrintChar ' '
    dec ax
    jmp .lpad
.lpaddone:
    mov ax, cx
    shl ax, 1
    inc ax
.bar:
    test ax, ax
    jz .bardone
    PrintChar 219
    dec ax
    jmp .bar
.bardone:
    mov ax, NUM_DISKS
    sub ax, cx
.rpad:
    test ax, ax
    jz .rpaddone
    PrintChar ' '
    dec ax
    jmp .rpad
.rpaddone:
    pop cx
    pop ax
    ret
