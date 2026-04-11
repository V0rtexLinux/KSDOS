; =============================================================================
; SNAKE.OVL  -  Classic Snake  (KSDOS 16-bit)
; WASD to move, eat food, avoid walls and yourself.  ESC = quit.
; Grid: 32 cols x 20 rows (10x10 px per cell).  Playfield: x=0..31, y=0..19
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

GCOLS   equ 32
GROWS   equ 20
CELL    equ 10
MAX_LEN equ 200
INIT_X  equ 16
INIT_Y  equ 10

STR str_title,   "SNAKE  [WASD=move  ESC=quit]"
STR str_gameover,"GAME OVER! Press any key"
STR str_score,   "Score:"
STRBUF sbuf, 6

; Snake body: arrays of X,Y grid positions
WORDBUF snk_x, MAX_LEN
WORDBUF snk_y, MAX_LEN
U16 snk_len, 5
U16 snk_dir, 0       ; 0=right 1=left 2=up 3=down
U16 food_x, 8
U16 food_y, 5
U16 score, 0
U16 lcg_seed, 0x1234

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call snek_init

.frame:
    ; ---- Check key (BIOS non-blocking) ----
    mov ah, 0x01
    int 0x16
    jz .move
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
    jmp .move
.go_up:
    cmp word [snk_dir], 3
    je .move
    mov word [snk_dir], 2
    jmp .move
.go_dn:
    cmp word [snk_dir], 2
    je .move
    mov word [snk_dir], 3
    jmp .move
.go_lt:
    cmp word [snk_dir], 0
    je .move
    mov word [snk_dir], 1
    jmp .move
.go_rt:
    cmp word [snk_dir], 1
    je .move
    mov word [snk_dir], 0

.move:
    ; ---- Shift body backward ----
    mov cx, [snk_len]
    dec cx
    jz .do_hd
.shift_loop:
    mov si, cx
    shl si, 1
    mov ax, [snk_x + si - 2]
    mov [snk_x + si], ax
    mov ax, [snk_y + si - 2]
    mov [snk_y + si], ax
    loop .shift_loop
.do_hd:
    ; ---- Advance head ----
    mov ax, [snk_x]
    mov bx, [snk_y]
    cmp word [snk_dir], 0
    jne .d1
    inc ax
    jmp .chk_bounds
.d1:
    cmp word [snk_dir], 1
    jne .d2
    dec ax
    jmp .chk_bounds
.d2:
    cmp word [snk_dir], 2
    jne .d3
    dec bx
    jmp .chk_bounds
.d3:
    inc bx
.chk_bounds:
    ; Wall collision
    cmp ax, 0
    jl .dead
    cmp ax, GCOLS
    jge .dead
    cmp bx, 0
    jl .dead
    cmp bx, GROWS
    jge .dead
    ; Self collision
    mov [snk_x], ax
    mov [snk_y], bx
    mov cx, [snk_len]
    dec cx
    jz .eat_check
    mov si, 2
.self_loop:
    cmp ax, [snk_x + si]
    jne .self_next
    cmp bx, [snk_y + si]
    je .dead
.self_next:
    add si, 2
    loop .self_loop

.eat_check:
    cmp ax, [food_x]
    jne .draw
    cmp bx, [food_y]
    jne .draw
    ; Ate food
    inc word [score]
    mov ax, [snk_len]
    cmp ax, MAX_LEN - 1
    jge .no_grow
    inc word [snk_len]
.no_grow:
    call snek_place_food

.draw:
    ; Clear screen
    mov al, 1
    call gl16_clear

    ; Draw border
    call snek_draw_border

    ; Draw food (red)
    mov ax, [food_x]
    shl ax, 1
    add ax, [food_x]
    shl ax, 1           ; ax = food_x * 6 ... actually CELL=10
    ; Recompute: px = food_x * CELL + 1
    mov ax, [food_x]
    mov bx, CELL
    mul bx
    add ax, 1
    mov bx, ax
    mov ax, [food_y]
    mov cx, CELL
    mul cx
    add ax, 1
    mov dx, ax
    ; Draw 8x8 red block
    mov cx, 8
