; =============================================================================
; MAZE.OVL  -  Maze Navigation  (KSDOS 16-bit)
; Navigate from start (top-left) to exit (bottom-right).
; WASD or arrow keys to move.  ESC = quit.
; Maze: 19 cols x 13 rows of cells, each 16px wide x 15px tall.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

MCOLS   equ 19
MROWS   equ 13
CW      equ 16
CH      equ 15
OX      equ 4           ; pixel origin X
OY      equ 4           ; pixel origin Y

STR str_title,  "MAZE  [WASD=move  ESC=quit]"
STR str_win,    "EXIT REACHED! Any key"
STR str_steps,  "Steps:"
STRBUF sbuf, 8

; Maze walls: MROWS*MCOLS bytes
; Bit 0 = right wall, Bit 1 = bottom wall
; Pre-built maze (hardcoded for reliability)
maze_walls:
    ; Row 0 (top row - always has top walls implied)
    db 0x01,0x00,0x01,0x02,0x00,0x01,0x02,0x00,0x01,0x00,0x01,0x02,0x01,0x00,0x01,0x02,0x00,0x01,0x02
    ; Row 1
    db 0x02,0x01,0x02,0x01,0x01,0x00,0x01,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x01,0x02,0x01
    ; Row 2
    db 0x01,0x02,0x01,0x02,0x02,0x01,0x02,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x00,0x01,0x02
    ; Row 3
    db 0x02,0x01,0x00,0x01,0x01,0x02,0x01,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x01,0x02,0x01
    ; Row 4
    db 0x01,0x02,0x01,0x00,0x02,0x01,0x00,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x00,0x02,0x01,0x02
    ; Row 5
    db 0x02,0x01,0x02,0x01,0x01,0x00,0x01,0x01,0x02,0x01,0x00,0x01,0x02,0x01,0x02,0x01,0x01,0x02,0x01
    ; Row 6
    db 0x01,0x02,0x01,0x00,0x02,0x01,0x02,0x00,0x01,0x02,0x01,0x02,0x01,0x00,0x01,0x02,0x00,0x01,0x02
    ; Row 7
    db 0x02,0x01,0x00,0x01,0x01,0x02,0x01,0x01,0x00,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x01,0x00,0x01
    ; Row 8
    db 0x01,0x00,0x01,0x02,0x02,0x01,0x00,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x00,0x01,0x02
    ; Row 9
    db 0x02,0x01,0x02,0x01,0x01,0x00,0x01,0x01,0x02,0x01,0x00,0x01,0x02,0x01,0x00,0x01,0x01,0x02,0x01
    ; Row 10
    db 0x01,0x02,0x01,0x00,0x02,0x01,0x02,0x00,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x00,0x02,0x01,0x02
    ; Row 11
    db 0x02,0x01,0x00,0x01,0x01,0x00,0x01,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x01,0x00,0x01
    ; Row 12 (bottom row)
    db 0x01,0x02,0x01,0x02,0x00,0x01,0x00,0x02,0x01,0x02,0x01,0x00,0x01,0x02,0x01,0x02,0x00,0x01,0x02

U16 plr_x, 0        ; player grid position
U16 plr_y, 0
U16 steps, 0

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    mov word [plr_x], 0
    mov word [plr_y], 0
    mov word [steps], 0

.frame:
    ; Input
    mov ah, 0x01
    int 0x16
    jz .draw
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    ; Move up
    cmp al, 'w'
    je .go_up
    cmp al, 'W'
    je .go_up
    cmp ah, 0x48
    je .go_up
    ; Move down
    cmp al, 's'
    je .go_dn
    cmp al, 'S'
    je .go_dn
    cmp ah, 0x50
    je .go_dn
    ; Move left
    cmp al, 'a'
    je .go_lt
    cmp al, 'A'
    je .go_lt
    cmp ah, 0x4B
    je .go_lt
    ; Move right
    cmp al, 'd'
    je .go_rt
    cmp al, 'D'
    je .go_rt
    cmp ah, 0x4D
    je .go_rt
    jmp .draw

.go_up:
    mov ax, [plr_y]
    test ax, ax
    jz .draw
    ; Check if top wall of current cell exists
    dec ax
    mov bx, [plr_x]
    call mz_wall_bottom  ; bottom of cell above = top of current
    jc .draw             ; wall exists, can't move
    dec word [plr_y]
    inc word [steps]
    jmp .chk_win

.go_dn:
    mov ax, [plr_y]
    cmp ax, MROWS - 1
    jge .draw
    mov bx, [plr_x]
    call mz_wall_bottom  ; bottom wall of current cell
    jc .draw
    inc word [plr_y]
    inc word [steps]
    jmp .chk_win

.go_lt:
    mov ax, [plr_y]
    mov bx, [plr_x]
    test bx, bx
    jz .draw
    ; Check right wall of cell to the left
    dec bx
    call mz_wall_right
    jc .draw
    dec word [plr_x]
    inc word [steps]
    jmp .chk_win

.go_rt:
    mov ax, [plr_y]
    mov bx, [plr_x]
    cmp bx, MCOLS - 1
    jge .draw
    call mz_wall_right   ; right wall of current cell
    jc .draw
    inc word [plr_x]
    inc word [steps]

