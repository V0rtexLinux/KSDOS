; =============================================================================
; INVADE.OVL  -  Space Invaders  (KSDOS 16-bit)
; LEFT/RIGHT to move, SPACE to shoot.  ESC = quit.
; 5 rows x 10 cols of aliens.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

ACOLS   equ 10
AROWS   equ 5
ACW     equ 24          ; alien cell width
ACH     equ 14          ; alien cell height
AOX     equ 20          ; alien origin X
AOY     equ 30          ; alien origin Y
SHIP_W  equ 16
SHIP_Y  equ 182
BLET_H equ 6            ; bullet height

STR str_title,   "INVADE  [<> move  SPC fire  ESC quit]"
STR str_score,   "Score:"
STR str_lives,   "Lives:"
STR str_win,     "EARTH SAVED! Any key"
STR str_lose,    "INVASION! Any key"
STRBUF sbuf, 8

; Alien map: AROWS * ACOLS bytes, 0=dead
STRBUF alien_map, AROWS * ACOLS

U16 ship_x,   150
I16 alien_ox, AOX       ; current alien X origin offset
I16 alien_oy, AOY
I16 alien_dx, 1         ; alien horizontal direction
U16 alien_cnt, AROWS * ACOLS
U16 alien_timer, 0
U16 alien_spd, 30

I16 blet_x, -1          ; player bullet X (-1 = inactive)
I16 blet_y, -1
U16 score, 0
U16 lives, 3
U16 lcg_seed, 0xDEAD

; Alien bullet (one at a time)
I16 abet_x, -1
I16 abet_y, -1

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call inv_init

.frame:
    ; Input
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp ah, 0x4B        ; LEFT
    jne .chk_r
    mov ax, [ship_x]
    cmp ax, 2
    jle .no_key
    sub word [ship_x], 3
    jmp .no_key
.chk_r:
    cmp ah, 0x4D        ; RIGHT
    jne .chk_sp
    mov ax, [ship_x]
    add ax, SHIP_W
    cmp ax, 318
    jge .no_key
    add word [ship_x], 3
    jmp .no_key
.chk_sp:
    cmp al, ' '
    jne .no_key
    ; Fire player bullet
    cmp word [blet_x], -1
    jne .no_key
    mov ax, [ship_x]
    add ax, SHIP_W / 2
    mov [blet_x], ax
    mov word [blet_y], SHIP_Y - 4
.no_key:

    ; Move player bullet
    cmp word [blet_y], -1
    je .alien_move
    sub word [blet_y], 4
    cmp word [blet_y], 2
    jge .chk_blet_hit
    mov word [blet_x], -1
    mov word [blet_y], -1
    jmp .alien_move

.chk_blet_hit:
    call inv_check_blet

    ; Move alien bullet
.alien_move:
    cmp word [abet_y], -1
    je .alien_step
    add word [abet_y], 3
    cmp word [abet_y], 195
    jl .chk_abet_ship
    mov word [abet_x], -1
    mov word [abet_y], -1
    jmp .alien_step
.chk_abet_ship:
    mov ax, [abet_x]
    cmp ax, [ship_x]
    jl .alien_step
    mov bx, [ship_x]
    add bx, SHIP_W
    cmp ax, bx
    jg .alien_step
    mov ax, [abet_y]
    cmp ax, SHIP_Y
    jl .alien_step
    ; Ship hit
    dec word [lives]
    mov word [abet_x], -1
    mov word [abet_y], -1
    cmp word [lives], 0
    jle .lose

    ; Move aliens horizontally
.alien_step:
    inc word [alien_timer]
    cmp word [alien_timer], [alien_spd]
    jl .draw
    mov word [alien_timer], 0
    mov ax, [alien_dx]
    add [alien_ox], ax
    ; Check if edge reached
    mov bx, [alien_ox]
    cmp bx, 2
    jge .chk_right
    neg word [alien_dx]
    add word [alien_oy], ACH / 2
    mov word [alien_ox], 2
    jmp .alien_fire
.chk_right:
    add bx, ACOLS * ACW
    cmp bx, 318
    jle .alien_fire
    neg word [alien_dx]
    add word [alien_oy], ACH / 2
    jmp .alien_fire

.alien_fire:
    ; Random alien fires
    cmp word [abet_x], -1
    jne .draw
    call inv_random_fire

.draw:
    mov al, 0
    call gl16_clear
    ; Ground line
    mov bx, 0
    mov cx, 319
    mov dx, SHIP_Y + SHIP_W / 2
    mov al, 2
    call gl16_hline
    ; Draw aliens
    call inv_draw_aliens
    ; Draw ship
    call inv_draw_ship
    ; Draw player bullet
    cmp word [blet_x], -1
    je .draw_abet
    mov bx, [blet_x]
    mov dx, [blet_y]
    mov cx, BLET_H
.pblet:
    mov al, 15
    call gl16_pix
    inc dx
    loop .pblet
    ; Draw alien bullet
.draw_abet:
    cmp word [abet_x], -1
    je .draw_ui
    mov bx, [abet_x]
    mov dx, [abet_y]
    mov cx, BLET_H
.ablet:
    mov al, 12
    call gl16_pix
    inc dx
    loop .ablet

.draw_ui:
    ; Check win
    cmp word [alien_cnt], 0
    je .win
    ; Check aliens reached ground
    mov ax, [alien_oy]
    add ax, AROWS * ACH
    cmp ax, SHIP_Y - 4
    jge .lose
    call inv_delay
    jmp .frame

