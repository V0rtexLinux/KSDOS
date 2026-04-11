; =============================================================================
; PONG.OVL  -  Classic Pong  (KSDOS 16-bit)
; Player = right paddle (UP/DOWN arrows)   CPU = left paddle (auto-follow)
; ESC to quit
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

SCR_W   equ 320
SCR_H   equ 200
PAD_W   equ 4
PAD_H   equ 24
BALL_S  equ 3
SCORE_Y equ 4

STR str_title, "PONG  [UP/DN=move  ESC=quit]"
STR str_score_sep, ":"

U16 ball_x,  160
U16 ball_y,  100
I16 ball_vx,  2
I16 ball_vy,  1
U16 lpad_y,  88       ; CPU left paddle
U16 rpad_y,  88       ; Player right paddle
U16 score_l,  0
U16 score_r,  0

; Score number buffers
STRBUF sbuf_l, 4
STRBUF sbuf_r, 4

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    call gl16_init      ; double call to ensure palette is set

.frame:
    ; ---- check keyboard (BIOS non-blocking) ----
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    cmp al, 27          ; ESC
    je .quit
    cmp ah, 0x48        ; UP scancode
    jne .chk_dn
    mov ax, [rpad_y]
    cmp ax, 4
    jle .no_key
    sub word [rpad_y], 3
    jmp .no_key
.chk_dn:
    cmp ah, 0x50        ; DOWN scancode
    jne .no_key
    mov ax, [rpad_y]
    add ax, PAD_H
    cmp ax, SCR_H - 4
    jge .no_key
    add word [rpad_y], 3
.no_key:

    ; ---- CPU left paddle follows ball ----
    mov ax, [ball_y]
    sub ax, PAD_H / 2
    cmp ax, 4
    jge .cpu_ok_lo
    mov ax, 4
.cpu_ok_lo:
    cmp ax, SCR_H - PAD_H - 4
    jle .cpu_ok_hi
    mov ax, SCR_H - PAD_H - 4
.cpu_ok_hi:
    mov bx, [lpad_y]
    cmp ax, bx
    jl .cpu_up
    jg .cpu_dn
    jmp .cpu_done
.cpu_up:
    sub word [lpad_y], 2
    jmp .cpu_done
.cpu_dn:
    add word [lpad_y], 2
.cpu_done:

    ; ---- move ball ----
    mov ax, [ball_x]
    add ax, [ball_vx]
    mov [ball_x], ax
    mov ax, [ball_y]
    add ax, [ball_vy]
    mov [ball_y], ax

    ; ---- top/bottom bounce ----
    mov ax, [ball_y]
    cmp ax, 2
    jge .bt_ok
    neg word [ball_vy]
    mov word [ball_y], 2
    jmp .ball_bounds
.bt_ok:
    add ax, BALL_S
    cmp ax, SCR_H - 2
    jle .ball_bounds
    neg word [ball_vy]
    mov ax, SCR_H - 2 - BALL_S
    mov [ball_y], ax
.ball_bounds:

    ; ---- left paddle collision (x=8..8+PAD_W) ----
    mov ax, [ball_x]
    cmp ax, 8 + PAD_W
    jg .chk_right
    cmp ax, 8
    jl .chk_right
    mov bx, [ball_y]
    cmp bx, [lpad_y]
    jl .miss_left
    mov cx, [lpad_y]
    add cx, PAD_H
    cmp bx, cx
    jg .miss_left
    neg word [ball_vx]
    mov word [ball_x], 8 + PAD_W + 1
    jmp .chk_right
.miss_left:
    ; Ball passed left paddle — right scores
    inc word [score_r]
    call pong_reset
    jmp .draw

    ; ---- right paddle collision (x=SCR_W-8-PAD_W..SCR_W-8) ----
.chk_right:
    mov ax, [ball_x]
    add ax, BALL_S
    cmp ax, SCR_W - 8 - PAD_W
    jl .chk_miss_r
    cmp ax, SCR_W - 8
    jg .chk_miss_r
    mov bx, [ball_y]
    cmp bx, [rpad_y]
    jl .miss_right
    mov cx, [rpad_y]
    add cx, PAD_H
    cmp bx, cx
    jg .miss_right
    neg word [ball_vx]
    mov ax, SCR_W - 8 - PAD_W - BALL_S - 1
    mov [ball_x], ax
    jmp .draw
