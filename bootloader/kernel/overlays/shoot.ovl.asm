; =============================================================================
; SHOOT.OVL  -  Shooter Gallery  (KSDOS 16-bit)
; Move crosshair with WASD, SPACE to shoot targets.  ESC=quit.
; Targets appear randomly; hit them before they disappear.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

MAX_TGTS equ 8
TGT_W    equ 20
TGT_H    equ 20

STR str_title,  "SHOOTING GALLERY  [WASD=aim SPC=fire ESC=quit]"
STR str_score,  "Score:"
STR str_miss,   "Misses:"
STR str_over,   "OUT OF AMMO! Any key"
STRBUF sbuf, 8

; Crosshair
U16 cx_x, 160
U16 cx_y, 100

; Targets: x, y, timer (countdown), alive
WORDBUF tgt_x, MAX_TGTS
WORDBUF tgt_y, MAX_TGTS
WORDBUF tgt_timer, MAX_TGTS
WORDBUF tgt_alive, MAX_TGTS

U16 score, 0
U16 misses, 0
U16 ammo, 30
U16 spawn_timer, 0
U16 spawn_rate, 80
U16 lcg_seed, 0xBEEF
U16 frame_cnt, 0

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call sh_init

.frame:
    inc word [frame_cnt]

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
    sub word [cx_y], 4
    cmp word [cx_y], 20
    jge .no_key
    mov word [cx_y], 20
    jmp .no_key
.go_dn:
    add word [cx_y], 4
    cmp word [cx_y], 190
    jle .no_key
    mov word [cx_y], 190
    jmp .no_key
.go_lt:
    sub word [cx_x], 4
    cmp word [cx_x], 10
    jge .no_key
    mov word [cx_x], 10
    jmp .no_key
.go_rt:
    add word [cx_x], 4
    cmp word [cx_x], 309
    jle .no_key
    mov word [cx_x], 309

.no_key:
    jmp .update
.fire:
    ; Check ammo
    cmp word [ammo], 0
    je .no_key
    dec word [ammo]
    ; Check each target
    mov cx, MAX_TGTS
    xor si, si
    xor bx, bx          ; hit flag
.ft:
    push cx
    push si
    cmp word [tgt_alive + si], 0
    je .ft_skip
    mov ax, [cx_x]
    cmp ax, [tgt_x + si]
    jl .ft_skip
    mov dx, [tgt_x + si]
    add dx, TGT_W
    cmp ax, dx
    jg .ft_skip
    mov ax, [cx_y]
    cmp ax, [tgt_y + si]
    jl .ft_skip
    mov dx, [tgt_y + si]
    add dx, TGT_H
    cmp ax, dx
    jg .ft_skip
    ; Hit!
    mov word [tgt_alive + si], 0
    inc word [score]
    add word [score], 9
    ; Refill ammo slightly
    cmp word [ammo], 28
    jge .ft_skip
    add word [ammo], 2
    mov bx, 1
.ft_skip:
    pop si
    pop cx
    add si, 2
    loop .ft
    test bx, bx
    jnz .update
    ; Missed
    inc word [misses]

.update:
    ; Update target timers
    mov cx, MAX_TGTS
    xor si, si
.ut:
    push cx
    push si
    cmp word [tgt_alive + si], 0
    je .ut_skip
    dec word [tgt_timer + si]
    cmp word [tgt_timer + si], 0
    jg .ut_skip
    ; Timed out
    mov word [tgt_alive + si], 0
    inc word [misses]
.ut_skip:
    pop si
    pop cx
    add si, 2
    loop .ut

    ; Spawn new targets
    inc word [spawn_timer]
    mov ax, [spawn_rate]
    cmp word [spawn_timer], ax
    jl .draw
    mov word [spawn_timer], 0
    call sh_spawn_target
    ; Speed up over time
    cmp word [spawn_rate], 30
    jle .draw
    dec word [spawn_rate]

.draw:
    ; Dark background
    mov al, 0
    call gl16_clear

    ; Draw targets
    mov cx, MAX_TGTS
    xor si, si
