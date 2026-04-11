; =============================================================================
; ASTRO.OVL - Corrigido para endereçamento 16-bit válido
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

MAX_ROCKS equ 12
MAX_BLETS equ 4

STR str_title, "ASTRO  [W=thrust AD=turn SPC=fire ESC=quit]"
STR str_score, "Score:"
STR str_dead,  "SHIP DESTROYED! Any key"
STRBUF sbuf, 8

I16 ship_x,   160 * 16
I16 ship_y,   100 * 16
I16 ship_vx,  0
I16 ship_vy,  0
U16 ship_ang, 0
U16 ship_alive, 1

WORDBUF rock_x,  MAX_ROCKS
WORDBUF rock_y,  MAX_ROCKS
WORDBUF rock_vx, MAX_ROCKS
WORDBUF rock_vy, MAX_ROCKS
WORDBUF rock_sz, MAX_ROCKS
U16 rock_cnt, 0
U16 lcg_seed, 0x4567

WORDBUF blet_x, MAX_BLETS
WORDBUF blet_y, MAX_BLETS
WORDBUF blet_vx, MAX_BLETS
WORDBUF blet_vy, MAX_BLETS
WORDBUF blet_life, MAX_BLETS

U16 score, 0
U16 frame_cnt, 0

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call ast_init

.frame:
    inc word [frame_cnt]
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp al, 'a'
    je .turn_left
    cmp al, 'A'
    je .turn_left
    cmp al, 'd'
    je .turn_right
    cmp al, 'D'
    je .turn_right
    cmp al, 'w'
    je .thrust
    cmp al, 'W'
    je .thrust
    cmp al, ' '
    je .fire
    jmp .no_key

.turn_left:
    mov ax, [ship_ang]
    sub ax, 10
    cmp ax, 0
    jge .tl_ok
    add ax, 360
.tl_ok:
    mov [ship_ang], ax
    jmp .no_key
.turn_right:
    mov ax, [ship_ang]
    add ax, 10
    cmp ax, 360
    jl .tr_ok
    sub ax, 360
.tr_ok:
    mov [ship_ang], ax
    jmp .no_key
.thrust:
    mov ax, [ship_ang]
    call fcos16
    sar ax, 5
    add [ship_vx], ax
    mov ax, [ship_ang]
    call fsin16
    neg ax
    sar ax, 5
    add [ship_vy], ax
    mov ax, [ship_vx]
    cmp ax, 128
    jle .vx_ok
    mov word [ship_vx], 128
    jmp .no_key
.vx_ok:
    cmp ax, -128
    jge .no_key
    mov word [ship_vx], -128
    jmp .no_key

.fire:
    mov si, 0
.find_blet:
    cmp si, MAX_BLETS * 2
    jge .no_key
    cmp word [blet_life + si], 0
    je .found
    add si, 2
    jmp .find_blet
.found:
    mov ax, [ship_x]
    mov [blet_x + si], ax
    mov ax, [ship_y]
    mov [blet_y + si], ax
    mov ax, [ship_ang]
    call fcos16
    sar ax, 2
    add ax, [ship_vx]
    mov [blet_vx + si], ax
    mov ax, [ship_ang]
    call fsin16
    neg ax
    sar ax, 2
    add ax, [ship_vy]
    mov [blet_vy + si], ax
    mov word [blet_life + si], 60
    jmp .no_key

.no_key:
    mov ax, [ship_vx]
    add [ship_x], ax
    mov ax, [ship_vy]
    add [ship_y], ax
    call ast_wrap_ship
    mov ax, [ship_vx]
    sar ax, 6
    sub [ship_vx], ax
    mov ax, [ship_vy]
    sar ax, 6
    sub [ship_vy], ax

    xor si, si
.mblet:
    cmp si, MAX_BLETS * 2
    jge .move_rocks
    cmp word [blet_life + si], 0
    je .mblet_skip
    mov ax, [blet_vx + si]
    add [blet_x + si], ax
    mov ax, [blet_vy + si]
    add [blet_y + si], ax
    dec word [blet_life + si]
    
    ; Wrap bullet (usando SI)
    mov ax, [blet_x + si]
    cmp ax, 0
    jge .bwx_ok
    add word [blet_x + si], 320 * 16
.bwx_ok:
    cmp ax, 320 * 16
    jl .bwy_ok
    sub word [blet_x + si], 320 * 16