.chk_win:
    mov ax, [plr_x]
    cmp ax, MCOLS - 1
    jne .draw
    mov ax, [plr_y]
    cmp ax, MROWS - 1
    jne .draw
    ; Win!
    call gl16_clear
    mov bx, 68
    mov dx, 96
    mov al, 10
    mov si, str_win
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    jmp .quit

.draw:
    mov al, 0
    call gl16_clear
    call mz_draw_maze
    call mz_draw_player
    ; Title
    mov bx, 4
    mov dx, MROWS * CH + 6
    mov al, 7
    mov si, str_title
    call gl16_text_gfx
    jmp .frame

.quit:
    call gl16_exit
    POP_ALL
ENDFN

; mz_wall_right: AX=row, BX=col -> CF=1 if right wall exists
mz_wall_right:
    push si
    push ax
    mov si, ax
    push bx
    mov ax, MCOLS
    mul si
    pop bx
    add ax, bx
    mov si, ax
    mov al, [maze_walls + si]
    and al, 0x01
    pop ax
    test al, al
    jnz .yes
    pop si
    clc
    ret
.yes:
    pop si
    stc
    ret

; mz_wall_bottom: AX=row, BX=col -> CF=1 if bottom wall exists
mz_wall_bottom:
    push si
    push ax
    mov si, ax
    push bx
    mov ax, MCOLS
    mul si
    pop bx
    add ax, bx
    mov si, ax
    mov al, [maze_walls + si]
    and al, 0x02
    pop ax
    test al, al
    jnz .yes
    pop si
    clc
    ret
.yes:
    pop si
    stc
    ret

mz_draw_maze:
    push ax
    push bx
    push cx
    push dx
    push si
    ; Draw all walls
    xor cx, cx          ; row
.row:
    cmp cx, MROWS
    jge .dm_done
    xor si, si          ; si = cell index base for this row
    push cx
    mov ax, cx
    mov bx, MCOLS
    mul bx
    mov si, ax
    xor bx, bx          ; col
.col:
    cmp bx, MCOLS
    jge .dm_next_row
    ; Pixel top-left of cell
    push bx
    push cx
    push si
    mov ax, bx
    mov cx, CW
    mul cx
    add ax, OX
    mov bx, ax          ; px
    mov ax, [esp+2]     ; row (cx on stack)
    push bx
    mov cx, CH
    mul cx
    add ax, OY
    mov dx, ax          ; py
    pop bx
    ; Top wall (always draw for row 0, or if coming from above)
    ; Draw top wall of row 0
    cmp word [esp+2], 0
    jne .right_wall
    mov cx, bx
    add cx, CW
    mov al, 7
    call gl16_hline

.right_wall:
    ; Right wall if bit 0 set
    mov si, [esp]       ; restore si
    pop si
    push si
    mov al, [maze_walls + si]
    test al, 0x01
    jz .bot_wall
    ; Draw right wall: vertical line at px+CW, from py to py+CH
    push dx
    push bx
    mov bx, bx
    add bx, CW
    mov cx, CH
    mov ax, dx
.rw_line:
    mov dx, ax
    cmp ax, 200
    jge .rw_done
    mov al, 7
    call gl16_pix
    inc ax
    loop .rw_line
.rw_done:
    pop bx
    pop dx

.bot_wall:
    ; Bottom wall if bit 1 set
    mov al, [maze_walls + si]
    test al, 0x02
    jz .no_bot
    mov cx, bx
    add cx, CW
    mov ax, dx
    add ax, CH
    mov dx, ax
    mov al, 7
    call gl16_hline
    sub dx, CH

.no_bot:
    pop si
    pop cx
    pop bx
    inc si
    inc bx
    jmp .col

.dm_next_row:
    pop cx
    inc cx
    jmp .row

.dm_done:
    ; Draw outer border
    xor bx, bx
    add bx, OX
    mov cx, OX + MCOLS * CW
    xor dx, dx
    add dx, OY
    mov al, 7
    call gl16_hline          ; top
    mov dx, OY + MROWS * CH
    call gl16_hline          ; bottom
    ; Left and right border
    mov cx, MROWS * CH + OY
.lb2:
    mov bx, OX
    mov dx, cx
    mov al, 7
    call gl16_pix
    mov bx, OX + MCOLS * CW
    call gl16_pix
    loop .lb2
    ; Exit marker (bright green at bottom-right)
    mov bx, OX + (MCOLS - 1) * CW + 2
    mov cx, bx
    add cx, CW - 4
    mov dx, OY + MROWS * CH - 4
    mov al, 10
    call gl16_hline
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

mz_draw_player:
    push ax
    push bx
    push cx
    push dx
    ; Draw player (yellow dot) in grid cell
    mov ax, [plr_x]
    mov cx, CW
    mul cx
    add ax, OX + CW/2 - 3
    mov bx, ax
    mov ax, [plr_y]
    mov cx, CH
    mul cx
    add ax, OY + CH/2 - 3
    mov dx, ax
    ; 6x6 yellow block
    mov cx, 6
.pr:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, 5
    mov al, 14
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .pr
    pop dx
    pop cx
    pop bx
    pop ax
    ret

%include "../opengl.asm"
