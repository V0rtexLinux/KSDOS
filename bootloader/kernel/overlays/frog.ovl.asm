; =============================================================================
; FROG.OVL  -  Frogger  (KSDOS 16-bit)
; Guide the frog across traffic to the safe pad.  WASD to move.  ESC=quit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

FROG_W  equ 12
FROG_H  equ 10
ROAD_Y1 equ 130        ; road top
ROAD_Y2 equ 50         ; water top (logs)
CAR_H   equ 14
NUM_CARS equ 5
NUM_LOGS equ 3

STR str_title,  "FROGGER  [WASD=move  ESC=quit]"
STR str_score,  "Score:"
STR str_lives,  "Lives:"
STR str_win,    "HOME! Any key"
STR str_dead,   "SPLAT! Any key"
STRBUF sbuf, 6

U16 frog_x, 154
U16 frog_y, 180
U16 score, 0
U16 lives, 3
U16 lcg_seed, 0x6666
U16 crossed, 0

; Cars: x, y, dx (pixels per frame), width
WORDBUF car_x, NUM_CARS
WORDBUF car_y, NUM_CARS
WORDBUF car_dx, NUM_CARS
WORDBUF car_w, NUM_CARS
; Colours
car_col: db 12, 6, 14, 11, 9

; Logs: x, y, dx, width
WORDBUF log_x, NUM_LOGS
WORDBUF log_y, NUM_LOGS
WORDBUF log_dx, NUM_LOGS
WORDBUF log_w, NUM_LOGS

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call frg_init

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
    jmp .no_key
.go_up:
    sub word [frog_y], FROG_H + 4
    jmp .chk_win
.go_dn:
    add word [frog_y], FROG_H + 4
    mov ax, [frog_y]
    cmp ax, 190
    jle .no_key
    mov word [frog_y], 190
    jmp .no_key
.go_lt:
    sub word [frog_x], FROG_W + 2
    mov ax, [frog_x]
    cmp ax, 4
    jge .no_key
    mov word [frog_x], 4
    jmp .no_key
.go_rt:
    add word [frog_x], FROG_W + 2
    mov ax, [frog_x]
    add ax, FROG_W
    cmp ax, 315
    jle .no_key
    mov word [frog_x], 315 - FROG_W
    jmp .no_key

.chk_win:
    mov ax, [frog_y]
    cmp ax, 20
    jg .no_key
    ; Reached top!
    inc word [score]
    add word [score], 50
    inc word [crossed]
    ; Reset frog
    mov word [frog_x], 154
    mov word [frog_y], 180
    jmp .no_key

.no_key:
    ; Move cars
    mov cx, NUM_CARS
    xor si, si
.mc:
    push cx
    push si
    mov ax, [car_dx + si]
    add [car_x + si], ax
    ; Wrap
    mov ax, [car_x + si]
    cmp ax, 320
    jl .mc_lw
    mov word [car_x + si], -50
    jmp .mc_done
.mc_lw:
    cmp ax, -60
    jg .mc_done
    mov word [car_x + si], 320
.mc_done:
    pop si
    pop cx
    add si, 2
    loop .mc

    ; Move logs
    mov cx, NUM_LOGS
    xor si, si
.ml:
    push cx
    push si
    mov ax, [log_dx + si]
    add [log_x + si], ax
    ; Wrap
    mov ax, [log_x + si]
    cmp ax, 320
    jl .ml_lw
    mov word [log_x + si], -80
    jmp .ml_done
.ml_lw:
    cmp ax, -90
    jg .ml_done
    mov word [log_x + si], 320
.ml_done:
    pop si
    pop cx
    add si, 2
    loop .ml

    ; Frog in water zone? Must be on log
    mov ax, [frog_y]
    cmp ax, ROAD_Y2
    jge .chk_car
    cmp ax, 20
    jl .chk_car
    ; In water: check if on any log
    push ax
    mov cx, NUM_LOGS
    xor si, si
    xor bx, bx          ; found flag
.log_chk:
    cmp cx, 0
    je .log_chk_done
    mov ax, [frog_x]
    cmp ax, [log_x + si]
    jl .log_skip
    mov dx, [log_x + si]
    add dx, [log_w + si]
    cmp ax, dx
    jg .log_skip
    mov ax, [frog_y]
    mov dx, [log_y + si]
    cmp ax, dx
    jl .log_skip
    add dx, CAR_H
    cmp ax, dx
    jg .log_skip
    ; On log — ride with it
    mov ax, [log_dx + si]
    add [frog_x], ax
    mov bx, 1
.log_skip:
    add si, 2
    dec cx
    jmp .log_chk
.log_chk_done:
    pop ax
    test bx, bx
    jz .drown
    jmp .chk_car

.drown:
    call frg_die
    jmp .draw

.chk_car:
    ; Check car collision
    mov ax, [frog_y]
    cmp ax, ROAD_Y1 - FROG_H
    jl .draw
    cmp ax, 190
    jg .draw
    mov cx, NUM_CARS
    xor si, si
.cc:
    push cx
    push si
    mov ax, [frog_x]
    cmp ax, [car_x + si]
    jl .cc_skip
    mov bx, [car_x + si]
    add bx, [car_w + si]
    cmp ax, bx
    jg .cc_skip
    mov ax, [frog_y]
    cmp ax, [car_y + si]
    jl .cc_skip
    mov bx, [car_y + si]
    add bx, CAR_H
    cmp ax, bx
    jg .cc_skip
    ; Hit by car!
    pop si
    pop cx
    call frg_die
    jmp .draw