.win:
    mov al, 0
    call gl16_clear
    mov bx, 56
    mov dx, 96
    mov al, 10
    mov si, str_win
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    jmp .quit

.lose:
    mov al, 0
    call gl16_clear
    mov bx, 68
    mov dx, 96
    mov al, 12
    mov si, str_lose
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16

.quit:
    call gl16_exit
    POP_ALL
ENDFN

inv_init:
    push cx
    push di
    mov cx, AROWS * ACOLS
    mov di, alien_map
    mov al, 1
    rep stosb
    mov word [alien_cnt], AROWS * ACOLS
    mov word [alien_ox], AOX
    mov word [alien_oy], AOY
    mov word [alien_dx], 1
    pop di
    pop cx
    ret

inv_draw_aliens:
    push ax
    push bx
    push cx
    push dx
    push si
    xor si, si
    xor cx, cx          ; row
.row:
    cmp cx, AROWS
    jge .da_done
    xor bx, bx          ; col
.col:
    cmp bx, ACOLS
    jge .da_next
    cmp byte [alien_map + si], 0
    je .da_skip
    ; Compute pixel X,Y
    push bx
    push cx
    push si
    mov ax, bx
    mov dx, ACW
    mul dx
    add ax, [alien_ox]
    mov bx, ax           ; px
    mov ax, cx
    mul dx
    add ax, [alien_oy]
    mov dx, ax           ; py
    ; Alien colour: alternate red/cyan/yellow per row
    mov ax, cx
    and ax, 3
    cmp ax, 0
    je .col_r
    cmp ax, 1
    je .col_c
    cmp ax, 2
    je .col_y
    mov al, 13
    jmp .draw_al
.col_r: mov al, 12
    jmp .draw_al
.col_c: mov al, 11
    jmp .draw_al
.col_y: mov al, 14
.draw_al:
    ; Draw simple alien shape (rectangle + dots)
    push ax
    push dx
    push bx
    mov cx, ACH - 2
.arow:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, ACW - 4
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .arow
    pop bx
    pop dx
    pop ax
    pop si
    pop cx
    pop bx
.da_skip:
    inc si
    inc bx
    jmp .col
.da_next:
    inc cx
    jmp .row
.da_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

inv_draw_ship:
    push ax
    push bx
    push cx
    push dx
    mov bx, [ship_x]
    mov dx, SHIP_Y
    mov cx, SHIP_W / 2
.srow:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, SHIP_W - 1
    mov al, 10
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .srow
    pop dx
    pop cx
    pop bx
    pop ax
    ret

inv_check_blet:
    push ax
    push bx
    push cx
    push dx
    push si
    ; Check each alien
    xor si, si
    xor cx, cx
.row:
    cmp cx, AROWS
    jge .cb_done
    xor bx, bx
.col:
    cmp bx, ACOLS
    jge .cb_next
    cmp byte [alien_map + si], 0
    je .cb_skip
    ; Alien px
    push bx
    push cx
    mov ax, bx
    mov dx, ACW
    mul dx
    add ax, [alien_ox]
    mov bx, ax
    mov ax, cx
    mul dx
    add ax, [alien_oy]
    mov dx, ax
    ; Check bullet in alien rect
    mov ax, [blet_x]
    cmp ax, bx
    jl .cb_no
    add bx, ACW
    cmp ax, bx
    jg .cb_no
    sub bx, ACW
    mov ax, [blet_y]
    cmp ax, dx
    jl .cb_no
    add dx, ACH
    cmp ax, dx
    jg .cb_no
    ; Hit!
    pop cx
    pop bx
    mov byte [alien_map + si], 0
    dec word [alien_cnt]
    add word [score], 10
    mov word [blet_x], -1
    mov word [blet_y], -1
    ; Speed up aliens
    cmp word [alien_spd], 5
    jle .cb_done
    dec word [alien_spd]
    jmp .cb_done
.cb_no:
    pop cx
    pop bx
.cb_skip:
    inc si
    inc bx
    jmp .col
.cb_next:
    inc cx
    jmp .row
.cb_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

inv_random_fire:
    push ax
    push bx
    push cx
    ; LCG random to pick a column
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    xor dx, dx
    mov bx, ACOLS
    div bx
    mov bx, dx          ; random col
    ; Find lowest alive alien in that column
    mov cx, AROWS
    dec cx
    push bx
.fi:
    push cx
    push bx
    mov ax, cx
    mov dx, ACOLS
    mul dx
    add ax, bx
    mov si, ax
    cmp byte [alien_map + si], 0
    je .fi_skip
    ; This alien fires
    mov ax, bx
    mov dx, ACW
    mul dx
    add ax, [alien_ox]
    add ax, ACW / 2
    mov [abet_x], ax
    mov ax, cx
    mul dx
    add ax, [alien_oy]
    add ax, ACH
    mov [abet_y], ax
    pop bx
    pop cx
    pop bx
    pop cx
    pop bx
    pop ax
    ret
.fi_skip:
    pop bx
    pop cx
    dec cx
    cmp cx, 0
    jge .fi
    pop bx
    pop cx
    pop bx
    pop ax
    ret

inv_delay:
    push cx
    mov cx, 0x1800
.d:
    loop .d
    pop cx
    ret

%include "../opengl.asm"
