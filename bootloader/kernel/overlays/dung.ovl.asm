; =============================================================================
; DUNG.OVL  -  Dungeon Crawler  (KSDOS 16-bit)
; Explore the dungeon, fight enemies, find the exit.
; WASD=move, SPACE=attack, ESC=quit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

MCOLS   equ 20
MROWS   equ 15
CELL    equ 14
MAX_ENE equ 6

STR str_title, "DUNGEON  [WASD=move SPC=attack ESC=quit]"
STR str_hp,    "HP:"
STR str_atk,   "ATK:"
STR str_floor, "Floor:"
STR str_dead,  "YOU DIED! Any key"
STR str_win,   "ESCAPED DUNGEON! Any key"
STRBUF sbuf, 4

; Tile types
T_EMPTY equ 0
T_FLOOR equ 1
T_WALL  equ 2
T_EXIT  equ 3
T_CHEST equ 4

; Map
STRBUF mapdata, MROWS * MCOLS

; Player
I16 px, 2
I16 py, 2
U16 php, 15
U16 patk, 3
U16 pfloor, 1

; Enemies: x,y,hp,dir,alive
WORDBUF ex, MAX_ENE
WORDBUF ey, MAX_ENE
WORDBUF ehp, MAX_ENE
WORDBUF edir, MAX_ENE
WORDBUF ealive, MAX_ENE

U16 exit_x, 0
U16 exit_y, 0
U16 lcg_seed, 0xC0DE
U16 ene_timer, 0
U16 attack_flash, 0

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call dg_gen_floor

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
    cmp ah, 0x48
    je .go_up
    cmp al, 's'
    je .go_dn
    cmp al, 'S'
    je .go_dn
    cmp ah, 0x50
    je .go_dn
    cmp al, 'a'
    je .go_lt
    cmp al, 'A'
    je .go_lt
    cmp ah, 0x4B
    je .go_lt
    cmp al, 'd'
    je .go_rt
    cmp al, 'D'
    je .go_rt
    cmp ah, 0x4D
    je .go_rt
    cmp al, ' '
    je .attack
    jmp .no_key

.go_up:
    mov ax, [py]
    dec ax
    call dg_try_move_y
    jmp .no_key
.go_dn:
    mov ax, [py]
    inc ax
    call dg_try_move_y
    jmp .no_key
.go_lt:
    mov ax, [px]
    dec ax
    call dg_try_move_x
    jmp .no_key
.go_rt:
    mov ax, [px]
    inc ax
    call dg_try_move_x
    jmp .no_key

.attack:
    ; Attack all adjacent enemies
    call dg_attack_adjacent
    mov word [attack_flash], 3

.no_key:
    ; Move enemies
    inc word [ene_timer]
    cmp word [ene_timer], 4
    jl .draw
    mov word [ene_timer], 0
    call dg_move_enemies

    ; Fade attack flash
    cmp word [attack_flash], 0
    je .draw
    dec word [attack_flash]

.draw:
    ; Check death
    cmp word [php], 0
    jle .dead

    mov al, 0
    call gl16_clear
    call dg_draw_map
    call dg_draw_enemies
    call dg_draw_player
    call dg_draw_ui

    ; Attack flash effect
    cmp word [attack_flash], 0
    je .frame
    ; Flash the attack range in yellow
    mov ax, [px]
    mov cx, CELL
    mul cx
    mov bx, ax
    mov ax, [py]
    mul cx
    sub ax, CELL
    mov dx, ax
    mov cx, 3
.flash_y:
    push cx
    push bx
    push dx
    mov cx, bx
    add cx, CELL - 1
    mov al, 14
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .flash_y
    ; Horizontal flash
    mov ax, [px]
    dec ax
    mov cx, CELL
    mul cx
    mov bx, ax
    mov ax, [py]
    mul cx
    mov dx, ax
    mov cx, 3
.flash_x:
    push cx
    push bx
    push dx
    mov cx, bx
    add cx, 3 * CELL - 1
    mov al, 14
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .flash_x

    jmp .frame

.dead:
    mov al, 0
    call gl16_clear
    mov bx, 72
    mov dx, 96
    mov al, 12
    mov si, str_dead
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    jmp .quit

.quit:
    call gl16_exit
    POP_ALL
ENDFN