.chk_miss_r:
    jmp .draw
.miss_right:
    inc word [score_l]
    call pong_reset

    ; ---- draw ----
.draw:
    ; Clear screen
    mov al, 0
    call gl16_clear

    ; Centre line dashes
    mov cx, 0
.dash_loop:
    cmp cx, SCR_H
    jge .dash_done
    mov bx, 159
    mov dx, cx
    mov al, 8
    call gl16_pix
    add cx, 4
    jmp .dash_loop
.dash_done:

    ; Left paddle (CPU) — colour 11 cyan
    call pong_draw_lpad

    ; Right paddle (player) — colour 10 green
    call pong_draw_rpad

    ; Ball — colour 15 white
    mov bx, [ball_x]
    mov dx, [ball_y]
    mov cx, BALL_S
.brow:
    push cx
    push dx
    mov cx, BALL_S
.bcol:
    mov al, 15
    call gl16_pix
    inc bx
    loop .bcol
    mov bx, [ball_x]
    pop dx
    pop cx
    inc dx
    loop .brow

    ; Score text
    call pong_draw_scores

    ; Brief delay (BIOS timer)
    call pong_delay

    jmp .frame

.quit:
    call gl16_exit
    POP_ALL
ENDFN

pong_reset:
    mov word [ball_x], 160
    mov word [ball_y], 100
    ; Alternate serve direction
    neg word [ball_vx]
    mov word [ball_vy], 1
    ret

pong_draw_lpad:
    push ax
    push bx
    push cx
    push dx
    mov dx, [lpad_y]
    mov cx, PAD_H
.lp:
    mov bx, 8
    mov ax, dx
    cmp ax, SCR_H
    jge .lp_done
    ; draw PAD_W wide hline
    push cx
    mov cx, 8 + PAD_W - 1
    mov al, 11
    call gl16_hline
    pop cx
    inc dx
    loop .lp
.lp_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

pong_draw_rpad:
    push ax
    push bx
    push cx
    push dx
    mov dx, [rpad_y]
    mov cx, PAD_H
.rp:
    mov bx, SCR_W - 8 - PAD_W
    mov ax, dx
    cmp ax, SCR_H
    jge .rp_done
    push cx
    mov cx, SCR_W - 8 - 1
    mov al, 10
    call gl16_hline
    pop cx
    inc dx
    loop .rp
.rp_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

pong_draw_scores:
    push ax
    push bx
    push cx
    push dx
    push si
    ; Convert score_l to string
    mov ax, [score_l]
    mov si, sbuf_l
    call pong_itoa
    mov bx, 100
    mov dx, SCORE_Y
    mov al, 14
    mov si, sbuf_l
    call gl16_text_gfx

    ; Separator
    mov bx, 152
    mov dx, SCORE_Y
    mov al, 7
    mov si, str_score_sep
    call gl16_text_gfx

    ; score_r
    mov ax, [score_r]
    mov si, sbuf_r
    call pong_itoa
    mov bx, 164
    mov dx, SCORE_Y
    mov al, 14
    mov si, sbuf_r
    call gl16_text_gfx

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; pong_itoa: AX=number, SI=buffer (4 bytes) -> null-terminated string
pong_itoa:
    push ax
    push bx
    push cx
    push dx
    push si
    mov bx, si
    add bx, 3
    mov byte [bx], 0    ; null
    dec bx
    xor cx, cx
    test ax, ax
    jnz .digits
    mov byte [bx], '0'
    dec bx
    jmp .done
.digits:
    test ax, ax
    jz .done
    xor dx, dx
    mov cx, 10
    div cx
    add dl, '0'
    mov [bx], dl
    dec bx
    jmp .digits
.done:
    ; Copy to start of buffer
    inc bx
    mov di, si
.cpy:
    mov al, [bx]
    mov [di], al
    test al, al
    jz .cpydone
    inc bx
    inc di
    jmp .cpy
.cpydone:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

pong_delay:
    push cx
    mov cx, 0x2000
.dl:
    loop .dl
    pop cx
    ret

%include "../opengl.asm"
