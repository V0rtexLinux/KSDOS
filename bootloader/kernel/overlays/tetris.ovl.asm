; =============================================================================
; TETRIS.OVL  -  Tetris  (KSDOS 16-bit)
; A/D=move, W=rotate, S=drop faster, ESC=quit
; Grid: 10 cols x 20 rows.  Cell=10px.  Playfield starts at x=60, y=0
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

TCOLS   equ 10
TROWS   equ 20
CELL    equ 10
PFX     equ 60          ; playfield left X

STR str_title,   "TETRIS"
STR str_score,   "Score:"
STR str_lines,   "Lines:"
STR str_next,    "Next:"
STR str_over,    "GAME OVER"
STR str_key,     "Press key"
STRBUF sbuf, 8

; Board: 10x20 bytes (0=empty, 1-7=colour)
STRBUF board, 200

; Current piece
U16 cur_type, 0    ; 0-6
U16 cur_rot,  0    ; 0-3
I16 cur_x,    3
I16 cur_y,    0
U16 next_type, 1
U16 score,    0
U16 lines,    0
U16 lcg_seed, 0xABCD
U16 drop_spd, 40   ; frames between auto-drop
U16 drop_cnt, 0

; Tetromino definitions: 4 rotations x 4 cells x (dx,dy)
; Encoded as 16 signed bytes per piece (8 rotations unused here — use 4)
; Format: for each rotation, 4 (dx,dy) pairs

; I-piece
tet_I:

    db -1,0, 0,0, 1,0, 2,0
    db  0,-1, 0,0, 0,1, 0,2

    db -1,0, 0,0, 1,0, 2,0
    db  0,-1, 0,0, 0,1, 0,2
; O-piece
tet_O:

    db  0,0, 1,0, 0,1, 1,1
    db  0,0, 1,0, 0,1, 1,1

    db  0,0, 1,0, 0,1, 1,1
    db  0,0, 1,0, 0,1, 1,1
; T-piece
tet_T:

    db  0,0,-1,0, 1,0, 0,1
    db  0,0, 0,-1, 0,1, 1,0

    db  0,0,-1,0, 1,0, 0,-1
    db  0,0, 0,-1, 0,1,-1,0
; S-piece
tet_S:

    db  0,0, 1,0,-1,1, 0,1
    db  0,0, 0,1, 1,-1, 1,0

    db  0,0, 1,0,-1,1, 0,1
    db  0,0, 0,1, 1,-1, 1,0
; Z-piece
tet_Z:

    db  0,0,-1,0, 0,1, 1,1
    db  1,0, 1,1, 0,1, 0,2

    db  0,0,-1,0, 0,1, 1,1
    db  1,0, 1,1, 0,1, 0,2
; J-piece
tet_J:

    db  0,0,-1,0, 1,0, 1,1
    db  0,0, 0,-1, 0,1,-1,1

    db  0,0,-1,0, 1,0,-1,-1
    db  0,0, 0,-1, 0,1, 1,-1
; L-piece
tet_L:

    db  0,0,-1,0, 1,0,-1,1
    db  0,0, 0,-1, 0,1,-1,-1

    db  0,0,-1,0, 1,0, 1,-1
    db  0,0, 0,-1, 0,1, 1,1

; Colour for each piece (1-7)
tet_col:
    db 11,14,13,10,12,9,6

; Pointer table to piece data
tet_ptrs: dw tet_I, tet_O, tet_T, tet_S, tet_Z, tet_J, tet_L

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call tet_board_clear
    call tet_spawn

.frame:
    ; Key input (BIOS non-blocking)
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp al, 'a'
    je .mv_left
    cmp al, 'A'
    je .mv_left
    cmp al, 'd'
    je .mv_right
    cmp al, 'D'
    je .mv_right
    cmp al, 'w'
    je .rotate
    cmp al, 'W'
    je .rotate
    cmp al, 's'
    je .drop_fast
    cmp al, 'S'
    je .drop_fast
    jmp .no_key

.mv_left:
    dec word [cur_x]
    call tet_collide
    jnc .no_key
    inc word [cur_x]
    jmp .no_key

.mv_right:
    inc word [cur_x]
    call tet_collide
    jnc .no_key
    dec word [cur_x]
    jmp .no_key

.rotate:
    inc word [cur_rot]
    and word [cur_rot], 3
    call tet_collide
    jnc .no_key
    dec word [cur_rot]
    and word [cur_rot], 3
    jmp .no_key

.drop_fast:
    inc word [drop_cnt]
    add word [drop_cnt], 30

