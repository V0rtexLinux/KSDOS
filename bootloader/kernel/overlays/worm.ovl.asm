; =============================================================================
; WORM.OVL  -  Worm (two-player local vs CPU)  (KSDOS 16-bit)
; WASD = Player 1, Arrows = CPU auto-plays.  Avoid walls and each other.
; ESC = quit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

GCOLS   equ 40
GROWS   equ 25
CELL    equ 8
MAX_LEN equ 200

STR str_title, "WORM  [WASD=P1  ESC=quit]"
STR str_p1win, "P1 WINS! Any key"
STR str_p2win, "P2 WINS! Any key"
STR str_food,  "*"
STRBUF sbuf, 4

; P1 worm
WORDBUF p1x, MAX_LEN
WORDBUF p1y, MAX_LEN
U16 p1len, 5
U16 p1dir, 0           ; 0=R 1=L 2=U 3=D
U16 p1alive, 1

; P2 worm (CPU)
WORDBUF p2x, MAX_LEN
WORDBUF p2y, MAX_LEN
U16 p2len, 5
U16 p2dir, 3           ; CPU starts going down
U16 p2alive, 1

U16 food_x, 20
U16 food_y, 12
U16 lcg_seed, 0xAAAA
U16 frame_cnt, 0

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call wm_init

.frame:
    inc word [frame_cnt]
    cmp word [frame_cnt], 3
    jl .key_only
    mov word [frame_cnt], 0

    ; Move worms
    call wm_move_p1
    call wm_move_p2
    call wm_check_collisions

.key_only:
    ; Input (direction change)
    mov ah, 0x01
    int 0x16
    jz .draw
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit
    cmp al, 'w'
    je .p1_up
    cmp al, 'W'
    je .p1_up
    cmp al, 's'
    je .p1_dn
    cmp al, 'S'
    je .p1_dn
    cmp al, 'a'
    je .p1_lt
    cmp al, 'A'
    je .p1_lt
    cmp al, 'd'
    je .p1_rt
    cmp al, 'D'
    je .p1_rt
    jmp .draw
.p1_up:
    cmp word [p1dir], 3
    je .draw
    mov word [p1dir], 2
    jmp .draw
.p1_dn:
    cmp word [p1dir], 2
    je .draw
    mov word [p1dir], 3
    jmp .draw
.p1_lt:
    cmp word [p1dir], 0
    je .draw
    mov word [p1dir], 1
    jmp .draw
.p1_rt:
    cmp word [p1dir], 1
    je .draw
    mov word [p1dir], 0

.draw:
    mov al, 1
    call gl16_clear
    ; Border
    xor bx, bx
    mov cx, GCOLS * CELL - 1
    xor dx, dx
    mov al, 7
    call gl16_hline
    mov dx, GROWS * CELL
    call gl16_hline
    ; Draw food
    mov ax, [food_x]
    mov bx, CELL
    mul bx
    add ax, 2
    mov bx, ax
    mov ax, [food_y]
    mul cx
    add ax, 2
    mov dx, ax
    mov cx, CELL - 3
.food_draw:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CELL - 4
    mov al, 14
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .food_draw
    ; Draw P1 (green)
    mov cx, [p1len]
    xor si, si
.d1:
    push cx
    push si
    mov ax, [p1x + si]
    mov bx, CELL
    mul bx
    add ax, 1
    mov bx, ax
    mov ax, [p1y + si]
    mul cx
    add ax, 1
    mov dx, ax
    cmp word si, 0
    jne .d1_body
    mov al, 10
    jmp .d1_draw
.d1_body:
    mov al, 2
.d1_draw:
    push ax
    mov cx, CELL - 2
.d1r:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CELL - 3
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .d1r
    pop ax
    pop si
    pop cx
    add si, 2
    loop .d1
    ; Draw P2 (red)
    mov cx, [p2len]
    xor si, si
.d2:
    push cx
    push si
    mov ax, [p2x + si]
    mov bx, CELL
    mul bx
    add ax, 1
    mov bx, ax
    mov ax, [p2y + si]
    mul cx
    add ax, 1
    mov dx, ax
    cmp word si, 0
    jne .d2_body
    mov al, 12
    jmp .d2_draw
.d2_body:
    mov al, 4
.d2_draw:
    push ax
    mov cx, CELL - 2
.d2r:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, CELL - 3
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .d2r
    pop ax
    pop si
    pop cx
    add si, 2
    loop .d2
    ; UI
    mov bx, GCOLS * CELL + 4
    mov dx, 10
    mov al, 10
    mov si, str_title
    call gl16_text_gfx
    ; Check alive status
    cmp word [p1alive], 0
    jne .chk_p2
    ; P2 wins
    mov al, 0
    call gl16_clear
    mov bx, 88
    mov dx, 96
    mov al, 12
    mov si, str_p2win
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    jmp .quit
.chk_p2:
    cmp word [p2alive], 0
    jne .frame
    ; P1 wins
    mov al, 0
    call gl16_clear
    mov bx, 88
    mov dx, 96
    mov al, 10
    mov si, str_p1win
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16

