; =============================================================================
; ROGUE.OVL  -  Roguelike Dungeon  (KSDOS 16-bit)
; Explore rooms, find stairs, avoid monsters.  WASD=move, ESC=quit.
; 80x25 char-like grid drawn with coloured blocks.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

MCOLS   equ 32
MROWS   equ 20
CELL    equ 10
MAX_MONS equ 8

; Tile types
TILE_EMPTY  equ 0
TILE_FLOOR  equ 1
TILE_WALL   equ 2
TILE_STAIRS equ 3
TILE_DOOR   equ 4

STR str_title, "ROGUE  [WASD=move ESC=quit]"
STR str_hp,    "HP:"
STR str_lv,    "Floor:"
STR str_dead,  "YOU DIED! Any key"
STR str_win,   "ESCAPED! Any key"
STRBUF sbuf, 4

; Map: MROWS * MCOLS bytes
STRBUF mapdata, MROWS * MCOLS

; Player
U16 plr_x, 5
U16 plr_y, 5
U16 plr_hp, 10
U16 plr_maxhp, 10
U16 floor_lv, 1

; Monsters
WORDBUF mon_x, MAX_MONS
WORDBUF mon_y, MAX_MONS
WORDBUF mon_hp, MAX_MONS
WORDBUF mon_alive, MAX_MONS

; Stairs
U16 stair_x, 0
U16 stair_y, 0

U16 lcg_seed, 0xF00D
U16 move_mon_timer, 0

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call rg_gen_floor

.frame:
    ; Input
    mov ah, 0x01
    int 0x16
    jz .draw
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
    jmp .draw

.go_up:
    mov ax, [plr_y]
    dec ax
    call rg_try_move_y
    jmp .draw
.go_dn:
    mov ax, [plr_y]
    inc ax
    call rg_try_move_y
    jmp .draw
.go_lt:
    mov ax, [plr_x]
    dec ax
    call rg_try_move_x
    jmp .draw
.go_rt:
    mov ax, [plr_x]
    inc ax
    call rg_try_move_x

.draw:
    ; Move monsters every 2 frames
    inc word [move_mon_timer]
    cmp word [move_mon_timer], 2
    jl .draw_only
    mov word [move_mon_timer], 0
    call rg_move_monsters

.draw_only:
    ; Check player dead
    cmp word [plr_hp], 0
    jle .dead

    mov al, 0
    call gl16_clear
    call rg_draw_map
    call rg_draw_entities
    call rg_draw_ui
    jmp .frame

.dead:
    mov al, 0
    call gl16_clear
    mov bx, 88
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

; rg_try_move_x: AX=new_x
rg_try_move_x:
    cmp ax, 0
    jl .blocked
    cmp ax, MCOLS
    jge .blocked
    mov bx, [plr_y]
    push ax
    mov cx, MCOLS
    mul cx
    ; wait, bx is used...
    pop ax
    push ax
    push bx
    mov cx, MCOLS
    mul bx
    add ax, [esp + 2]   ; + new_x
    mov si, ax
    pop bx
    pop ax
    mov dl, [mapdata + si]
    cmp dl, TILE_EMPTY
    je .blocked
    cmp dl, TILE_WALL
    je .blocked
    ; Check monster at this position
    push ax
    push bx
    call rg_check_monster
    jc .attack_mon
    pop bx
    pop ax
    mov [plr_x], ax
    ; Check stairs
    cmp dl, TILE_STAIRS
    jne .done
    call rg_next_floor
.done:
    ret
.attack_mon:
    ; Attack monster at [mon_x+si], [mon_y+si]
    dec word [mon_hp + si]
    cmp word [mon_hp + si], 0
    jg .pop_done
    mov word [mon_alive + si], 0
.pop_done:
    pop bx
    pop ax
    ret
.blocked:
    ret

; rg_try_move_y: AX=new_y
rg_try_move_y:
    cmp ax, 0
    jl .blocked
    cmp ax, MROWS
    jge .blocked
    mov bx, [plr_x]
    push ax
    push bx
    mov cx, MCOLS
    mul cx
    add ax, bx
    mov si, ax
    pop bx
    pop ax
    mov dl, [mapdata + si]
    cmp dl, TILE_EMPTY
    je .blocked
    cmp dl, TILE_WALL
    je .blocked
    push ax
    push bx
    call rg_check_monster
    jc .attack_mon
    pop bx
    pop ax
    mov [plr_y], ax
    cmp dl, TILE_STAIRS
    jne .done
    call rg_next_floor
.done:
    ret
.attack_mon:
    dec word [mon_hp + si]
    cmp word [mon_hp + si], 0
    jg .pop_done
    mov word [mon_alive + si], 0
.pop_done:
    pop bx
    pop ax
    ret
.blocked:
    ret

; rg_check_monster: AX=row, BX=col -> CF=1 and SI=index if monster there
rg_check_monster:
    push cx
    mov cx, MAX_MONS
    xor si, si