.bwy_ok:
    mov ax, [blet_y + si]
    cmp ax, 0
    jge .bwx2_ok
    add word [blet_y + si], 200 * 16
.bwx2_ok:
    cmp ax, 200 * 16
    jl .mblet_skip
    sub word [blet_y + si], 200 * 16
.mblet_skip:
    add si, 2
    jmp .mblet

.move_rocks:
    call ast_move_rocks
    call ast_check_collisions

.draw:
    mov al, 0
    call gl16_clear
    call ast_draw_rocks
    call ast_draw_bullets
    call ast_draw_ship
    mov bx, 4
    mov dx, 4
    mov al, 7
    mov si, str_score
    call gl16_text_gfx
    mov ax, [score]
    mov si, sbuf
    call ast_itoa
    mov bx, 46
    mov dx, 4
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    cmp word [rock_cnt], 0
    jne .frame
    call ast_spawn_rocks
    jmp .frame

.quit:
    call gl16_exit
    POP_ALL
ENDFN

ast_init:
    call ast_spawn_rocks
    mov cx, MAX_BLETS
    xor si, si
.cl:
    mov word [blet_life + si], 0
    add si, 2
    loop .cl
    ret

ast_spawn_rocks:
    push ax
    push bx
    push cx
    mov word [rock_cnt], 6
    mov cx, 6
    xor si, si
.sr:
    push cx
    push si
    call ast_rand
    and ax, 0xFF
    cmp ax, 80
    jl .rx_ok
    cmp ax, 240
    jg .rx_ok
    add ax, 80
.rx_ok:
    mov bx, 16
    mul bx
    mov [rock_x + si], ax
    call ast_rand
    and ax, 0x7F
    mov bx, 16
    mul bx
    mov [rock_y + si], ax
    call ast_rand
    and ax, 0x1F
    sub ax, 16
    mov [rock_vx + si], ax
    call ast_rand
    and ax, 0x1F
    sub ax, 16
    mov [rock_vy + si], ax
    call ast_rand
    and ax, 0x07
    add ax, 12
    mov [rock_sz + si], ax
    pop si
    pop cx
    add si, 2
    loop .sr
    pop cx
    pop bx
    pop ax
    ret

ast_rand:
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    ret

ast_wrap_ship:
    mov ax, [ship_x]
    cmp ax, 0
    jge .sx_ok
    add word [ship_x], 320 * 16
    jmp .sy
.sx_ok:
    cmp ax, 320 * 16
    jl .sy
    sub word [ship_x], 320 * 16
.sy:
    mov ax, [ship_y]
    cmp ax, 0
    jge .sy_ok
    add word [ship_y], 200 * 16
    jmp .done
.sy_ok:
    cmp ax, 200 * 16
    jl .done
    sub word [ship_y], 200 * 16
.done:
    ret

ast_move_rocks:
    push ax
    push cx
    push si
    mov cx, MAX_ROCKS
    xor si, si
.mr:
    cmp word [rock_sz + si], 0
    je .mr_skip
    mov ax, [rock_vx + si]
    add [rock_x + si], ax
    mov ax, [rock_vy + si]
    add [rock_y + si], ax
    ; Wrap rocks
    mov ax, [rock_x + si]
    cmp ax, 0
    jge .rx_ok
    add word [rock_x + si], 320 * 16
    jmp .ry
.rx_ok:
    cmp ax, 320 * 16
    jl .ry
    sub word [rock_x + si], 320 * 16
.ry:
    mov ax, [rock_y + si]
    cmp ax, 0
    jge .ry_ok
    add word [rock_y + si], 200 * 16
    jmp .mr_skip
.ry_ok:
    cmp ax, 200 * 16
    jl .mr_skip
    sub word [rock_y + si], 200 * 16
.mr_skip:
    add si, 2
    loop .mr
    pop si
    pop cx
    pop ax
    ret

ast_check_collisions:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov di, 0
.bl:
    cmp di, MAX_BLETS * 2
    jge .done_cc
    cmp word [blet_life + di], 0
    je .bl_next
    mov ax, [blet_x + di]
    sar ax, 4
    mov bx, ax
    mov ax, [blet_y + di]
    sar ax, 4
    mov dx, ax
    xor si, si
