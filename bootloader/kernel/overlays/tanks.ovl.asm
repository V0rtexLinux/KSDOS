; =============================================================================
; TANKS.OVL  -  Tank Battle  (KSDOS 16-bit)
; WASD=move, SPACE=fire.  Destroy all enemy tanks.  ESC=quit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

TANK_W  equ 14
TANK_H  equ 12
MAX_ENEMIES equ 4
BLET_SPD equ 5

STR str_title,  "TANKS  [WASD=move SPC=fire ESC=quit]"
STR str_score,  "Score:"
STR str_win,    "ALL ENEMIES DESTROYED! Any key"
STR str_lose,   "YOUR TANK DESTROYED! Any key"
STRBUF sbuf, 8

; Player tank
I16 ptank_x, 150
I16 ptank_y, 160
U16 ptank_dir, 0     ; 0=right 1=left 2=up 3=down
U16 ptank_alive, 1
; Player bullet
I16 pblet_x, -1
I16 pblet_y, -1
I16 pblet_dx, 0
I16 pblet_dy, 0

; Enemy tanks (x,y,dir,alive,shoot_timer)
WORDBUF etank_x, MAX_ENEMIES
WORDBUF etank_y, MAX_ENEMIES
WORDBUF etank_dir, MAX_ENEMIES
WORDBUF etank_alive, MAX_ENEMIES
WORDBUF etank_stimer, MAX_ENEMIES
; Enemy bullets (one per tank)
WORDBUF eblet_x, MAX_ENEMIES
WORDBUF eblet_y, MAX_ENEMIES
WORDBUF eblet_dx, MAX_ENEMIES
WORDBUF eblet_dy, MAX_ENEMIES

U16 score, 0
U16 enemies_left, MAX_ENEMIES
U16 lcg_seed, 0x9ABC
U16 move_timer, 0

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call tnk_init

.frame:
    ; Input
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp al, 'w'
    je .go_up
    cmp al, 'W'
    je .go_up
    cmp al, 's'
    je .go_dn
    cmp al, 'S'
    je .go_dn
    cmp al, 'a'
    je .go_lt
    cmp al, 'A'
    je .go_lt
    cmp al, 'd'
    je .go_rt
    cmp al, 'D'
    je .go_rt
    cmp al, ' '
    je .fire
    jmp .no_key

.go_up:
    mov word [ptank_dir], 2
    mov ax, [ptank_y]
    cmp ax, 4
    jle .no_key
    sub word [ptank_y], 3
    jmp .no_key
.go_dn:
    mov word [ptank_dir], 3
    mov ax, [ptank_y]
    add ax, TANK_H
    cmp ax, 195
    jge .no_key
    add word [ptank_y], 3
    jmp .no_key
.go_lt:
    mov word [ptank_dir], 1
    mov ax, [ptank_x]
    cmp ax, 4
    jle .no_key
    sub word [ptank_x], 3
    jmp .no_key
.go_rt:
    mov word [ptank_dir], 0
    mov ax, [ptank_x]
    add ax, TANK_W
    cmp ax, 315
    jge .no_key
    add word [ptank_x], 3
    jmp .no_key
.fire:
    cmp word [pblet_x], -1
    jne .no_key
    ; Spawn bullet based on direction
    mov ax, [ptank_x]
    add ax, TANK_W / 2
    mov [pblet_x], ax
    mov ax, [ptank_y]
    add ax, TANK_H / 2
    mov [pblet_y], ax
    cmp word [ptank_dir], 0
    je .fd_rt
    cmp word [ptank_dir], 1
    je .fd_lt
    cmp word [ptank_dir], 2
    je .fd_up
    ; Down
    mov word [pblet_dx], 0
    mov word [pblet_dy], BLET_SPD
    jmp .no_key
.fd_rt:
    mov word [pblet_dx], BLET_SPD
    mov word [pblet_dy], 0
    jmp .no_key
.fd_lt:
    mov word [pblet_dx], -BLET_SPD
    mov word [pblet_dy], 0
    jmp .no_key
.fd_up:
    mov word [pblet_dx], 0
    mov word [pblet_dy], -BLET_SPD

.no_key:
    ; Move player bullet
    cmp word [pblet_x], -1
    je .enemy_update
    mov ax, [pblet_x]
    add ax, [pblet_dx]
    mov [pblet_x], ax
    mov ax, [pblet_y]
    add ax, [pblet_dy]
    mov [pblet_y], ax
    ; Check bounds
    cmp word [pblet_x], 2
    jl .pblet_dead
    cmp word [pblet_x], 317
    jg .pblet_dead
    cmp word [pblet_y], 2
    jl .pblet_dead
    cmp word [pblet_y], 197
    jg .pblet_dead
    call tnk_check_pblet
    jmp .enemy_update