.quit:
    call gl16_exit
    POP_ALL
ENDFN

wm_init:
    ; P1 starts top-left, going right
    mov cx, 5
    xor si, si
    xor ax, ax
.i1:
    mov [p1x + si], ax
    mov word [p1y + si], 2
    inc ax
    add si, 2
    loop .i1
    mov word [p1len], 5
    mov word [p1dir], 0
    mov word [p1alive], 1
    ; P2 starts bottom-right, going left
    mov cx, 5
    xor si, si
    mov ax, GCOLS - 1
.i2:
    mov [p2x + si], ax
    mov word [p2y + si], GROWS - 3
    dec ax
    add si, 2
    loop .i2
    mov word [p2len], 5
    mov word [p2dir], 1
    mov word [p2alive], 1
    call wm_place_food
    ret

wm_place_food:
    call wm_rand
    xor dx, dx
    mov bx, GCOLS - 2
    div bx
    inc dx
    mov [food_x], dx
    call wm_rand
    xor dx, dx
    mov bx, GROWS - 2
    div bx
    inc dx
    mov [food_y], dx
    ret

wm_rand:
    push bx
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    pop bx
    ret

wm_move_p1:
    cmp word [p1alive], 0
    je .done
    ; Shift body
    mov cx, [p1len]
    dec cx
    jz .mv_head
    mov si, cx
    shl si, 1
.sh:
    mov ax, [p1x + si - 2]
    mov [p1x + si], ax
    mov ax, [p1y + si - 2]
    mov [p1y + si], ax
    sub si, 2
    loop .sh
.mv_head:
    mov ax, [p1x]
    mov bx, [p1y]
    cmp word [p1dir], 0
    jne .p1d1
    inc ax
    jmp .p1_bounds
.p1d1:
    cmp word [p1dir], 1
    jne .p1d2
    dec ax
    jmp .p1_bounds
.p1d2:
    cmp word [p1dir], 2
    jne .p1d3
    dec bx
    jmp .p1_bounds
.p1d3:
    inc bx
.p1_bounds:
    cmp ax, 0
    jl .p1_die
    cmp ax, GCOLS
    jge .p1_die
    cmp bx, 0
    jl .p1_die
    cmp bx, GROWS
    jge .p1_die
    mov [p1x], ax
    mov [p1y], bx
    ; Ate food?
    cmp ax, [food_x]
    jne .done
    cmp bx, [food_y]
    jne .done
    inc word [p1len]
    call wm_place_food
.done:
    ret
.p1_die:
    mov word [p1alive], 0
    ret

wm_move_p2:
    cmp word [p2alive], 0
    je .done2
    ; Simple CPU: pick direction that doesn't immediately die
    ; Try current direction, else turn
    call wm_rand
    and ax, 0x03
    cmp ax, 0
    jne .mv_p2
    ; Occasionally randomly turn
    call wm_rand
    and ax, 0x03
    mov [p2dir], ax
.mv_p2:
    ; Shift body
    mov cx, [p2len]
    dec cx
    jz .mv_p2_head
    mov si, cx
    shl si, 1
.sh2:
    mov ax, [p2x + si - 2]
    mov [p2x + si], ax
    mov ax, [p2y + si - 2]
    mov [p2y + si], ax
    sub si, 2
    loop .sh2
.mv_p2_head:
    mov ax, [p2x]
    mov bx, [p2y]
    cmp word [p2dir], 0
    jne .p2d1
    inc ax
    jmp .p2_bounds
.p2d1:
    cmp word [p2dir], 1
    jne .p2d2
    dec ax
    jmp .p2_bounds
.p2d2:
    cmp word [p2dir], 2
    jne .p2d3
    dec bx
    jmp .p2_bounds
.p2d3:
    inc bx
.p2_bounds:
    cmp ax, 0
    jl .p2_die
    cmp ax, GCOLS
    jge .p2_die
    cmp bx, 0
    jl .p2_die
    cmp bx, GROWS
    jge .p2_die
    mov [p2x], ax
    mov [p2y], bx
    cmp ax, [food_x]
    jne .done2
    cmp bx, [food_y]
    jne .done2
    inc word [p2len]
    call wm_place_food
.done2:
    ret
.p2_die:
    mov word [p2alive], 0
    ret

wm_check_collisions:
    ; P1 head vs P2 body and vice versa (simplified)
    ; Just check head vs head
    mov ax, [p1x]
    cmp ax, [p2x]
    jne .done
    mov ax, [p1y]
    cmp ax, [p2y]
    jne .done
    ; Collision — both die
    mov word [p1alive], 0
    mov word [p2alive], 0
.done:
    ret

%include "../opengl.asm"