.dt:
    push cx
    push si
    cmp word [tgt_alive + si], 0
    je .dt_skip
    ; Colour based on timer
    mov ax, [tgt_timer + si]
    cmp ax, 40
    jge .dt_green
    cmp ax, 20
    jge .dt_yellow
    mov al, 12          ; red (urgent)
    jmp .dt_draw
.dt_green:
    mov al, 10
    jmp .dt_draw
.dt_yellow:
    mov al, 14
.dt_draw:
    push ax
    mov bx, [tgt_x + si]
    mov dx, [tgt_y + si]
    mov cx, TGT_H
.tgt_row:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, TGT_W - 1
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .tgt_row
    ; Bullseye ring
    pop ax
    mov bx, [tgt_x + si]
    add bx, TGT_W / 2 - 2
    mov dx, [tgt_y + si]
    add dx, TGT_H / 2 - 2
    mov cx, 4
.ring:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, 3
    mov al, 15
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .ring
.dt_skip:
    pop si
    pop cx
    add si, 2
    loop .dt

    ; Draw crosshair
    mov bx, [cx_x]
    sub bx, 10
    mov dx, [cx_y]
    mov cx, 21
.cx_h:
    mov al, 15
    call gl16_pix
    inc bx
    loop .cx_h
    ; Vertical
    mov bx, [cx_x]
    mov dx, [cx_y]
    sub dx, 10
    mov cx, 21
.cx_v:
    call gl16_pix
    inc dx
    loop .cx_v
    ; Centre dot
    mov bx, [cx_x]
    mov dx, [cx_y]
    mov al, 12
    call gl16_pix

    ; UI
    mov bx, 4
    mov dx, 2
    mov al, 7
    mov si, str_score
    call gl16_text_gfx
    mov ax, [score]
    mov si, sbuf
    call sh_itoa
    mov bx, 46
    mov dx, 2
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    mov bx, 100
    mov dx, 2
    mov al, 7
    mov si, str_miss
    call gl16_text_gfx
    mov ax, [misses]
    mov si, sbuf
    call sh_itoa
    mov bx, 154
    mov dx, 2
    mov al, 14
    mov si, sbuf
    call gl16_text_gfx

    ; Ammo bar
    mov bx, 4
    mov dx, 193
    mov cx, [ammo]
    shl cx, 3
    push cx
    add cx, 3
    mov al, 14
    call gl16_hline
    pop cx

    ; Check game over
    cmp word [ammo], 0
    jne .frame
    ; Check if any targets alive
    mov cx, MAX_TGTS
    xor si, si
.chk_alive:
    cmp word [tgt_alive + si], 1
    je .frame              ; still targets alive
    add si, 2
    loop .chk_alive
    ; No ammo, no targets
    mov al, 0
    call gl16_clear
    mov bx, 68
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

sh_init:
    push cx
    push si
    mov cx, MAX_TGTS
    xor si, si
.cl:
    mov word [tgt_alive + si], 0
    add si, 2
    loop .cl
    ; Spawn initial targets
    call sh_spawn_target
    call sh_spawn_target
    call sh_spawn_target
    pop si
    pop cx
    ret

sh_spawn_target:
    push ax
    push bx
    push cx
    push dx
    push si
    ; Find free slot
    mov cx, MAX_TGTS
    xor si, si
.find:
    cmp word [tgt_alive + si], 0
    je .spawn
    add si, 2
    loop .find
    jmp .done
.spawn:
    ; Random position
    call sh_rand
    xor dx, dx
    mov bx, 300 - TGT_W
    div bx
    add dx, 10
    mov [tgt_x + si], dx
    call sh_rand
    xor dx, dx
    mov bx, 170 - TGT_H
    div bx
    add dx, 20
    mov [tgt_y + si], dx
    ; Timer: 40-80 frames
    call sh_rand
    xor dx, dx
    mov bx, 40
    div bx
    add dx, 40
    mov [tgt_timer + si], dx
    mov word [tgt_alive + si], 1
.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

sh_rand:
    push bx
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    pop bx
    ret

sh_itoa:
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
