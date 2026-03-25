; =============================================================================
; OPENGL.OVL - KSDOS Software OpenGL 16-bit Renderer Overlay  v2.1
; Demos: Rotating Cube, Filled Triangles, Plasma, Starfield, Sine Wave
; Press a number key at the menu to launch a demo; any key exits each demo.
; =============================================================================
BITS 16
ORG OVERLAY_BUF

%include "ovl_api.asm"

; ---------------------------------------------------------------------------
; Entry point - main menu
; ---------------------------------------------------------------------------
ovl_entry:
    call gl16_init

.menu:
    mov al, 1
    call gl16_clear

    ; Title bar
    mov bx, 60
    mov dx, 8
    mov al, 15
    mov si, str_title
    call gl16_text_gfx

    mov bx, 52
    mov dx, 20
    mov al, 11
    mov si, str_m1
    call gl16_text_gfx

    mov bx, 52
    mov dx, 30
    mov al, 10
    mov si, str_m2
    call gl16_text_gfx

    mov bx, 52
    mov dx, 40
    mov al, 14
    mov si, str_m3
    call gl16_text_gfx

    mov bx, 52
    mov dx, 50
    mov al, 13
    mov si, str_m4
    call gl16_text_gfx

    mov bx, 52
    mov dx, 60
    mov al, 12
    mov si, str_m5
    call gl16_text_gfx

    mov bx, 52
    mov dx, 80
    mov al, 7
    mov si, str_quit
    call gl16_text_gfx

    call kbd_getkey

    cmp al, '1'
    je .do_cube
    cmp al, '2'
    je .do_tri
    cmp al, '3'
    je .do_plasma
    cmp al, '4'
    je .do_stars
    cmp al, '5'
    je .do_sine
    cmp al, 27          ; ESC
    je .exit
    cmp al, 'Q'
    je .exit
    cmp al, 'q'
    je .exit
    jmp .menu

.do_cube:
    call gl16_cube_demo
    jmp .menu

.do_tri:
    call gl16_triangle_demo
    jmp .menu

.do_plasma:
    call gl16_plasma_demo
    jmp .menu

.do_stars:
    call gl16_stars_demo
    jmp .menu

.do_sine:
    call gl16_sine_demo
    jmp .menu

.exit:
    call gl16_exit
    ret

str_title: db "KSDOS OpenGL 16-bit  v2.1", 0
str_m1:    db "1 - Rotating Wireframe Cube", 0
str_m2:    db "2 - Filled Triangle Spinner", 0
str_m3:    db "3 - Plasma Effect", 0
str_m4:    db "4 - 3D Starfield", 0
str_m5:    db "5 - Sine Wave Oscilloscope", 0
str_quit:  db "ESC - Exit", 0

; ---------------------------------------------------------------------------
; Include base renderer (cube, triangle, font, sin/cos table, etc.)
; ---------------------------------------------------------------------------
%include "../opengl.asm"

; ===========================================================================
; gl16_plasma_demo: XOR palette-cycling plasma  [key = exit]
; Each pixel colour = ((x XOR y) + frame) & 0xFF, drawn one row at a time.
; ===========================================================================
_pl_frame:  dw 0
_pl_y:      dw 0
_pl_x:      dw 0

gl16_plasma_demo:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov word [_pl_frame], 0

.pl_frame:
    call kbd_check
    jnz .pl_exit

    ; Draw one full frame row by row
    mov word [_pl_y], 0
.pl_row:
    mov dx, [_pl_y]
    cmp dx, MODE13_H
    jae .pl_row_done

    mov word [_pl_x], 0
.pl_pixel:
    mov bx, [_pl_x]
    cmp bx, MODE13_W
    jae .pl_next_row

    ; colour = (x XOR y XOR (y>>1) + frame) & 0xFF
    mov ax, bx
    xor ax, dx
    mov cx, dx
    shr cx, 1
    xor ax, cx
    add ax, [_pl_frame]
    and al, 0xFF
    cmp al, 0
    jne .pl_ok
    mov al, 1
.pl_ok:
    call gl16_pix

    inc word [_pl_x]
    jmp .pl_pixel

.pl_next_row:
    inc word [_pl_y]
    jmp .pl_row

.pl_row_done:
    add word [_pl_frame], 3
    cmp word [_pl_frame], 256
    jb .pl_frame
    mov word [_pl_frame], 0
    jmp .pl_frame

.pl_exit:
    call kbd_getkey
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ===========================================================================
; gl16_stars_demo: 64-star 3D starfield  [key = exit]
; Stars have (sx, sy) in -120..120 and sz depth 1..255.
; Projected:  px = 160 + sx*FOV/sz,  py = 100 + sy*FOV/sz
; ===========================================================================
STAR_CNT    equ 64
STAR_FOV    equ 180

star_sx:    times STAR_CNT dw 0
star_sy:    times STAR_CNT dw 0
star_sz:    times STAR_CNT dw 0

_st_i:      dw 0
_st_spd:    dw 3

gl16_stars_demo:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Seed stars with pseudo-random positions
    mov cx, STAR_CNT
    xor di, di
    mov si, 0x1234
.seed:
    ; simple LCG: next = prev*1103515245 + 12345 (we use 16-bit)
    mov ax, si
    mov bx, 25173
    mul bx
    add ax, 13849
    mov si, ax
    mov bx, ax
    and bx, 0x7F        ; 0..127
    sub bx, 64          ; -64..63  (sx)
    cmp bx, 0
    jne .sxok
    inc bx
