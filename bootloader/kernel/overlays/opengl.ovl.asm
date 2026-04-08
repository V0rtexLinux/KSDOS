; =============================================================================
; OPENGL.OVL  -  KSDOS Software OpenGL 16-bit Renderer  v2.1
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Demos: Rotating Cube, Filled Triangles, Plasma, Starfield, Sine Wave.
; Press a number key at the menu to launch a demo; any key exits each demo.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static menu strings
; ---------------------------------------------------------------------------
STR str_title, "KSDOS OpenGL 16-bit  v2.1"
STR str_m1,    "1 - Rotating Wireframe Cube"
STR str_m2,    "2 - Filled Triangle Spinner"
STR str_m3,    "3 - Plasma Effect"
STR str_m4,    "4 - 3D Starfield"
STR str_m5,    "5 - Sine Wave Oscilloscope"
STR str_quit,  "ESC - Exit"

; ---------------------------------------------------------------------------
; U0 ovl_entry()  -  main menu loop
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    call gl16_init

.menu:
    mov al, 1
    call gl16_clear

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

    GetKey

    cmp al, '1'
    IF e
        call gl16_cube_demo
        jmp .menu
    ENDIF
    cmp al, '2'
    IF e
        call gl16_triangle_demo
        jmp .menu
    ENDIF
    cmp al, '3'
    IF e
        call gl16_plasma_demo
        jmp .menu
    ENDIF
    cmp al, '4'
    IF e
        call gl16_stars_demo
        jmp .menu
    ENDIF
    cmp al, '5'
    IF e
        call gl16_sine_demo
        jmp .menu
    ENDIF

    cmp al, 27          ; ESC
    IF e
        jmp .exit
    ENDIF
    cmp al, 'Q'
    IF e
        jmp .exit
    ENDIF
    cmp al, 'q'
    IF e
        jmp .exit
    ENDIF
    jmp .menu

.exit:
    call gl16_exit
ENDFN

; ---------------------------------------------------------------------------
; Include base renderer (cube, triangle, font, sin/cos tables, etc.)
; ---------------------------------------------------------------------------
%include "../opengl.asm"

; ===========================================================================
; Plasma, Starfield, and Sine demos (complex render routines — kept as raw
; assembly since they are tight inner loops with carefully managed registers)
; ===========================================================================

; ---------------------------------------------------------------------------
; Plasma demo data
; ---------------------------------------------------------------------------
U16 _pl_frame, 0
U16 _pl_y,     0
U16 _pl_x,     0

; ---------------------------------------------------------------------------
; U0 gl16_plasma_demo()
; XOR palette-cycling plasma. Pixel colour = ((x XOR y) + frame) & 0xFF.
; Any keypress exits.
; ---------------------------------------------------------------------------
FN U0, gl16_plasma_demo
    PUSH_ALL
    push es

    mov word [_pl_frame], 0

.pl_frame:
    CheckKey
    jnz .pl_exit

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
    jb  .pl_frame
    mov word [_pl_frame], 0
    jmp .pl_frame

.pl_exit:
    GetKey
    pop es
    POP_ALL
ENDFN

; ---------------------------------------------------------------------------
; Starfield demo data
; ---------------------------------------------------------------------------
STAR_CNT    equ 64
STAR_FOV    equ 180

WORDBUF star_sx, STAR_CNT
WORDBUF star_sy, STAR_CNT
WORDBUF star_sz, STAR_CNT

U16 _st_i,   0
U16 _st_spd, 3

STR str_stars_title, "KSDOS StarField 3D [key=exit]"

; ---------------------------------------------------------------------------
; U0 gl16_stars_demo()
; 64-star 3D starfield.  px = 160 + sx*FOV/sz,  py = 100 + sy*FOV/sz.
; ---------------------------------------------------------------------------
FN U0, gl16_stars_demo
    PUSH_ALL

    ; Seed stars with LCG pseudo-random positions
    mov cx, STAR_CNT
    xor di, di
    mov si, 0x1234
.seed:
    mov ax, si
    mov bx, 25173
    mul bx
    add ax, 13849
    mov si, ax
    mov bx, ax
    and bx, 0x7F
    sub bx, 64
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
    and bx, 0x3F
    sub bx, 32
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
    CheckKey
    jnz .st_exit

    mov al, 0
    call gl16_clear

    mov bx, 48
    mov dx, 5
    mov al, 15
    mov si, str_stars_title
    call gl16_text_gfx

    mov cx, STAR_CNT
    xor di, di
.st_draw:
    push cx
    push di

    mov ax, [star_sz + di]
    sub ax, [_st_spd]
    jg .st_alive

    mov ax, 127
    mov [star_sz + di], ax
    mov bx, di
    add bx, si
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

    mov ax, [star_sx + di]
    mov bx, STAR_FOV
    imul bx
    mov cx, [star_sz + di]
    idiv cx
    add ax, 160
    mov bx, ax

    mov ax, [star_sy + di]
    mov cx, STAR_FOV
    imul cx
    mov cx, [star_sz + di]
    idiv cx
    add ax, 100
    mov dx, ax

    mov ax, [star_sz + di]
    mov cx, 15
    sub cx, ax
    sar cx, 3
    add cx, 12
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
    GetKey
    POP_ALL
ENDFN

; ---------------------------------------------------------------------------
; Sine Wave demo data
; ---------------------------------------------------------------------------
U16 _sw_phase, 0
STR str_sine_title, "Sine Wave Oscilloscope [key=exit]"

; ---------------------------------------------------------------------------
; U0 gl16_sine_demo()
; Animated dual sine-wave oscilloscope.
; ---------------------------------------------------------------------------
FN U0, gl16_sine_demo
    PUSH_ALL

    mov word [_sw_phase], 0

.sw_frame:
    CheckKey
    jnz .sw_exit

    mov al, 0
    call gl16_clear

    mov bx, 48
    mov dx, 5
    mov al, 14
    mov si, str_sine_title
    call gl16_text_gfx

    ; Wave 1 — yellow
    mov bx, 0
.sw1_loop:
    cmp bx, MODE13_W
    jae .sw1_done
    push bx
    mov ax, bx
    shl ax, 1
    add ax, [_sw_phase]
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
    mov al, 14
    call gl16_pix
    inc bx
    jmp .sw1_loop
.sw1_done:

    ; Wave 2 — cyan (90° phase shift)
    mov bx, 0
.sw2_loop:
    cmp bx, MODE13_W
    jae .sw2_done
    push bx
    mov ax, bx
    shl ax, 1
    add ax, [_sw_phase]
    add ax, 90
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
    mov al, 11
    call gl16_pix
    inc bx
    jmp .sw2_loop
.sw2_done:

    add word [_sw_phase], 4
    cmp word [_sw_phase], 360
    jb  .sw_frame
    mov word [_sw_phase], 0
    jmp .sw_frame

.sw_exit:
    GetKey
    POP_ALL
ENDFN