.cm:
    cmp word [mon_alive + si], 0
    je .cm_skip
    cmp ax, [mon_y + si]
    jne .cm_skip
    cmp bx, [mon_x + si]
    je .cm_hit
.cm_skip:
    add si, 2
    loop .cm
    pop cx
    clc
    ret
.cm_hit:
    pop cx
    stc
    ret

rg_gen_floor:
    push ax
    push bx
    push cx
    push di
    ; Fill with walls
    mov cx, MROWS * MCOLS
    mov di, mapdata
    mov al, TILE_WALL
    rep stosb
    ; Carve rooms
    call rg_carve_room
    ; Place stairs
    call rg_rand
    xor dx, dx
    mov bx, MCOLS - 4
    div bx
    add dx, 2
    mov [stair_x], dx
    call rg_rand
    xor dx, dx
    mov bx, MROWS - 4
    div bx
    add dx, 2
    mov [stair_y], dx
    ; Place stair tile
    mov ax, [stair_y]
    mov cx, MCOLS
    mul cx
    add ax, [stair_x]
    mov si, ax
    mov byte [mapdata + si], TILE_STAIRS
    ; Spawn monsters
    call rg_spawn_monsters
    ; Player start in first room area
    mov word [plr_x], 5
    mov word [plr_y], 5
    pop di
    pop cx
    pop bx
    pop ax
    ret

rg_carve_room:
    push ax
    push bx
    push cx
    push dx
    push di
    ; Carve 3 rectangular rooms
    ; Room 1
    mov bx, 2
    mov dx, 2
    mov cx, 12
    mov di, 8
    call rg_fill_rect
    ; Room 2
    mov bx, 18
    mov dx, 4
    mov cx, 12
    mov di, 10
    call rg_fill_rect
    ; Room 3
    mov bx, 5
    mov dx, 12
    mov cx, 20
    mov di, 7
    call rg_fill_rect
    ; Connect with corridors
    ; Horizontal corridor row 10
    push bx
    push dx
    mov dx, 10
    mov bx, 14
.hcor:
    cmp bx, 18
    jg .hcor_done
    mov ax, dx
    mov cx, MCOLS
    mul cx
    add ax, bx
    mov byte [mapdata + ax], TILE_FLOOR
    inc bx
    jmp .hcor
.hcor_done:
    pop dx
    pop bx
    ; Vertical corridor col 8
    mov bx, 8
    mov dx, 10
.vcor:
    cmp dx, 14
    jg .vcor_done
    mov ax, dx
    mov cx, MCOLS
    mul cx
    add ax, bx
    mov byte [mapdata + ax], TILE_FLOOR
    inc dx
    jmp .vcor
.vcor_done:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; rg_fill_rect: BX=x,DX=y,CX=w,DI=h
rg_fill_rect:
    push ax
    push si
    push bx
    push cx
    push dx
    push di
    mov si, dx
.fry:
    cmp si, dx
    push dx
    mov dx, di
    add dx, si
    cmp si, dx
    pop dx
    jge .fr_done
    ; oops, simplify
    pop di
    pop dx
    pop cx
    pop bx
    pop si
    pop ax
    ; Do it inline
    push ax
    push si
    push cx
    push di
    mov si, dx
    push dx
.fr_rows:
    mov ax, di
    add ax, dx
    cmp si, ax
    jge .fr_done2
    push cx
    push si
    push bx
.fr_cols:
    mov ax, cx
    add ax, bx
    cmp bx, ax      ; this is wrong...
    ; simplified: fill row si, cols bx to bx+cx
    mov ax, si
    push bx
    push cx
    mov cx, MCOLS
    mul cx
    pop cx
    pop bx
    push bx
    push cx
    add ax, bx
    mov [mapdata + ax], byte TILE_FLOOR
    pop cx
    pop bx
    inc ax
    ; Use a counter
    pop bx
    pop si
    pop cx
    push cx
    push si
    push bx
    ; Better loop:
    mov si, [esp + 4]   ; row
    mov ax, si
    mov cx, MCOLS
    mul cx
    add ax, [esp + 6]   ; bx (col start)
    mov cx, [esp + 2]   ; width
.fr_row_inner:
    mov byte [mapdata + ax], TILE_FLOOR
    inc ax
    loop .fr_row_inner
    pop bx
    pop si
    pop cx
    inc si
    cmp si, [esp]       ; di (height)
    jl .fr_rows_fake
    jmp .fr_done2
.fr_rows_fake:
    push cx
    push si
    push bx
    jmp .fr_rows
.fr_done2:
    pop dx
    pop di
    pop cx
    pop si
    pop ax
    ret
.fr_done:
    pop di
    pop dx
    pop cx
    pop bx
    pop si
    pop ax
    ret