.rk:
    cmp si, MAX_ROCKS * 2
    jge .bl_next
    cmp word [rock_sz + si], 0
    je .rk_next
    mov ax, [rock_x + si]
    sar ax, 4
    mov cx, ax
    sub cx, bx
    imul cx
    push ax
    mov ax, [rock_y + si]
    sar ax, 4
    sub ax, dx
    imul ax
    add ax, [esp]
    pop cx
    mov cx, [rock_sz + si]
    imul cx
    cmp ax, cx
    jg .rk_next
    mov word [blet_life + di], 0
    mov word [rock_sz + si], 0
    dec word [rock_cnt]
    add word [score], 50
.rk_next:
    add si, 2
    jmp .rk
.bl_next:
    add di, 2
    jmp .bl
.done_cc:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ast_draw_rocks:
    push ax
    push bx
    push cx
    push dx
    push si
    mov cx, MAX_ROCKS
    xor si, si
.dr:
    cmp word [rock_sz + si], 0
    je .dr_skip
    mov ax, [rock_x + si]
    sar ax, 4
    mov bx, ax
    mov ax, [rock_y + si]
    sar ax, 4
    mov dx, ax
    mov ax, [rock_sz + si]
    push ax
    push bx
    push dx
    xor di, di
.drw:
    cmp di, [esp+8]
    jg .dr_done_draw
    push di
    push dx
    push bx
    mov cx, bx
    sub cx, di
    push cx
    mov cx, bx
    add cx, di
    pop ax
    mov bx, ax
    mov ax, [esp+4]
    sub ax, di
    cmp ax, di
    jge .drw_ok
    mov ax, di
.drw_ok:
    push ax
    mov ax, dx
    sub ax, di
    mov dx, ax
    pop ax
    mov bx, [esp+2]
    sub bx, di
    mov al, 8
    call gl16_hline
    mov ax, [esp+4]
    add ax, di
    mov dx, ax
    call gl16_hline
    pop bx
    pop dx
    pop di
    inc di
    jmp .drw
.dr_done_draw:
    pop dx
    pop bx
    pop ax
.dr_skip:
    add si, 2
    loop .dr
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ast_draw_bullets:
    push ax
    push bx
    push cx
    push dx
    push si
    xor si, si
    mov cx, MAX_BLETS
.db:
    cmp word [blet_life + si], 0
    je .db_skip
    mov ax, [blet_x + si]
    sar ax, 4
    mov bx, ax
    mov ax, [blet_y + si]
    sar ax, 4
    mov dx, ax
    mov al, 15
    call gl16_pix
    inc bx
    call gl16_pix
    inc dx
    call gl16_pix
    dec bx
    call gl16_pix
.db_skip:
    add si, 2
    loop .db
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ast_draw_ship:
    push ax
    push bx
    push cx
    push dx
    push si
    mov ax, [ship_x]
    sar ax, 4
    mov bx, ax
    mov ax, [ship_y]
    sar ax, 4
    mov dx, ax
    push bx
    push dx
    mov ax, [ship_ang]
    call fcos16
    sar ax, 4
    add ax, bx
    mov bx, ax
    mov ax, [ship_ang]
    call fsin16
    neg ax
    sar ax, 4
    add ax, dx
    mov dx, ax
    mov al, 15
    call gl16_pix
    pop dx
    pop bx
    mov ax, [ship_ang]
    add ax, 140
    cmp ax, 360
    jl .lw_ok
    sub ax, 360
.lw_ok:
    call fcos16
    sar ax, 4
    add ax, bx
    push ax
    mov ax, [ship_ang]
    add ax, 140
    cmp ax, 360
    jl .lwv_ok
    sub ax, 360
.lwv_ok:
    call fsin16
    neg ax
    sar ax, 4
    add ax, dx
    mov dx, ax
    pop bx
    mov al, 10
    call gl16_pix
    mov bx, [ship_x]
    sar bx, 4
    mov dx, [ship_y]
    sar dx, 4
    mov ax, [ship_ang]
    add ax, 220
    cmp ax, 360
    jl .rw_ok
    sub ax, 360
.rw_ok:
    call fcos16
    sar ax, 4
    add ax, bx
    push ax
    mov ax, [ship_ang]
    add ax, 220
    cmp ax, 360
    jl .rwv_ok
    sub ax, 360
.rwv_ok:
    call fsin16
    neg ax
    sar ax, 4
    add ax, dx
    mov dx, ax
    pop bx
    mov al, 10
    call gl16_pix
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ast_itoa:
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

%include "../opengl.asm"