.no_key:
    inc word [drop_cnt]
    mov ax, [drop_spd]     ; Move o valor da memória para um registrador (ex: AX)
    cmp [drop_cnt], ax     ; Compara a memória com o valor que agora está no registrador

    jl .draw
    mov word [drop_cnt], 0

    ; Auto-drop one row
    inc word [cur_y]
    call tet_collide
    jnc .draw
    ; Can't move down — lock piece
    dec word [cur_y]
    call tet_lock
    call tet_clear_lines
    call tet_spawn
    ; Check game over
    call tet_collide
    jc .game_over

.draw:
    mov al, 0
    call gl16_clear
    call tet_draw_board
    call tet_draw_cur
    call tet_draw_ui
    call tet_delay
    jmp .frame

.game_over:
    mov al, 0
    call gl16_clear
    call tet_draw_board
    mov bx, 84
    mov dx, 96
    mov al, 12
    mov si, str_over
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16

.quit:
    call gl16_exit
    POP_ALL
ENDFN

; Get pointer to current piece rotation data -> SI
tet_piece_ptr:
    push ax
    push bx
    mov ax, [cur_type]
    shl ax, 1
    mov bx, ax
    mov si, [tet_ptrs + bx]
    ; Add rotation offset: each rotation = 8 bytes
    mov ax, [cur_rot]
    shl ax, 3
    add si, ax
    pop bx
    pop ax
    ret

; tet_collide: test if current piece collides (board or walls)
; Returns: CF=0 ok, CF=1 collision
tet_collide:
    push ax
    push bx
    push cx
    push dx
    push si
    call tet_piece_ptr
    mov cx, 4
.lp:
    push cx
    mov al, [si]            ; dx offset (signed byte)
    cbw
    add ax, [cur_x]
    mov bx, ax              ; bx = board col
    mov al, [si+1]
    cbw
    add ax, [cur_y]
    mov dx, ax              ; dx = board row
    ; Check bounds
    cmp bx, 0
    jl .hit
    cmp bx, TCOLS
    jge .hit
    cmp dx, TROWS
    jge .hit
    cmp dx, 0
    jl .skip              ; above top is ok
    ; Check board cell
    mov ax, dx
    mov cx, TCOLS
    mul cx
    add ax, bx
    mov di, ax
    cmp byte [board + di], 0
    jne .hit
.skip:
    add si, 2
    pop cx
    loop .lp
    ; No collision
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.hit:
    pop cx
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

; tet_lock: write current piece into board
tet_lock:
    push ax
    push bx
    push cx
    push dx
    push si
    call tet_piece_ptr
    mov al, [tet_col + bx]  ; use type for colour... fix below
    mov bx, [cur_type]
    mov al, [tet_col + bx]
    push ax
    call tet_piece_ptr
    mov cx, 4
.lp:
    push cx
    push ax
    mov al, [si]
    cbw
    add ax, [cur_x]
    mov bx, ax
    mov al, [si+1]
    cbw
    add ax, [cur_y]
    mov dx, ax
    ; Write to board if within bounds
    cmp dx, 0
    jl .skip2
    cmp bx, 0
    jl .skip2
    cmp bx, TCOLS
    jge .skip2
    cmp dx, TROWS
    jge .skip2
    mov ax, dx
    mov cx, TCOLS
    mul cx
    add ax, bx
    mov di, ax
    pop ax
    mov [board + di], al
    push ax
.skip2:
    add si, 2
    pop ax
    pop cx
    loop .lp
    pop ax
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; tet_clear_lines: scan rows, clear full ones, shift down
tet_clear_lines:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov dx, TROWS - 1
.scan:
    cmp dx, 0
    jl .done_cl
    ; Check if row dx is full
    mov ax, dx
    mov bx, TCOLS
    mul bx
    mov si, ax
    mov cx, TCOLS
    xor bx, bx
.chk:
    cmp byte [board + si + bx], 0
    je .not_full
    inc bx
    loop .chk
    ; Row is full — shift everything above down
    inc word [lines]
    add word [score], 100
    ; Speed up
    cmp word [drop_spd], 10
    jle .no_spdup
    dec word [drop_spd]
.no_spdup:
    ; Shift rows dx-1 downward to dx
    mov di, dx
.shift_dn:
    test di, di
    jz .shift_done
    ; Copy row di-1 to di
    mov ax, di
    mov cx, TCOLS
    mul cx
    mov bx, ax          ; bx = dest offset
    sub ax, TCOLS
    mov si, ax          ; si = src offset
    mov cx, TCOLS
.copy_row:
    mov al, [board + si]
    mov [board + bx], al
    inc si
    inc bx
    loop .copy_row
    dec di
    jmp .shift_dn
.shift_done:
    ; Clear top row
    xor si, si
    mov cx, TCOLS
    xor al, al
    rep stosb
    ; Don't decrement dx (re-check same row)
    jmp .scan
.not_full:
    dec dx
    jmp .scan
.done_cl:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