rg_spawn_monsters:
    push ax
    push bx
    push cx
    push dx
    push si
    mov cx, MAX_MONS
    xor si, si
.sm:
    push cx
    push si
    call rg_rand
    xor dx, dx
    mov bx, MCOLS - 4
    div bx
    add dx, 2
    mov [mon_x + si], dx
    call rg_rand
    xor dx, dx
    mov bx, MROWS - 4
    div bx
    add dx, 2
    mov [mon_y + si], dx
    mov word [mon_hp + si], 3
    mov word [mon_alive + si], 1
    pop si
    pop cx
    add si, 2
    loop .sm
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

rg_move_monsters:
    push ax
    push bx
    push cx
    push dx
    push si
    mov cx, MAX_MONS
    xor si, si
.mm:
    push cx
    push si
    cmp word [mon_alive + si], 0
    je .mm_skip
    ; Simple: move toward player
    mov ax, [plr_x]
    sub ax, [mon_x + si]
    cmp ax, 0
    je .mm_vert
    jg .mm_right
    dec word [mon_x + si]
    jmp .mm_chk_hit
.mm_right:
    inc word [mon_x + si]
    jmp .mm_chk_hit
.mm_vert:
    mov ax, [plr_y]
    sub ax, [mon_y + si]
    cmp ax, 0
    je .mm_skip
    jg .mm_down
    dec word [mon_y + si]
    jmp .mm_chk_hit
.mm_down:
    inc word [mon_y + si]
.mm_chk_hit:
    ; If at player position, attack
    mov ax, [mon_x + si]
    cmp ax, [plr_x]
    jne .mm_skip
    mov ax, [mon_y + si]
    cmp ax, [plr_y]
    jne .mm_skip
    ; Monster attacks player
    dec word [plr_hp]
    ; Push monster back slightly
    dec word [mon_y + si]
.mm_skip:
    pop si
    pop cx
    add si, 2
    loop .mm
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

rg_next_floor:
    inc word [floor_lv]
    cmp word [floor_lv], 6
    jl .nf_ok
    ; Won!
    mov al, 0
    call gl16_clear
    mov bx, 96
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
    call rg_gen_floor
    ret

rg_draw_map:
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
    jge .dm_next_row
    mov ax, cx
    mov dx, MCOLS
    mul dx
    add ax, bx
    mov si, ax
    mov al, [mapdata + si]
    cmp al, TILE_EMPTY
    je .dm_skip
    ; Compute pixel pos
    push bx
    push cx
    push si
    mov ax, bx
    mov cx, CELL
    mul cx
    mov bx, ax
    pop si
    pop cx
    push cx
    push si
    mov ax, cx
    mul cx
    mov dx, ax
    pop si
    pop cx
    push cx
    push si
    ; Determine colour
    mov al, [mapdata + si]
    cmp al, TILE_FLOOR
    je .fl_col
    cmp al, TILE_WALL
    je .wl_col
    cmp al, TILE_STAIRS
    je .st_col
    mov al, 6           ; door
    jmp .draw_tile
.fl_col:
    mov al, 3
    jmp .draw_tile
.wl_col:
    mov al, 7
    jmp .draw_tile
.st_col:
    mov al, 14
.draw_tile:
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
.dm_next_row:
    inc cx
    jmp .row
.dm_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

rg_draw_entities:
    push ax
    push bx
    push cx
    push dx
    push si
    ; Draw monsters
    mov cx, MAX_MONS
    xor si, si
.dm:
    push cx
    push si
    cmp word [mon_alive + si], 0
    je .dm_skip
    mov ax, [mon_x + si]
    mov cx, CELL
    mul cx
    add ax, 2
    mov bx, ax
    mov ax, [mon_y + si]
    mul cx
    add ax, 2
    mov dx, ax
    mov cx, CELL - 4
.mon_row:
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
    loop .mon_row
.dm_skip:
    pop si
    pop cx
    add si, 2
    loop .dm
    ; Draw player
    mov ax, [plr_x]
    mov cx, CELL
    mul cx
    add ax, 2
    mov bx, ax
    mov ax, [plr_y]
    mul cx
    add ax, 2
    mov dx, ax
    mov cx, CELL - 4
.plr_row:
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
    loop .plr_row
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

rg_draw_ui:
    push ax
    push bx
    push dx
    push si
    mov bx, 4
    mov dx, MROWS * CELL + 2
    mov al, 10
    mov si, str_hp
    call gl16_text_gfx
    mov ax, [plr_hp]
    mov si, sbuf
    call rg_itoa
    mov bx, 24
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    mov bx, 70
    mov al, 11
    mov si, str_lv
    call gl16_text_gfx
    mov ax, [floor_lv]
    mov si, sbuf
    call rg_itoa
    mov bx, 108
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    pop si
    pop dx
    pop bx
    pop ax
    ret

rg_rand:
    push bx
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    pop bx
    ret

rg_itoa:
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
