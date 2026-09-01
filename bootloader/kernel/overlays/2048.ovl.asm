; =============================================================================
; 2048.OVL  -  Sliding tile merge puzzle  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; 4x4 grid of power-of-two tiles. Arrow keys slide all tiles that
; direction; equal tiles that collide merge into their sum. A new 2 (or
; occasionally 4) appears after every move that changes the board.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

GN equ 4
WORDBUF grid, GN*GN
WORDBUF grow, GN            ; scratch row/col buffer for a slide
U16 tw_rng, 0x6B17
U16 score, 0

STR str_title,  "2048 - arrows to slide, ESC to quit"
STR str_score,  "Score: "
STR str_win,    "*** 2048! You win! (keep going or ESC) ***"
STR str_over,   "No moves left - game over."
STR str_again,  "Play again? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    mov ah, 0x00
    int 0x1A
    mov [tw_rng], dx
    xor [tw_rng], cx

.new_game:
    mov si, grid
    mov cx, GN*GN
.clr:
    mov word [si], 0
    add si, 2
    loop .clr
    mov word [score], 0
    call tw_spawn
    call tw_spawn

.loop:
    call tw_draw
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    test ah, ah
    jz .loop

    mov word [_tw_moved], 0
    cmp ah, 0x48
    je .m_up
    cmp ah, 0x50
    je .m_down
    cmp ah, 0x4B
    je .m_left
    cmp ah, 0x4D
    je .m_right
    jmp .loop
.m_up:
    mov al, 0
    call tw_move
    jmp .after_move
.m_down:
    mov al, 1
    call tw_move
    jmp .after_move
.m_left:
    mov al, 2
    call tw_move
    jmp .after_move
.m_right:
    mov al, 3
    call tw_move
.after_move:
    cmp word [_tw_moved], 0
    je .loop
    call tw_spawn
    call tw_has_moves
    cmp ax, 0
    jne .loop

    call tw_draw
    PrintLn str_over
    jmp .ask_again

.quit:
    jmp .ask_again2
.ask_again:
.ask_again2:
    Print str_again
    GetKey
    NewLine
    cmp al, 'y'
    je .new_game
    cmp al, 'Y'
    je .new_game
ENDFN
_tw_moved: dw 0

; ---------------------------------------------------------------------------
; U0 tw_spawn()  -  place a 2 (90%) or 4 (10%) in a random empty cell
; ---------------------------------------------------------------------------
tw_spawn:
    push ax
    push bx
    push cx
    push si

    ; count empties
    xor cx, cx
    mov si, grid
    mov bx, GN*GN
.cnt:
    cmp word [si], 0
    jne .cnt_next
    inc cx
.cnt_next:
    add si, 2
    dec bx
    jnz .cnt
    cmp cx, 0
    je .spawn_done

    call tw_rand
    xor dx, dx
    div cx                       ; dx = which empty slot (0-based)
    mov cx, dx
    mov si, grid
    mov bx, GN*GN
.find:
    cmp word [si], 0
    jne .find_next
    cmp cx, 0
    je .found
    dec cx
.find_next:
    add si, 2
    dec bx
    jnz .find
    jmp .spawn_done
.found:
    call tw_rand
    xor dx, dx
    mov bx, 10
    div bx
    cmp dx, 9
    je .four
    mov word [si], 2
    jmp .spawn_done
.four:
    mov word [si], 4
.spawn_done:
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 tw_move(AL=dir: 0=up 1=down 2=left 3=right)
; Slides every row/column, merges equal adjacent tiles once each, sets
; _tw_moved=1 if anything on the board actually changed.
; ---------------------------------------------------------------------------
tw_move:
    push ax
    push bx
    push cx
    push si
    push di
    mov [_tw_dir], al

    xor bx, bx                  ; line index 0..3 (row or col)
.line_loop:
    cmp bx, GN
    jge .move_done

    ; gather the 4 cells of this line (in slide order) into grow[]
    xor cx, cx
.gather:
    cmp cx, GN
    jge .gather_done
    call tw_cell_addr           ; in: bx=line, cx=pos-in-line -> si=addr
    mov ax, [si]
    mov di, cx
    shl di, 1
    mov [grow + di], ax
    inc cx
    jmp .gather
.gather_done:

    call tw_collapse_row        ; compacts+merges grow[] in place

    ; scatter back, tracking whether anything changed
    xor cx, cx
.scatter:
    cmp cx, GN
    jge .line_next
    call tw_cell_addr
    mov di, cx
    shl di, 1
    mov ax, [grow + di]
    cmp ax, [si]
    je .no_change
    mov word [_tw_moved], 1
    mov [si], ax
.no_change:
    inc cx
    jmp .scatter
.line_next:
    inc bx
    jmp .line_loop
.move_done:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret
_tw_dir: db 0

; tw_cell_addr: BX=line index, CX=position-in-line (both 0..3, in the
; direction implied by _tw_dir) -> SI = address of that grid cell
tw_cell_addr:
    push ax
    push dx
    mov al, [_tw_dir]
    cmp al, 0
    je .up
    cmp al, 1
    je .down
    cmp al, 2
    je .left
    jmp .right
.up:
    ; line=column bx, pos=row cx (slide toward row 0)
    mov ax, cx
    jmp .idx
.down:
    mov ax, GN-1
    sub ax, cx
.idx:
    mov dx, GN
    imul dx
    add ax, bx
    jmp .have_index