tet_spawn:
    mov ax, [next_type]
    mov [cur_type], ax
    mov word [cur_rot], 0
    mov word [cur_x], 4
    mov word [cur_y], 0
    ; Generate next piece
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    xor dx, dx
    mov bx, 7
    div bx
    mov [next_type], dx
    ret

tet_board_clear:
    push cx
    push si
    xor si, si
    mov cx, 200
    xor al, al
    mov di, board
    rep stosb
    pop si
    pop cx
    ret

tet_draw_board:
    push ax
    push bx
    push cx
    push dx
    push si
    mov dx, 0
.row:
    cmp dx, TROWS
    jge .done_db
    mov ax, dx
    mov cx, TCOLS
    mul cx
    mov si, ax
    xor bx, bx
.col:
    cmp bx, TCOLS
    jge .next_row
    mov al, [board + si + bx]
    test al, al
    jz .skip_db
    ; Draw cell
    push ax
    push bx
    push dx
    push si
    mov ax, bx
    mov cx, CELL
    mul cx
    add ax, PFX
    mov bx, ax
    mov ax, dx
    mul cx
    mov dx, ax
    pop si
    pop ax
    push si
    push ax
    ; Draw CELL x CELL block colour AL
    mov cx, CELL
.dr:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CELL - 1
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .dr
    pop ax
    pop si
    pop dx
    pop bx
    pop ax
.skip_db:
    inc si
    inc bx
    jmp .col
.next_row:
    inc dx
    jmp .row
.done_db:
    ; Draw playfield border
    xor bx, bx
    add bx, PFX - 1
    mov cx, PFX + TCOLS * CELL
    xor dx, dx
    mov al, 7
    call gl16_hline         ; top
    mov dx, TROWS * CELL
    call gl16_hline         ; bottom
    mov cx, TROWS * CELL
.lb:
    mov bx, PFX - 1
    mov dx, cx
    mov al, 7
    call gl16_pix
    mov bx, PFX + TCOLS * CELL
    call gl16_pix
    loop .lb
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

tet_draw_cur:
    push ax
    push bx
    push cx
    push dx
    push si
    call tet_piece_ptr
    mov bx, [cur_type]
    mov al, [tet_col + bx]
    push ax
    mov cx, 4
.dp:
    push cx
    mov al, [si]
    cbw
    add ax, [cur_x]
    push ax
    mov al, [si+1]
    cbw
    add ax, [cur_y]
    mov dx, ax
    pop ax
    mov bx, ax
    cmp bx, 0
    jl .skip_dp
    cmp bx, TCOLS
    jge .skip_dp
    cmp dx, 0
    jl .skip_dp
    cmp dx, TROWS
    jge .skip_dp
    ; Pixel coords
    push dx
    push bx
    mov ax, bx
    mov cx, CELL
    mul cx
    add ax, PFX
    mov bx, ax
    pop ax
    push bx
    mov cx, CELL
    mul cx
    mov dx, ax
    pop bx
    pop ax
    push ax
    push si
    ; al = colour (on stack)
    pop si
    pop ax
    push si
    push ax
    ; Draw block
    mov cx, CELL
.dr2:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CELL - 1
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .dr2
    pop ax
    pop si
.skip_dp:
    add si, 2
    pop cx
    loop .dp
    pop ax
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

tet_draw_ui:
    push ax
    push bx
    push dx
    push si
    mov bx, 4
    mov dx, 4
    mov al, 15
    mov si, str_title
    call gl16_text_gfx
    mov bx, 4
    mov dx, 20
    mov al, 14
    mov si, str_score
    call gl16_text_gfx
    mov ax, [score]
    mov si, sbuf
    call tet_itoa
    mov bx, 4
    mov dx, 30
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    mov bx, 4
    mov dx, 50
    mov al, 11
    mov si, str_lines
    call gl16_text_gfx
    mov ax, [lines]
    mov si, sbuf
    call tet_itoa
    mov bx, 4
    mov dx, 60
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    pop si
    pop dx
    pop bx
    pop ax
    ret

tet_itoa:
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, si
    add bx, 7
    mov byte [bx], 0
    dec bx
    test ax, ax
    jnz .d
    mov byte [bx], '0'
    dec bx
    jmp .dn
.d:
    test ax, ax
    jz .dn
    xor dx, dx
    mov cx, 10
    div cx
    add dl, '0'
    mov [bx], dl
    dec bx
    jmp .d
.dn:
    inc bx
    mov di, si
.cp:
    mov al, [bx]
    mov [di], al
    test al, al
    jz .cpd
    inc bx
    inc di
    jmp .cp
.cpd:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

tet_delay:
    push cx
    mov cx, 0x4000
.d:
    loop .d
    pop cx
    ret

%include "../opengl.asm"
