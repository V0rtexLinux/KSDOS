; =============================================================================
; RACE.OVL  -  Road Racer  (KSDOS 16-bit)
; LEFT/RIGHT to dodge traffic.  ESC = quit.  Avoid other cars!
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

ROAD_L  equ 80
ROAD_R  equ 239
ROAD_W  equ ROAD_R - ROAD_L
CAR_W   equ 20
CAR_H   equ 32
LANE_W  equ 40
NUM_OPP equ 5

STR str_title,  "RACE  [<>=steer  ESC=quit]"
STR str_score,  "Score:"
STR str_crash,  "CRASH! Any key"
STRBUF sbuf, 8

U16 plr_x,  150       ; player car left X
U16 score,  0
U16 speed,  3         ; road scroll speed
U16 scroll, 0         ; current scroll offset for dashes
U16 frame_cnt, 0
U16 lcg_seed, 0x2222

; Opponent cars (x=left edge, y=top edge, colour)
WORDBUF opp_x, NUM_OPP
WORDBUF opp_y, NUM_OPP
WORDBUF opp_col, NUM_OPP
U16 alive, 1

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call race_init

.frame:
    inc word [frame_cnt]
    ; Increase speed slowly
    cmp word [frame_cnt], 200
    jl .no_speed
    mov word [frame_cnt], 0
    cmp word [speed], 8
    jge .no_speed
    inc word [speed]
    add word [score], 50
.no_speed:

    ; Input
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp ah, 0x4B
    jne .chk_r
    mov ax, [plr_x]
    cmp ax, ROAD_L + 2
    jle .no_key
    sub word [plr_x], 4
    jmp .no_key
.chk_r:
    cmp ah, 0x4D
    jne .no_key
    mov ax, [plr_x]
    add ax, CAR_W
    cmp ax, ROAD_R - 2
    jge .no_key
    add word [plr_x], 4

.no_key:
    ; Scroll road markings
    mov ax, [speed]
    add [scroll], ax
    cmp word [scroll], 24
    jl .move_opp
    sub word [scroll], 24

.move_opp:
    ; Move opponent cars down
    mov cx, NUM_OPP
    xor si, si
.mo:
    push cx
    push si
    mov ax, [speed]
    add [opp_y + si], ax
    ; If car left screen, respawn at top
    cmp word [opp_y + si], 210
    jl .mo_ok
    call race_respawn
.mo_ok:
    ; Check collision with player
    mov ax, [opp_y + si]
    add ax, CAR_H
    cmp ax, 168          ; player top
    jl .mo_next
    cmp word [opp_y + si], 199
    jg .mo_next
    mov ax, [opp_x + si]
    cmp ax, [plr_x]
    jl .mo_col_left
    sub ax, CAR_W
    cmp ax, [plr_x]
    jg .mo_next
    jmp .crash
.mo_col_left:
    add ax, CAR_W
    cmp ax, [plr_x]
    jl .mo_next
    jmp .crash
.mo_next:
    pop si
    pop cx
    add si, 2
    loop .mo
    jmp .draw

.crash:
    mov al, 0
    call gl16_clear
    mov bx, 88
    mov dx, 96
    mov al, 12
    mov si, str_crash
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    jmp .quit

.draw:
    ; Draw road (dark grey background)
    push bx
    push cx
    push dx
    mov cx, 0
.bg_row:
    cmp cx, 200
    jge .bg_done
    mov bx, 0
    mov dx, cx
    mov al, 8           ; dark grey for sides
    call gl16_pix
    ; Road fill line
    push cx
    push dx
    mov bx, ROAD_L
    mov cx, ROAD_R
    mov al, 7           ; grey road
    call gl16_hline
    pop dx
    pop cx
    inc cx
    jmp .bg_row
.bg_done:
    pop dx
    pop cx
    pop bx

    ; Road markings (dashes)
    mov cx, 0
.dash_loop:
    cmp cx, 200
    jge .dash_done
    mov ax, cx
    add ax, [scroll]
    and ax, 0x17        ; mod 24
    cmp ax, 12
    jge .dash_skip
    ; White dash at centre of road
    mov bx, 159
    mov dx, cx
    mov al, 15
    call gl16_pix
    mov bx, 160
    call gl16_pix
.dash_skip:
    inc cx
    jmp .dash_loop
.dash_done:

    ; Draw opponent cars
    call race_draw_opponents

    ; Draw player car (red)
    mov bx, [plr_x]
    mov dx, 168
    mov cx, CAR_H
.pcar:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CAR_W - 1
    mov al, 12
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .pcar

    ; Score
    mov bx, 4
    mov dx, 4
    mov al, 15
    mov si, str_score
    call gl16_text_gfx
    inc word [score]
    mov ax, [score]
    mov si, sbuf
    call race_itoa
    mov bx, 46
    mov dx, 4
    mov al, 14
    mov si, sbuf
    call gl16_text_gfx

    call race_delay
    jmp .frame

.quit:
    call gl16_exit
    POP_ALL
ENDFN

race_init:
    push ax
    push bx
    push cx
    push si
    ; Place opponent cars
    mov cx, NUM_OPP
    xor si, si
    xor bx, bx
.ri:
    ; X: random lane within road
    call race_rand
    xor dx, dx
    push ax
    mov ax, ROAD_W - CAR_W
    mov bx, ax
    pop ax
    xor dx, dx
    div bx
    add dx, ROAD_L
    mov [opp_x + si], dx
    ; Y: spread them out
    mov ax, si
    mov bx, 40
    mul bx
    neg ax
    sub ax, 20
    mov [opp_y + si], ax
    ; Colour: alternating
    mov ax, si
    and ax, 1
    jz .col_c
    mov word [opp_col + si], 11
    jmp .ri_next
.col_c:
    mov word [opp_col + si], 6
.ri_next:
    add si, 2
    loop .ri
    pop si
    pop cx
    pop bx
    pop ax
    ret

race_respawn:
    ; SI = index (word offset)
    push ax
    push bx
    call race_rand
    xor dx, dx
    mov bx, ROAD_W - CAR_W
    div bx
    add dx, ROAD_L
    mov [opp_x + si], dx
    ; Reset Y to top with negative (above screen)
    mov word [opp_y + si], -40
    pop bx
    pop ax
    ret

race_rand:
    push bx
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    pop bx
    ret

race_draw_opponents:
    push ax
    push bx
    push cx
    push dx
    push si
    mov cx, NUM_OPP
    xor si, si
.do:
    push cx
    push si
    mov ax, [opp_y + si]
    cmp ax, 200
    jge .do_skip
    cmp ax, -CAR_H
    jle .do_skip
    mov bx, [opp_x + si]
    mov dx, ax
    cmp dx, 0
    jge .draw_car
    xor dx, dx
.draw_car:
    mov al, byte [opp_col + si]
    mov cx, CAR_H
.car_row:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CAR_W - 1
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    cmp dx, 200
    jge .do_skip
    loop .car_row
.do_skip:
    pop si
    pop cx
    add si, 2
    loop .do
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

race_itoa:
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

race_delay:
    push cx
    mov cx, 0x1500
.d:
    loop .d
    pop cx
    ret

%include "../opengl.asm"