.pblet_dead:
    mov word [pblet_x], -1
    mov word [pblet_y], -1

.enemy_update:
    inc word [move_timer]
    cmp word [move_timer], 20
    jl .draw
    mov word [move_timer], 0
    call tnk_move_enemies
    call tnk_enemy_shoot
    call tnk_check_eblets

.draw:
    mov al, 1
    call gl16_clear
    call tnk_draw_player
    call tnk_draw_enemies
    call tnk_draw_bullets
    ; UI
    mov bx, 4
    mov dx, 4
    mov al, 7
    mov si, str_title
    call gl16_text_gfx
    ; Win check
    cmp word [enemies_left], 0
    jne .lose_chk
    mov al, 0
    call gl16_clear
    mov bx, 36
    mov dx, 96
    mov al, 10
    mov si, str_win
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    jmp .quit
.lose_chk:
    cmp word [ptank_alive], 0
    jne .frame
    mov al, 0
    call gl16_clear
    mov bx, 56
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

tnk_init:
    ; Place enemies
    mov word [etank_x], 20
    mov word [etank_y], 20
    mov word [etank_alive], 1
    mov word [etank_dir], 3
    mov word [etank_x + 2], 200
    mov word [etank_y + 2], 20
    mov word [etank_alive + 2], 1
    mov word [etank_dir + 2], 3
    mov word [etank_x + 4], 20
    mov word [etank_y + 4], 80
    mov word [etank_alive + 4], 1
    mov word [etank_dir + 4], 0
    mov word [etank_x + 6], 200
    mov word [etank_y + 6], 80
    mov word [etank_alive + 6], 1
    mov word [etank_dir + 6], 1
    ; Init enemy bullets to off
    mov cx, MAX_ENEMIES
    xor si, si
.cl:
    mov word [eblet_x + si], -1
    add si, 2
    loop .cl
    ; Init shoot timers randomly
    mov word [etank_stimer], 15
    mov word [etank_stimer + 2], 25
    mov word [etank_stimer + 4], 10
    mov word [etank_stimer + 6], 35
    ret

tnk_draw_tank:
    ; BX=x, DX=y, AL=colour
    push ax
    push bx
    push cx
    push dx
    push si
    mov si, TANK_H
.tr:
    push si
    push dx
    push bx
    mov cx, bx
    add cx, TANK_W - 1
    call gl16_hline
    pop bx
    pop dx
    pop si
    inc dx
    dec si
    jnz .tr
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

tnk_draw_player:
    cmp word [ptank_alive], 0
    je .dp_done
    mov bx, [ptank_x]
    mov dx, [ptank_y]
    mov al, 10
    call tnk_draw_tank
.dp_done:
    ret

tnk_draw_enemies:
    push cx
    push si
    mov cx, MAX_ENEMIES
    xor si, si
.de:
    cmp word [etank_alive + si], 0
    je .de_skip
    push cx
    push si
    mov bx, [etank_x + si]
    mov dx, [etank_y + si]
    mov al, 12
    call tnk_draw_tank
    pop si
    pop cx
.de_skip:
    add si, 2
    loop .de
    pop si
    pop cx
    ret

tnk_draw_bullets:
    push ax
    push bx
    push cx
    push dx
    ; Player bullet
    cmp word [pblet_x], -1
    je .eb
    mov bx, [pblet_x]
    mov dx, [pblet_y]
    mov al, 15
    call gl16_pix
    inc bx
    call gl16_pix
    dec bx
    inc dx
    call gl16_pix
.eb:
    ; Enemy bullets
    mov cx, MAX_ENEMIES
    xor si, si
.ebl:
    cmp word [eblet_x + si], -1
    je .ebl_skip
    mov bx, [eblet_x + si]
    mov dx, [eblet_y + si]
    mov al, 14
    call gl16_pix
    inc bx
    call gl16_pix
.ebl_skip:
    add si, 2
    loop .ebl
    pop dx
    pop cx
    pop bx
    pop ax
    ret

tnk_check_pblet:
    push ax
    push bx
    push cx
    push si
    mov cx, MAX_ENEMIES
    xor si, si
