; =============================================================================
; SIMON.OVL  -  Simon Says  (KSDOS 16-bit)
; Remember and repeat the colour sequence.
; 1=Red  2=Green  3=Blue  4=Yellow.  ESC=quit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

MAX_SEQ equ 64

STR str_title,  "SIMON SAYS"
STR str_watch,  "Watch..."
STR str_repeat, "Your turn! Press 1-4"
STR str_win,    "Level:"
STR str_lose,   "WRONG! Any key"
STR str_hint,   "1=Red 2=Green 3=Blue 4=Yellow"
STRBUF sbuf, 4

STRBUF sequence, MAX_SEQ
U16 seq_len, 0
U16 lcg_seed, 0x1111

FN U0, ovl_entry
    PUSH_ALL
    call gl16_init
    mov word [seq_len], 0

.add_step:
    ; Add one random colour to sequence
    call sm_rand
    xor dx, dx
    mov bx, 4
    div bx
    inc dx                  ; 1-4
    mov bx, [seq_len]
    mov [sequence + bx], dl
    inc word [seq_len]

    ; Show title
    mov al, 0
    call gl16_clear
    mov bx, 112
    mov dx, 60
    mov al, 15
    mov si, str_title
    call gl16_text_gfx
    ; Show level
    mov bx, 112
    mov dx, 76
    mov al, 14
    mov si, str_win
    call gl16_text_gfx
    mov ax, [seq_len]
    mov si, sbuf
    call sm_itoa
    mov bx, 154
    mov dx, 76
    mov al, 15
    mov si, sbuf
    call gl16_text_gfx
    ; Show hint
    mov bx, 52
    mov dx, 180
    mov al, 7
    mov si, str_hint
    call gl16_text_gfx

    ; Playback sequence
    mov bx, 84
    mov dx, 96
    mov al, 11
    mov si, str_watch
    call gl16_text_gfx
    ; Wait briefly
    call sm_long_delay

    mov cx, [seq_len]
    xor si, si
.play:
    push cx
    push si
    movzx ax, byte [sequence + si]
    call sm_flash_colour
    call sm_med_delay
    pop si
    pop cx
    inc si
    loop .play

    ; Player's turn
    mov al, 1
    call gl16_clear
    call sm_draw_buttons
    mov bx, 76
    mov dx, 170
    mov al, 15
    mov si, str_repeat
    call gl16_text_gfx

    mov cx, [seq_len]
    xor si, si
.input:
    push cx
    push si
    ; Wait for key 1-4 or ESC
.wait_key:
    mov ah, 0x00
    int 0x16
    cmp al, 27
    je .quit_pop
    cmp al, '1'
    jb .wait_key
    cmp al, '4'
    ja .wait_key
    sub al, '0'         ; 1-4
    ; Check against sequence
    movzx bx, byte [sequence + si]
    cmp ax, bx
    jne .wrong
    ; Correct! Flash colour
    call sm_flash_colour
    call sm_short_delay
    ; Redraw buttons
    mov al, 1
    call gl16_clear
    call sm_draw_buttons
    mov bx, 76
    mov dx, 170
    mov al, 15
    mov si, str_repeat
    call gl16_text_gfx
    pop si
    pop cx
    inc si
    loop .input
    ; All correct — add next step
    jmp .add_step

.wrong:
    pop si
    pop cx
    mov al, 0
    call gl16_clear
    mov bx, 100
    mov dx, 96
    mov al, 12
    mov si, str_lose
    call gl16_text_gfx
    mov ah, 0x00
    int 0x16
    jmp .quit

.quit_pop:
    pop si
    pop cx
.quit:
    call gl16_exit
    POP_ALL
ENDFN

; sm_draw_buttons: draw 4 coloured quadrants
sm_draw_buttons:
    push ax
    push bx
    push cx
    push dx
    ; Red (1) top-left
    mov cx, 100