.food_row:
    push cx
    push bx
    push dx
    mov cx, bx
    add cx, 7
    mov al, 4
    call gl16_hline
    pop dx
    pop bx
    pop cx
    inc dx
    loop .food_row

    ; Draw snake body
    mov si, 0
    mov cx, [snk_len]
.body_loop:
    push cx
    push si
    mov ax, [snk_x + si]
    mov bx, CELL
    mul bx
    add ax, 1
    mov bx, ax
    mov ax, [snk_y + si]
    mov cx, CELL
    mul cx
    add ax, 1
    mov dx, ax
    ; Colour: head=10, body=2
    cmp word si, 0
    jne .body_col
    mov al, 10
    jmp .body_draw
.body_col:
    mov al, 2
.body_draw:
    push ax
    mov cx, 8
.brow:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, 7
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .brow
    pop ax
    pop si
    pop cx
    add si, 2
    loop .body_loop

    ; Draw score
    mov bx, 204
    mov dx, 4
    mov al, 14
    mov si, str_score
    call gl16_text_gfx
    mov ax, [score]
    mov si, sbuf
    call snek_itoa
    mov bx, 246
    mov dx, 4
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx

    ; Delay
    call snek_delay
    jmp .frame

.dead:
    mov al, 0
    call gl16_clear
    mov bx, 72
    mov dx, 96
    mov al, 12
    mov si, str_gameover
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16

.quit:
    call gl16_exit
    POP_ALL
ENDFN

snek_init:
    ; Init snake at centre going right
    mov word [snk_len], 5
    mov word [snk_dir], 0
    mov word [score], 0
    mov cx, 5
    mov si, 0
    mov ax, INIT_X
.initlp:
    sub ax, 0
    mov [snk_x + si], ax
    mov word [snk_y + si], INIT_Y
    dec ax
    add si, 2
    loop .initlp
    ; Fix: head at INIT_X, body going left
    mov cx, 5
    mov si, 0
    mov ax, INIT_X
.fixlp:
    mov [snk_x + si], ax
    dec ax
    add si, 2
    loop .fixlp
    call snek_place_food
    ret

snek_place_food:
    push ax
    push bx
    ; LCG random
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    and ax, 0x1F        ; 0..31
    mov [food_x], ax
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    xor dx, dx
    mov bx, GROWS
    div bx
    mov [food_y], dx
    pop bx
    pop ax
    ret

snek_draw_border:
    push ax
    push bx
    push cx
    push dx
    ; Top
    xor bx, bx
    mov cx, GCOLS * CELL - 1
    xor dx, dx
    mov al, 7
    call gl16_hline
    ; Bottom
    mov dx, GROWS * CELL
    call gl16_hline
    ; Left col
    mov cx, GROWS * CELL
    xor bx, bx
.bl:
    xor bx, bx
    mov dx, cx
    mov al, 7
    call gl16_pix
    loop .bl
    ; Right col
    mov cx, GROWS * CELL
    mov bx, GCOLS * CELL
.br:
    mov dx, cx
    mov al, 7
    call gl16_pix
    loop .br
    pop dx
    pop cx
    pop bx
    pop ax
    ret

snek_itoa:
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, si
    add bx, 5
    mov byte [bx], 0
    dec bx
    test ax, ax
    jnz .dig
    mov byte [bx], '0'
    dec bx
    jmp .done
.dig:
    test ax, ax
    jz .done
    xor dx, dx
    mov cx, 10
    div cx
    add dl, '0'
    mov [bx], dl
    dec bx
    jmp .dig
.done:
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

snek_delay:
    push cx
    mov cx, 0x3000
.dl:
    loop .dl
    pop cx
    ret

%include "../opengl.asm"