.sxok:
    mov [star_sx + di], bx

    mov ax, si
    mov bx, 25173
    mul bx
    add ax, 13849
    mov si, ax
    mov bx, ax
    and bx, 0x3F        ; 0..63
    sub bx, 32          ; -32..31  (sy)
    cmp bx, 0
    jne .syok
    inc bx
.syok:
    mov [star_sy + di], bx

    mov ax, si
    mov bx, 25173
    mul bx
    add ax, 13849
    mov si, ax
    and ax, 0x7F
    cmp ax, 0
    jne .szok
    inc ax
.szok:
    mov [star_sz + di], ax

    add di, 2
    loop .seed

.st_frame:
    call kbd_check
    jnz .st_exit

    mov al, 0
    call gl16_clear

    mov bx, 48
    mov dx, 5
    mov al, 15
    mov si, str_stars_title
    call gl16_text_gfx

    ; Draw and update each star
    mov cx, STAR_CNT
    xor di, di
.st_draw:
    push cx
    push di

    ; Move star closer (decrease sz)
    mov ax, [star_sz + di]
    sub ax, [_st_spd]
    jg .st_alive
    ; Reset star to far depth with new position
    mov ax, 127
    mov [star_sz + di], ax
    ; Randomize sx/sy (cheap: reuse di as seed)
    mov bx, di
    add bx, si          ; si still holds LCG state
    and bx, 0x7F
    sub bx, 64
    cmp bx, 0
    jne .rsx
    inc bx
.rsx:
    mov [star_sx + di], bx
    xor bx, 0x3D
    sub bx, 32
    cmp bx, 0
    jne .rsy
    inc bx
.rsy:
    mov [star_sy + di], bx
    pop di
    pop cx
    dec cx
    jnz .st_draw
    jmp .st_frame_done

.st_alive:
    mov [star_sz + di], ax

    ; Project: px = 160 + sx*FOV/sz
    mov ax, [star_sx + di]
    mov bx, STAR_FOV
    imul bx             ; dx:ax = sx*FOV
    mov cx, [star_sz + di]
    idiv cx             ; ax = sx*FOV/sz
    add ax, 160
    mov bx, ax          ; bx = screen x

    ; py = 100 + sy*FOV/sz
    mov ax, [star_sy + di]
    mov cx, STAR_FOV
    imul cx
    mov cx, [star_sz + di]
    idiv cx
    add ax, 100
    mov dx, ax          ; dx = screen y

    ; Brightness: brighter when closer (smaller sz)
    mov ax, [star_sz + di]
    mov cx, 15
    sub cx, ax          ; rough brightness
    sar cx, 3
    add cx, 12          ; colour 12..15
    cmp cx, 15
    jle .brok
    mov cx, 15
.brok:
    cmp cx, 1
    jge .brok2
    mov cx, 1
.brok2:
    mov al, cl
    call gl16_pix

    pop di
    pop cx
    add di, 2
    dec cx
    jnz .st_draw

.st_frame_done:
    jmp .st_frame

.st_exit:
    call kbd_getkey
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

str_stars_title: db "KSDOS StarField 3D [key=exit]", 0

; ===========================================================================
; gl16_sine_demo: animated dual sine-wave oscilloscope  [key = exit]
; Draws two sine waves (offset by 90 deg phase) scrolling across screen.
; ===========================================================================
_sw_phase:  dw 0

gl16_sine_demo:
    push ax
    push bx
    push cx
    push dx
    push si

    mov word [_sw_phase], 0

.sw_frame:
    call kbd_check
    jnz .sw_exit

    mov al, 0
    call gl16_clear

    mov bx, 48
    mov dx, 5
    mov al, 14
    mov si, str_sine_title
    call gl16_text_gfx

    ; Draw wave 1 (yellow): y = 100 + sin(x*2 + phase) * 60
    mov bx, 0
.sw1_loop:
    cmp bx, MODE13_W
    jae .sw1_done
    push bx
    ; angle = bx*2 + phase (mod 360)
    mov ax, bx
    shl ax, 1
    add ax, [_sw_phase]
    mov cx, 360
    xor dx, dx
    div cx
    mov ax, dx          ; remainder = angle mod 360
    call fsin16         ; ax = sin*256
    ; scale: y = 100 + ax*60/256 = 100 + ax*15/64
    mov cx, 15
    imul cx             ; dx:ax = sin*256 * 15
    sar ax, 6           ; ax / 64 --> sin*60
    add ax, 100
    mov dx, ax
    pop bx
    mov al, 14          ; yellow
    call gl16_pix
    inc bx
    jmp .sw1_loop
.sw1_done:

    ; Draw wave 2 (cyan, 90 deg phase shift):
    mov bx, 0
.sw2_loop:
    cmp bx, MODE13_W
    jae .sw2_done
    push bx
    mov ax, bx
    shl ax, 1
    add ax, [_sw_phase]
    add ax, 90          ; 90-degree phase shift
    mov cx, 360
    xor dx, dx
    div cx
    mov ax, dx
    call fsin16
    mov cx, 15
    imul cx
    sar ax, 6
    add ax, 100
    mov dx, ax
    pop bx
    mov al, 11          ; cyan
    call gl16_pix
    inc bx
    jmp .sw2_loop
.sw2_done:

    add word [_sw_phase], 4
    cmp word [_sw_phase], 360
    jb .sw_frame
    mov word [_sw_phase], 0
    jmp .sw_frame

.sw_exit:
    call kbd_getkey
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

str_sine_title: db "Sine Wave Oscilloscope [key=exit]", 0
