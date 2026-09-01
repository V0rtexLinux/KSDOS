; =============================================================================
; LIGHTOUT.OVL  -  Lights Out puzzle  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; 5x5 grid. Toggling a cell also toggles its 4 orthogonal neighbours.
; Arrow keys move the cursor, SPACE toggles, goal: turn every light off.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

GRID_N equ 5
STRBUF grid, GRID_N*GRID_N   ; 0=off, 1=on
U16 cur_x, 0
U16 cur_y, 0
U16 lo_rng, 0x2545
U16 lo_moves, 0

STR str_title, "LIGHTS OUT - arrows=move  SPACE=toggle  ESC=quit"
STR str_moves, "Moves: "
STR str_win,   "All lights out - solved!"
STR str_again, "Play again? (Y/N): "
STR str_on,    "[]"
STR str_off,   "::"
STR str_cur_on,"()"
STR str_cur_off,".."

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
.new_game:
    ClearScreen
    mov dh, 0
    mov dl, 0
    call vid_set_cursor
    SetColor 0x1F
    PrintLn str_title
    SetColor 0x07

    mov ah, 0x00
    int 0x1A
    mov [lo_rng], dx
    xor [lo_rng], cx

    mov si, grid
    mov cx, GRID_N*GRID_N
    xor al, al
.clr:
    mov [si], al
    inc si
    loop .clr

    ; scramble with random valid toggles so the puzzle stays solvable
    mov cx, 15
.scramble:
    push cx
    call lo_rand
    xor dx, dx
    mov bx, GRID_N
    div bx
    mov [cur_x], dx
    call lo_rand
    xor dx, dx
    mov bx, GRID_N
    div bx
    mov [cur_y], dx
    mov ax, [cur_x]
    mov bx, [cur_y]
    call lo_toggle_cross
    pop cx
    loop .scramble

    mov word [cur_x], 2
    mov word [cur_y], 2
    mov word [lo_moves], 0

.loop:
    call lo_draw
    call lo_check_win
    cmp ax, 1
    je .won

    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp al, ' '
    je .toggle
    test ah, ah
    jz .loop
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    cmp ah, 0x4B
    je .left
    cmp ah, 0x4D
    je .right
    jmp .loop
.up:
    cmp word [cur_y], 0
    je .loop
    dec word [cur_y]
    jmp .loop
.down:
    cmp word [cur_y], GRID_N-1
    jge .loop
    inc word [cur_y]
    jmp .loop
.left:
    cmp word [cur_x], 0
    je .loop
    dec word [cur_x]
    jmp .loop
.right:
    cmp word [cur_x], GRID_N-1
    jge .loop
    inc word [cur_x]
    jmp .loop
.toggle:
    mov ax, [cur_x]
    mov bx, [cur_y]
    call lo_toggle_cross
    inc word [lo_moves]
    jmp .loop

.won:
    mov dh, 9
    mov dl, 0
    call vid_set_cursor
    SetColor 0x1A
    PrintLn str_win
    SetColor 0x07
    Print str_again
    GetKey
    NewLine
    cmp al, 'y'
    je .new_game
    cmp al, 'Y'
    je .new_game
    jmp .quit
.quit:
ENDFN

; ---------------------------------------------------------------------------
; U0 lo_toggle_cross(AX=x, BX=y)  -  toggle (x,y) and its 4 neighbours
; ---------------------------------------------------------------------------
lo_toggle_cross:
    push ax
    push bx
    call lo_toggle_one
    pop bx
    pop ax
    push ax
    push bx
    dec ax
    call lo_toggle_one
    pop bx
    pop ax
    push ax
    push bx
    inc ax
    call lo_toggle_one
    pop bx
    pop ax
    push ax
    push bx
    dec bx
    call lo_toggle_one
    pop bx
    pop ax
    push ax
    push bx
    inc bx
    call lo_toggle_one
    pop bx
    pop ax
    ret

; lo_toggle_one: AX=x, BX=y; no-op if out of bounds
lo_toggle_one:
    push ax
    push bx
    push si
    cmp ax, 0
    jl .done
    cmp ax, GRID_N
    jge .done
    cmp bx, 0
    jl .done
    cmp bx, GRID_N
    jge .done
    push ax                 ; save x
    mov ax, bx               ; ax = y
    mov si, GRID_N
    imul si                   ; ax = y*GRID_N
    pop si                     ; si = x
    add ax, si                  ; ax = y*GRID_N + x
    mov si, ax
    xor byte [grid + si], 1
.done:
    pop si
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 lo_draw()
; ---------------------------------------------------------------------------
lo_draw:
    push ax
    push bx
    push cx
    push dx
    push si

    xor bx, bx              ; row
.row:
    cmp bx, GRID_N
    jge .rowdone
    mov dh, bl
    add dh, 3
    mov dl, 4
    call vid_set_cursor
    xor cx, cx               ; col
.col:
    cmp cx, GRID_N
    jge .coldone
    mov ax, bx
    mov si, GRID_N
    imul si
    add ax, cx
    mov si, ax
    mov al, [grid + si]

    cmp cx, [cur_x]
    jne .not_cur_x
    cmp bx, [cur_y]
    jne .not_cur_x
    ; cursor is here
    test al, al
    jz .cur_off
    SetColor 0x4E
    Print str_cur_on
    jmp .cell_done
.cur_off:
    SetColor 0x40
    Print str_cur_off
    jmp .cell_done
.not_cur_x:
    test al, al
    jz .off
    SetColor 0x2E
    Print str_on
    jmp .cell_done
.off:
    SetColor 0x08
    Print str_off
.cell_done:
    inc cx
    jmp .col
.coldone:
    inc bx
    jmp .row
.rowdone:
    SetColor 0x07
    mov dh, GRID_N + 4
    mov dl, 0
    call vid_set_cursor
    Print str_moves
    mov ax, [lo_moves]
    call print_word_dec
    NewLine

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 lo_check_win() -> AX=1 if every cell is off
; ---------------------------------------------------------------------------
lo_check_win:
    push si
    push cx
    mov si, grid
    mov cx, GRID_N*GRID_N
.chk:
    cmp byte [si], 0
    jne .not_won
    inc si
    loop .chk
    mov ax, 1
    jmp .cwdone
.not_won:
    xor ax, ax
.cwdone:
    pop cx
    pop si
    ret

; ---------------------------------------------------------------------------
; U0 lo_rand() -> AX = random word
; ---------------------------------------------------------------------------
lo_rand:
    push bx
    mov ax, [lo_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xB400
    xor ax, bx
    mov [lo_rng], ax
    pop bx
    ret