.left:
    ; line=row bx, pos=col cx (slide toward col 0)
    mov ax, bx
    mov dx, GN
    imul dx
    add ax, cx
    jmp .have_index
.right:
    mov ax, bx
    mov dx, GN
    imul dx
    mov si, ax
    mov ax, GN-1
    sub ax, cx
    add ax, si
.have_index:
    mov si, ax
    shl si, 1
    add si, grid
    pop dx
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 tw_collapse_row()  -  compact non-zero entries of grow[] to the front,
; merge equal adjacent pairs once (left to right), re-pad with zeros.
; ---------------------------------------------------------------------------
tw_collapse_row:
    push ax
    push bx
    push cx
    push si
    push di

    ; compact non-zero values into positions 0..k-1
    xor bx, bx                  ; write index
    xor cx, cx                  ; read index
.compact:
    cmp cx, GN
    jge .compact_done
    mov si, cx
    shl si, 1
    mov ax, [grow + si]
    cmp ax, 0
    je .compact_next
    mov di, bx
    shl di, 1
    mov [grow + di], ax
    inc bx
.compact_next:
    inc cx
    jmp .compact
.compact_done:
    ; zero-fill the rest
.padz:
    cmp bx, GN
    jge .pad_done
    mov si, bx
    shl si, 1
    mov word [grow + si], 0
    inc bx
    jmp .padz
.pad_done:

    ; merge adjacent equal pairs, left to right, each tile merges once
    xor cx, cx
.merge:
    cmp cx, GN-1
    jge .merge_done
    mov si, cx
    shl si, 1
    mov ax, [grow + si]
    cmp ax, 0
    je .merge_next
    mov di, cx
    inc di
    shl di, 1
    cmp ax, [grow + di]
    jne .merge_next
    shl ax, 1
    mov [grow + si], ax
    add [score], ax
    mov word [grow + di], 0
.merge_next:
    inc cx
    jmp .merge
.merge_done:

    ; compact again to close the gap left by merged-away tiles
    xor bx, bx
    xor cx, cx
.compact2:
    cmp cx, GN
    jge .compact2_done
    mov si, cx
    shl si, 1
    mov ax, [grow + si]
    cmp ax, 0
    je .compact2_next
    mov di, bx
    shl di, 1
    mov [grow + di], ax
    inc bx
.compact2_next:
    inc cx
    jmp .compact2
.compact2_done:
.padz2:
    cmp bx, GN
    jge .c2done
    mov si, bx
    shl si, 1
    mov word [grow + si], 0
    inc bx
    jmp .padz2
.c2done:

    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 tw_has_moves() -> AX=1 if any empty cell exists or any adjacent pair
; of equal tiles exists (i.e. a move is still possible)
; ---------------------------------------------------------------------------
tw_has_moves:
    push bx
    push cx
    push si

    mov si, grid
    mov cx, GN*GN
.chk_empty:
    cmp word [si], 0
    je .yes
    add si, 2
    loop .chk_empty

    ; horizontal adjacent pairs
    xor bx, bx                  ; row
.rowchk:
    cmp bx, GN
    jge .vertsetup
    xor cx, cx                  ; col
.colinner:
    cmp cx, GN-1
    jge .rowchk_next
    call tw_addr                ; bx=row, cx=col -> si
    mov ax, [si]
    push cx
    inc cx
    call tw_addr
    pop cx
    cmp ax, [si]
    je .yes
    inc cx
    jmp .colinner
.rowchk_next:
    inc bx
    jmp .rowchk

.vertsetup:
    ; vertical adjacent pairs
    xor cx, cx                  ; col
.colchk:
    cmp cx, GN
    jge .no
    xor bx, bx                  ; row
.rowinner:
    cmp bx, GN-1
    jge .colchk_next
    call tw_addr                ; bx=row, cx=col -> si
    mov ax, [si]
    push bx
    inc bx
    call tw_addr
    pop bx
    cmp ax, [si]
    je .yes
    inc bx
    jmp .rowinner
.colchk_next:
    inc cx
    jmp .colchk

.no:
    xor ax, ax
    jmp .hmdone
.yes:
    mov ax, 1
.hmdone:
    pop si
    pop cx
    pop bx
    ret

; tw_addr: BX=row, CX=col -> SI=grid addr
tw_addr:
    push ax
    push dx
    mov ax, bx
    mov dx, GN
    imul dx
    add ax, cx
    mov si, ax
    shl si, 1
    add si, grid
    pop dx
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 tw_draw()
; ---------------------------------------------------------------------------
tw_draw:
    push ax
    push bx
    push cx
    push si
    ClearScreen
    Banner CYAN, str_title
    Print str_score
    mov ax, [score]
    call print_word_dec
    NewLine
    NewLine

    xor bx, bx
.row:
    cmp bx, GN
    jge .rowdone
    xor cx, cx
.col:
    cmp cx, GN
    jge .coldone
    mov ax, bx
    mov si, GN
    imul si
    add ax, cx
    mov si, ax
    shl si, 1
    add si, grid
    mov ax, [si]
    PrintChar '['
    cmp ax, 0
    jne .have_val
    PrintChar ' '
    PrintChar ' '
    PrintChar ' '
    PrintChar ' '
    jmp .celldone
.have_val:
    call print_word_dec
    PrintChar ' '
.celldone:
    PrintChar ']'
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

tw_rand:
    push bx
    mov ax, [tw_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [tw_rng], ax
    pop bx
    ret
