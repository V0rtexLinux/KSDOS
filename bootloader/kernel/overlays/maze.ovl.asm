; =============================================================================
; MAZE.OVL  -  Maze Navigation (Corrigido)
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"
MCOLS   equ 19
MROWS   equ 13
CW      equ 16
CH      equ 15
OX      equ 4
OY      equ 4

STR str_title,  "MAZE  [WASD=move  ESC=quit]"
STR str_win,    "EXIT REACHED! Any key"
STRBUF sbuf, 8

maze_walls:
    db 0x01,0x00,0x01,0x02,0x00,0x01,0x02,0x00,0x01,0x00,0x01,0x02,0x01,0x00,0x01,0x02,0x00,0x01,0x02
    db 0x02,0x01,0x02,0x01,0x01,0x00,0x01,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x01,0x02,0x01
    db 0x01,0x02,0x01,0x02,0x02,0x01,0x02,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x00,0x01,0x02
    db 0x02,0x01,0x00,0x01,0x01,0x02,0x01,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x01,0x02,0x01
    db 0x01,0x02,0x01,0x00,0x02,0x01,0x00,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x00,0x02,0x01,0x02
    db 0x02,0x01,0x02,0x01,0x01,0x00,0x01,0x01,0x02,0x01,0x00,0x01,0x02,0x01,0x02,0x01,0x01,0x02,0x01
    db 0x01,0x02,0x01,0x00,0x02,0x01,0x02,0x00,0x01,0x02,0x01,0x02,0x01,0x00,0x01,0x02,0x00,0x01,0x02
    db 0x02,0x01,0x00,0x01,0x01,0x02,0x01,0x01,0x00,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x01,0x00,0x01
    db 0x01,0x00,0x01,0x02,0x02,0x01,0x00,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x00,0x01,0x02
    db 0x02,0x01,0x02,0x01,0x01,0x00,0x01,0x01,0x02,0x01,0x00,0x01,0x02,0x01,0x00,0x01,0x01,0x02,0x01
    db 0x01,0x02,0x01,0x00,0x02,0x01,0x02,0x00,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x00,0x02,0x01,0x02
    db 0x02,0x01,0x00,0x01,0x01,0x00,0x01,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x02,0x01,0x01,0x00,0x01
    db 0x01,0x02,0x01,0x02,0x00,0x01,0x00,0x02,0x01,0x02,0x01,0x00,0x01,0x02,0x01,0x02,0x00,0x01,0x02

plr_x: dw 0
plr_y: dw 0

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    mov word [plr_x], 0
    mov word [plr_y], 0

.frame:
    mov ah, 0x01
    int 0x16
    jz .draw
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit

    cmp al, 'w'
    je .go_up
    cmp al, 's'
    je .go_dn
    cmp al, 'a'
    je .go_lt
    cmp al, 'd'
    je .go_rt
    jmp .draw

.go_up:
    mov ax, [plr_y]
    test ax, ax
    jz .draw
    mov bx, [plr_x]
    dec ax
    call mz_wall_bottom
    jc .draw
    dec word [plr_y]
    jmp .chk_win

.go_dn:
    mov ax, [plr_y]
    cmp ax, MROWS - 1
    jge .draw
    mov bx, [plr_x]
    call mz_wall_bottom
    jc .draw
    inc word [plr_y]
    jmp .chk_win

.go_lt:
    mov bx, [plr_x]
    test bx, bx
    jz .draw
    mov ax, [plr_y]
    dec bx
    call mz_wall_right
    jc .draw
    dec word [plr_x]
    jmp .chk_win

.go_rt:
    mov bx, [plr_x]
    cmp bx, MCOLS - 1
    jge .draw
    mov ax, [plr_y]
    call mz_wall_right
    jc .draw
    inc word [plr_x]

.chk_win:
    mov ax, [plr_x]
    cmp ax, MCOLS - 1
    jne .draw
    mov ax, [plr_y]
    cmp ax, MROWS - 1
    jne .draw
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
    jmp .frame

.quit:
    call gl16_exit
    POP_ALL
ENDFN

mz_wall_right:
    push ax
    mov ax, MCOLS
    imul ax, [esp+6] ; Pega o parâmetro 'row' da stack
    add ax, bx       ; Soma 'col'
    mov si, ax
    mov al, [maze_walls + si]
    pop ax
    test al, 0x01
    jnz .yes
    clc
    ret
.yes:
    stc
    ret


mz_wall_bottom:
    push si
    mov si, MCOLS
    imul si, ax
    add si, bx
    mov al, [maze_walls + si]
    and al, 0x02
    pop si
    test al, al
    jnz .yes
    clc
    ret
.yes:
    stc
    ret

mz_draw_maze:
    pusha
    xor cx, cx          ; CX = linha (row)
.row:
    cmp cx, MROWS
    jge .dm_done
    xor bx, bx          ; BX = coluna (col)
.col:
    cmp bx, MCOLS
    jge .dm_next_row

    ; Calcular coordenadas (SI=px, DI=py)
    mov ax, bx
    imul ax, CW
    add ax, OX
    mov si, ax          ; px
    mov ax, cx
    imul ax, CH
    add ax, OY
    mov di, ax          ; py

    ; Obter índice da célula atual (row * MCOLS + col)
    mov ax, cx
    imul ax, MCOLS
    add ax, bx
    push bx
    mov bx, ax
    mov al, [maze_walls + bx] ; Lê bits de parede
    pop bx

    ; Desenhar Parede Direita (bit 0)
    test al, 0x01
    jz .bot
    push si
    add si, CW
    push di
    add di, CH
    mov al, 7
    call gl16_vline    ; Linha vertical na direita
    pop di
    pop si
.bot:
    ; Desenhar Parede Inferior (bit 1)
    test al, 0x02
    jz .next_cell
    push si
    push di
    add di, CH
    mov cx, CW
    mov al, 7
    call gl16_hline    ; Linha horizontal na base
    pop di
    pop si

.next_cell:
    inc bx
    jmp .col
.dm_next_row:
    inc cx
    jmp .row
.dm_done:
    popa
    ret

mz_draw_player:
    pusha
    ; Posição X: (plr_x * CW) + OX + (CW/2 - 3)
    mov ax, [plr_x]
    imul ax, CW
    add ax, OX + 5
    mov bx, ax

    ; Posição Y: (plr_y * CH) + OY + (CH/2 - 3)
    mov ax, [plr_y]
    imul ax, CH
    add ax, OY + 4
    mov dx, ax

    ; Desenha um bloco 6x6 (usando loop para linhas)
    mov cx, 6
.draw_loop:
    push cx
    push dx
    mov cx, bx
    add cx, 5
    mov al, 14         ; Cor amarela
    call gl16_hline
    pop dx
    inc dx
    pop cx
    loop .draw_loop

    popa
    ret

%include "../opengl.asm"