.cc_skip:
    pop si
    pop cx
    add si, 2
    loop .cc

.draw:
    mov al, 0
    call gl16_clear
    ; Draw road (grey)
    push bx
    push cx
    push dx
    mov cx, ROAD_Y1
.road:
    cmp cx, 190
    jg .road_done
    mov bx, 0
    mov dx, cx
    mov al, 7
    push cx
    mov cx, 319
    call gl16_hline
    pop cx
    inc cx
    jmp .road
.road_done:
    ; Draw water (blue)
    mov cx, ROAD_Y2
.water:
    cmp cx, ROAD_Y1
    jge .water_done
    mov bx, 0
    mov dx, cx
    mov al, 1
    push cx
    mov cx, 319
    call gl16_hline
    pop cx
    inc cx
    jmp .water
.water_done:
    ; Safe zone (green)
    mov cx, 0
.safe:
    cmp cx, ROAD_Y2
    jge .safe_done
    mov bx, 0
    mov dx, cx
    mov al, 2
    push cx
    mov cx, 319
    call gl16_hline
    pop cx
    inc cx
    jmp .safe
.safe_done:
    pop dx
    pop cx
    pop bx

    ; Draw cars
    mov cx, NUM_CARS
    xor si, si
.dc:
    push cx
    push si
    mov bx, [car_x + si]
    mov dx, [car_y + si]
    push bx
    mov bx, si
    shr bx, 1
    mov al, [car_col + bx]
    pop bx
    push ax
    mov ax, [car_w + si]
    push ax
    mov cx, CAR_H
.car_row:
    push cx
    push dx
    push bx
    pop ax
    push ax
    mov cx, bx
    add cx, [esp + 2]   ; car_w on stack
    dec cx
    pop ax
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .car_row
    pop ax
    pop ax
    pop si
    pop cx
    add si, 2
    loop .dc

    ; Draw logs
    mov cx, NUM_LOGS
    xor si, si
.dl:
    push cx
    push si
    mov bx, [log_x + si]
    mov dx, [log_y + si]
    push dx
    push bx
    mov ax, [log_w + si]
    push ax
    mov cx, CAR_H - 2
.log_row:
    push cx
    pop bx
    pop dx
    push dx
    push bx
    mov cx, bx
    add cx, [esp + 2]
    dec cx
    mov al, 6
    call gl16_hline
    pop bx
    pop dx
    push dx
    push bx
    inc dx
    pop bx
    pop dx
    push dx
    push bx
    pop cx
    dec cx
    push cx
    jmp .log_row_end
.log_row_end:
    pop cx
    pop dx
    pop dx
    pop bx
    pop ax
    pop si
    pop cx
    add si, 2
    loop .dl

    ; Draw frog (green)
    mov bx, [frog_x]
    mov dx, [frog_y]
    mov cx, FROG_H
.fr:
    push cx
    push dx
    push bx
    mov cx, bx
    add cx, FROG_W - 1
    mov al, 10
    call gl16_hline
    pop bx
    pop dx
    pop cx
    inc dx
    loop .fr

    ; UI
    mov bx, 4
    mov dx, 4
    mov al, 15
    mov si, str_title
    call gl16_text_gfx
    call frg_delay
    ; Clamp frog x
    mov ax, [frog_x]
    cmp ax, 4
    jge .fx_ok
    mov word [frog_x], 4
.fx_ok:
    add ax, FROG_W
    cmp ax, 315
    jle .frame
    mov word [frog_x], 315 - FROG_W
    jmp .frame

.quit:
    call gl16_exit
    POP_ALL
ENDFN

frg_init:
    ; Init cars
    mov word [car_x],     20
    mov word [car_y],     150
    mov word [car_dx],    2
    mov word [car_w],     40

    mov word [car_x+2],   120
    mov word [car_y+2],   150
    mov word [car_dx+2],  2
    mov word [car_w+2],   30

    mov word [car_x+4],   180
    mov word [car_y+4],   165
    mov word [car_dx+4],  -2
    mov word [car_w+4],   45

    mov word [car_x+6],   80
    mov word [car_y+6],   140
    mov word [car_dx+6],  3
    mov word [car_w+6],   35

    mov word [car_x+8],   250
    mov word [car_y+8],   175
    mov word [car_dx+8],  -3
    mov word [car_w+8],   50

    ; Init logs
    mov word [log_x],     30
    mov word [log_y],     80
    mov word [log_dx],    2
    mov word [log_w],     80

    mov word [log_x+2],   160
    mov word [log_y+2],   60
    mov word [log_dx+2],  -1
    mov word [log_w+2],   90

    mov word [log_x+4],   60
    mov word [log_y+4],   100
    mov word [log_dx+4],  2
    mov word [log_w+4],   70
    ret

frg_die:
    dec word [lives]
    mov word [frog_x], 154
    mov word [frog_y], 180
    cmp word [lives], 0
    jg .fd_ok
    ; Game over
    mov al, 0
    call gl16_clear
    mov bx, 108
    mov dx, 96
    mov al, 12
    mov si, str_dead
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    call gl16_exit
    POP_ALL
    ; Jump back to caller
    jmp 0xDEAD           ; OS will reclaim; just return
.fd_ok:
    ret

frg_delay:
    push cx
    mov cx, 0x2000
.d: loop .d
    pop cx
    ret

%include "../opengl.asm"