.cp:
    cmp word [etank_alive + si], 0
    je .cp_skip
    mov ax, [pblet_x]
    cmp ax, [etank_x + si]
    jl .cp_skip
    mov bx, [etank_x + si]
    add bx, TANK_W
    cmp ax, bx
    jg .cp_skip
    mov ax, [pblet_y]
    cmp ax, [etank_y + si]
    jl .cp_skip
    mov bx, [etank_y + si]
    add bx, TANK_H
    cmp ax, bx
    jg .cp_skip
    ; Hit!
    mov word [etank_alive + si], 0
    dec word [enemies_left]
    add word [score], 100
    mov word [pblet_x], -1
    mov word [pblet_y], -1
    pop si
    pop cx
    pop bx
    pop ax
    ret
.cp_skip:
    add si, 2
    loop .cp
    pop si
    pop cx
    pop bx
    pop ax
    ret

tnk_move_enemies:
    push ax
    push bx
    push cx
    push si
    mov cx, MAX_ENEMIES
    xor si, si
.me:
    cmp word [etank_alive + si], 0
    je .me_skip
    ; Move based on direction
    cmp word [etank_dir + si], 0
    jne .me_lt
    add word [etank_x + si], 2
    mov ax, [etank_x + si]
    add ax, TANK_W
    cmp ax, 316
    jl .me_skip
    mov word [etank_dir + si], 1
    jmp .me_skip
.me_lt:
    cmp word [etank_dir + si], 1
    jne .me_up
    sub word [etank_x + si], 2
    cmp word [etank_x + si], 4
    jg .me_skip
    mov word [etank_dir + si], 0
    jmp .me_skip
.me_up:
    cmp word [etank_dir + si], 2
    jne .me_dn
    sub word [etank_y + si], 2
    cmp word [etank_y + si], 16
    jg .me_skip
    mov word [etank_dir + si], 3
    jmp .me_skip
.me_dn:
    add word [etank_y + si], 2
    mov ax, [etank_y + si]
    add ax, TANK_H
    cmp ax, 100
    jl .me_skip
    mov word [etank_dir + si], 2
.me_skip:
    add si, 2
    loop .me
    pop si
    pop cx
    pop bx
    pop ax
    ret

tnk_enemy_shoot:
    push ax
    push bx
    push cx
    push si
    mov cx, MAX_ENEMIES
    xor si, si
.es:
    cmp word [etank_alive + si], 0
    je .es_skip
    inc word [etank_stimer + si]
    cmp word [etank_stimer + si], 40
    jl .es_skip
    mov word [etank_stimer + si], 0
    ; Fire bullet toward player
    cmp word [eblet_x + si], -1
    jne .es_skip
    mov ax, [etank_x + si]
    add ax, TANK_W / 2
    mov [eblet_x + si], ax
    mov ax, [etank_y + si]
    add ax, TANK_H / 2
    mov [eblet_y + si], ax
    ; Direction toward player
    mov ax, [ptank_x]
    sub ax, [etank_x + si]
    cmp ax, 0
    jge .es_rt
    ; Shoot left
    push si
    mov si, si
    mov word [eblet_dx + si], -BLET_SPD
    mov word [eblet_dy + si], 0
    pop si
    jmp .es_skip
.es_rt:
    mov word [eblet_dx + si], BLET_SPD
    mov word [eblet_dy + si], 0
.es_skip:
    add si, 2
    loop .es
    pop si
    pop cx
    pop bx
    pop ax
    ret

tnk_check_eblets:
    push ax
    push bx
    push cx
    push si
    mov cx, MAX_ENEMIES
    xor si, si
.ce:
    cmp word [eblet_x + si], -1
    je .ce_skip
    ; Move bullet
    mov ax, [eblet_dx + si]
    add [eblet_x + si], ax
    mov ax, [eblet_dy + si]
    add [eblet_y + si], ax
    ; Bounds
    cmp word [eblet_x + si], 2
    jl .ebdead
    cmp word [eblet_x + si], 317
    jg .ebdead
    cmp word [eblet_y + si], 2
    jl .ebdead
    cmp word [eblet_y + si], 197
    jg .ebdead
    ; Check player hit
    cmp word [ptank_alive], 0
    je .ce_skip
    mov ax, [eblet_x + si]
    cmp ax, [ptank_x]
    jl .ce_skip
    mov bx, [ptank_x]
    add bx, TANK_W
    cmp ax, bx
    jg .ce_skip
    mov ax, [eblet_y + si]
    cmp ax, [ptank_y]
    jl .ce_skip
    mov bx, [ptank_y]
    add bx, TANK_H
    cmp ax, bx
    jg .ce_skip
    ; Player hit!
    mov word [ptank_alive], 0
    mov word [eblet_x + si], -1
    jmp .ce_skip
.ebdead:
    mov word [eblet_x + si], -1
.ce_skip:
    add si, 2
    loop .ce
    pop si
    pop cx
    pop bx
    pop ax
    ret

%include "../opengl.asm"