dg_gen_floor:
    push ax
    push bx
    push cx
    push di
    ; Fill with walls
    mov cx, MROWS * MCOLS
    mov di, mapdata
    mov al, T_WALL
    rep stosb
    ; Carve 2 rooms
    ; Room 1: top-left
    mov bx, 1
    mov di, 1
    mov cx, 9
    mov ax, 8
    call dg_carve_room
    ; Room 2: bottom-right
    mov bx, 11
    mov di, 7
    mov cx, 8
    mov ax, 7
    call dg_carve_room
    ; Corridor connecting them
    mov bx, 9
    mov di, 4
    mov cx, 2
    mov ax, 4
    call dg_carve_room
    ; Place exit
    call dg_rand
    xor dx, dx
    push ax
    mov ax, 8
    mov bx, 8
    mul bx
    pop bx
    div bx
    ; Simplified: place exit at fixed spot + random offset
    mov word [exit_x], 15
    mov word [exit_y], 10
    mov ax, [exit_y]
    mov bx, MCOLS
    mul bx
    add ax, [exit_x]
    mov byte [mapdata + ax], T_EXIT
    ; Player start
    mov word [px], 2
    mov word [py], 2
    ; Spawn enemies
    call dg_spawn_enemies
    pop di
    pop cx
    pop bx
    pop ax
    ret

; dg_carve_room: BX=x, DI=y, CX=w, AX=h
dg_carve_room:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov dx, di          ; row = y
    push cx             ; save width
    push ax             ; save height counter
.cr_row:
    pop ax
    dec ax
    push ax
    cmp ax, 0
    jl .cr_done
    ; Fill CX cells at row DX starting at col BX
    push bx
    push dx
    mov ax, dx
    mov cx, MCOLS
    mul cx
    add ax, bx
    mov si, ax
    pop dx
    pop bx
    push bx
    push dx
    push si
    mov cx, [esp + 6]   ; width
.cr_col:
    mov byte [mapdata + si], T_FLOOR
    inc si
    loop .cr_col
    pop si
    pop dx
    pop bx
    inc dx
    jmp .cr_row
.cr_done:
    pop ax
    pop cx
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

dg_spawn_enemies:
    push ax
    push bx
    push cx
    push dx
    push si
    mov cx, MAX_ENE
    xor si, si
.se:
    push cx
    push si
    call dg_rand
    xor dx, dx
    mov bx, MCOLS - 4
    div bx
    add dx, 2
    mov [ex + si], dx
    call dg_rand
    xor dx, dx
    mov bx, MROWS - 4
    div bx
    add dx, 2
    mov [ey + si], dx
    mov word [ehp + si], 5
    mov word [ealive + si], 1
    call dg_rand
    and ax, 3
    mov [edir + si], ax
    pop si
    pop cx
    add si, 2
    loop .se
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; dg_try_move_x: AX=new_x
dg_try_move_x:
    cmp ax, 0
    jl .blocked
    cmp ax, MCOLS
    jge .blocked
    push ax
    mov bx, [py]
    mov cx, MCOLS
    mul bx
    ; wait, ax was overwritten
    pop ax
    push ax
    mov bx, [py]
    push ax
    mov ax, bx
    mov cx, MCOLS
    mul cx
    pop bx
    add ax, bx
    mov si, ax
    pop ax
    mov dl, [mapdata + si]
    cmp dl, T_EMPTY
    je .blocked
    cmp dl, T_WALL
    je .blocked
    mov [px], ax
    cmp dl, T_EXIT
    jne .done
    call dg_next_floor
.done:
    ret
.blocked:
    ret

; dg_try_move_y: AX=new_y
dg_try_move_y:
    cmp ax, 0
    jl .blocked
    cmp ax, MROWS
    jge .blocked
    push ax
    mov bx, [px]
    push bx
    mov cx, MCOLS
    mul cx
    pop bx
    add ax, bx
    mov si, ax
    pop ax
    mov dl, [mapdata + si]
    cmp dl, T_EMPTY
    je .blocked
    cmp dl, T_WALL
    je .blocked
    mov [py], ax
    cmp dl, T_EXIT
    jne .done
    call dg_next_floor
.done:
    ret
.blocked:
    ret

dg_attack_adjacent:
    push ax
    push bx
    push cx
    push si
    mov cx, MAX_ENE
    xor si, si
.aa:
    push cx
    push si
    cmp word [ealive + si], 0
    je .aa_skip
    ; Check if adjacent to player
    mov ax, [ex + si]
    sub ax, [px]
    cmp ax, 1
    jg .aa_skip
    cmp ax, -1
    jl .aa_skip
    mov bx, [ey + si]
    sub bx, [py]
    cmp bx, 1
    jg .aa_skip
    cmp bx, -1
    jl .aa_skip
    ; Attack!
    sub word [ehp + si], [patk]
    cmp word [ehp + si], 0
    jg .aa_skip
    mov word [ealive + si], 0
    ; Reward
    inc word [patk]
    add word [php], 2
.aa_skip:
    pop si
    pop cx
    add si, 2
    loop .aa
    pop si
    pop cx
    pop bx
    pop ax
    ret

dg_move_enemies:
    push ax
    push bx
    push cx
    push si
    mov cx, MAX_ENE
    xor si, si
.me:
    push cx
    push si
    cmp word [ealive + si], 0
    je .me_skip
    ; Move toward player
    mov ax, [px]
    sub ax, [ex + si]
    cmp ax, 0
    je .me_vert
    jg .me_right
    dec word [ex + si]
    jmp .me_hit_chk