.r1:
    cmp cx, 160
    jg .r2s
    push cx
    mov bx, 80
    mov dx, cx
    mov al, 4
    push cx
    mov cx, 158
    call gl16_hline
    pop cx
    pop cx
    inc cx
    jmp .r1
.r2s:
    ; Green (2) top-right
    mov cx, 100
.r2:
    cmp cx, 160
    jg .r3s
    push cx
    mov bx, 162
    mov dx, cx
    mov al, 2
    push cx
    mov cx, 240
    call gl16_hline
    pop cx
    pop cx
    inc cx
    jmp .r2
.r3s:
    ; Blue (3) bottom-left
    mov cx, 162
.r3:
    cmp cx, 162 + 60
    jg .r4s
    push cx
    mov bx, 80
    mov dx, cx
    mov al, 1
    push cx
    mov cx, 158
    call gl16_hline
    pop cx
    pop cx
    inc cx
    jmp .r3
.r4s:
    ; Yellow (4) bottom-right
    mov cx, 162
.r4:
    cmp cx, 162 + 60
    jg .db_done
    push cx
    mov bx, 162
    mov dx, cx
    mov al, 6
    push cx
    mov cx, 240
    call gl16_hline
    pop cx
    pop cx
    inc cx
    jmp .r4
.db_done:
    ; Labels
    mov bx, 112
    mov dx, 126
    mov al, 15
    mov si, .s1
    call gl16_text_gfx
    mov bx, 186
    mov si, .s2
    call gl16_text_gfx
    mov bx, 112
    mov dx, 188
    mov si, .s3
    call gl16_text_gfx
    mov bx, 186
    mov si, .s4
    call gl16_text_gfx
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.s1: db "1",0
.s2: db "2",0
.s3: db "3",0
.s4: db "4",0

; sm_flash_colour: AL=colour(1-4), flash the corresponding button
sm_flash_colour:
    push ax
    push bx
    push cx
    push dx
    push si
    mov si, ax
    ; Determine quadrant
    cmp si, 1
    je .fl1
    cmp si, 2
    je .fl2
    cmp si, 3
    je .fl3
    ; Yellow
    mov cx, 162
.fl4l:
    cmp cx, 162 + 60
    jg .fl_done
    push cx
    mov bx, 162
    mov dx, cx
    mov al, 14          ; bright yellow
    push cx
    mov cx, 240
    call gl16_hline
    pop cx
    pop cx
    inc cx
    jmp .fl4l
.fl1:
    mov cx, 100
.fl1l:
    cmp cx, 160
    jg .fl_done
    push cx
    mov bx, 80
    mov dx, cx
    mov al, 12          ; bright red
    push cx
    mov cx, 158
    call gl16_hline
    pop cx
    pop cx
    inc cx
    jmp .fl1l
.fl2:
    mov cx, 100
.fl2l:
    cmp cx, 160
    jg .fl_done
    push cx
    mov bx, 162
    mov dx, cx
    mov al, 10          ; bright green
    push cx
    mov cx, 240
    call gl16_hline
    pop cx
    pop cx
    inc cx
    jmp .fl2l
.fl3:
    mov cx, 162
.fl3l:
    cmp cx, 162 + 60
    jg .fl_done
    push cx
    mov bx, 80
    mov dx, cx
    mov al, 9           ; bright blue
    push cx
    mov cx, 158
    call gl16_hline
    pop cx
    pop cx
    inc cx
    jmp .fl3l
.fl_done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

sm_rand:
    push bx
    mov ax, [lcg_seed]
    mov bx, 25173
    mul bx
    add ax, 13849
    mov [lcg_seed], ax
    pop bx
    ret

sm_short_delay:
    push cx
    mov cx, 0x4000
.d: loop .d
    pop cx
    ret

sm_med_delay:
    push cx
    mov cx, 0x8000
.d: loop .d
    pop cx
    ret

sm_long_delay:
    push cx
    push bx
    mov bx, 4
.outer:
    mov cx, 0xFFFF
.d: loop .d
    dec bx
    jnz .outer
    pop bx
    pop cx
    ret

sm_itoa:
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