.me_right:
    inc word [ex + si]
    jmp .me_hit_chk
.me_vert:
    mov ax, [py]
    sub ax, [ey + si]
    cmp ax, 0
    je .me_skip
    jg .me_down
    dec word [ey + si]
    jmp .me_hit_chk
.me_down:
    inc word [ey + si]
.me_hit_chk:
    ; If at player pos, damage player
    mov ax, [ex + si]
    cmp ax, [px]
    jne .me_skip
    mov ax, [ey + si]
    cmp ax, [py]
    jne .me_skip
    ; Enemy attacks player
    sub word [php], 1
    ; Push enemy back
    dec word [ey + si]
.me_skip:
    pop si
    pop cx
    add si, 2
    loop .me
    pop si
    pop cx
    pop bx
    pop ax
    ret

dg_next_floor:
    inc word [pfloor]
    cmp word [pfloor], 4
    jl .nf_ok
    ; Won!
    mov al, 0
    call gl16_clear
    mov bx, 52
    mov dx, 96
    mov al, 10
    mov si, str_win
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    call gl16_exit
    POP_ALL
    jmp 0xDEAD
.nf_ok:
    ; Heal slightly
    add word [php], 3
    call dg_gen_floor
    ret

dg_draw_map:
    push ax
    push bx
    push cx
    push dx
    push si
    xor cx, cx
.row:
    cmp cx, MROWS
    jge .dm_done
    xor bx, bx
.col:
    cmp bx, MCOLS
    jge .dm_next
    mov ax, cx
    mov dx, MCOLS
    mul dx
    add ax, bx
    mov si, ax
    mov al, [mapdata + si]
    test al, al
    jz .dm_skip
    push bx
    push cx
    push si
    ; Pixel coords
    mov ax, bx
    mov cx, CELL
    mul cx
    mov bx, ax
    pop si
    pop cx
    push cx
    push si
    mov ax, cx
    mov cx, CELL
    mul cx
    mov dx, ax
    pop si
    pop cx
    push cx
    push si
    ; Colour by tile
    mov al, [mapdata + si]
    cmp al, T_FLOOR
    je .tc_floor
    cmp al, T_WALL
    je .tc_wall
    cmp al, T_EXIT
    je .tc_exit
    cmp al, T_CHEST
    je .tc_chest
    mov al, 5
    jmp .tc_draw
.tc_floor: mov al, 3
    jmp .tc_draw
.tc_wall:  mov al, 7
    jmp .tc_draw
.tc_exit:  mov al, 14
    jmp .tc_draw
.tc_chest: mov al, 6
.tc_draw:
    push ax
    mov cx, CELL
.tile_row:
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
    loop .tile_row
    pop ax
    pop si
    pop cx
    pop bx
.dm_skip:
    inc bx
    jmp .col
.dm_next:
    inc cx
    jmp .row
.dm_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

dg_draw_enemies:
    push ax
    push bx
    push cx
    push dx
    push si
    mov cx, MAX_ENE
    xor si, si
.de:
    push cx
    push si
    cmp word [ealive + si], 0
    je .de_skip
    mov ax, [ex + si]
    mov cx, CELL
    mul cx
    add ax, 2
    mov bx, ax
    mov ax, [ey + si]
    mul cx
    add ax, 2
    mov dx, ax
    mov cx, CELL - 4
.de_row:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CELL - 5
    mov al, 12
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .de_row
.de_skip:
    pop si
    pop cx
    add si, 2
    loop .de
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

dg_draw_player:
    push ax
    push bx
    push cx
    push dx
    mov ax, [px]
    mov cx, CELL
    mul cx
    add ax, 2
    mov bx, ax
    mov ax, [py]
    mul cx
    add ax, 2
    mov dx, ax
    mov cx, CELL - 4
.pr:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CELL - 5
    mov al, 10
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

dg_draw_ui:
    push ax
    push bx
    push dx
    push si
    mov bx, 4
    mov dx, MROWS * CELL + 2
    mov al, 10
    mov si, str_hp
    call gl16_text_gfx
    mov ax, [php]
    mov si, sbuf
    call dg_itoa
    mov bx, 26
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    mov bx, 60
    mov al, 14
    mov si, str_atk
    call gl16_text_gfx
    mov ax, [patk]
    mov si, sbuf
    call dg_itoa
    mov bx, 90
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    mov bx, 130
    mov al, 11
    mov si, str_floor
    call gl16_text_gfx
    mov ax, [pfloor]
    mov si, sbuf
    call dg_itoa
    mov bx, 172
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    pop si
    pop dx
    pop bx
    pop ax
    ret

dg_rand:
    push bx
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    pop bx
    ret

dg_itoa:
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, si
    add bx, 3
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

%include "../opengl.asm"
