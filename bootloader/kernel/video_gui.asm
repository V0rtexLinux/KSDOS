; =============================================================================
; video_gui.asm - KSDOS GUI Video Driver
; Amiga-style graphical interface driver
; =============================================================================

; ---- Video constants ----
VGA_MODE_320x200   equ 0x13
VGA_MODE_640x480   equ 0x12
VGA_SEGMENT        equ 0xA000
SCREEN_WIDTH       equ 320
SCREEN_HEIGHT      equ 200
SCREEN_SIZE        equ SCREEN_WIDTH * SCREEN_HEIGHT

; ---- Color palette (Amiga-style) ----
colors:
    ; 0: Black
    db 0, 0, 0
    ; 1: White
    db 63, 63, 63
    ; 2: Blue
    db 0, 0, 63
    ; 3: Red
    db 63, 0, 0
    ; 4: Green
    db 0, 63, 0
    ; 5: Yellow
    db 63, 63, 0
    ; 6: Cyan
    db 0, 63, 63
    ; 7: Magenta
    db 63, 0, 63
    ; 8: Orange
    db 63, 32, 0
    ; 9: Purple
    db 32, 0, 63
    ; 10: Light Blue
    db 0, 32, 63
    ; 11: Light Green
    db 0, 63, 32
    ; 12: Light Red
    db 63, 0, 32
    ; 13: Gray
    db 32, 32, 32
    ; 14: Light Gray
    db 48, 48, 48
    ; 15: Dark Gray
    db 16, 16, 16

; ---- GUI state ----
current_color    db 1        ; Default white
mouse_x         dw 160
mouse_y         dw 100
mouse_visible    db 1
window_count    db 0
active_window   dw 0

; ============================================================
; video_gui_init: Initialize GUI video mode
; ============================================================
video_gui_init:
    push ax
    push bx
    
    ; Set 320x200 256-color mode
    mov ax, VGA_MODE_320x200
    int 0x10
    
    ; Set up VGA segment
    mov ax, VGA_SEGMENT
    mov es, ax
    
    ; Initialize palette
    call video_set_palette
    
    ; Clear screen with black
    mov byte [current_color], 0
    call video_clear_screen
    
    ; Draw initial GUI elements
    call video_draw_desktop
    
    pop bx
    pop ax
    ret

; ============================================================
; video_set_palette: Set Amiga-style color palette
; ============================================================
video_set_palette:
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov si, colors
    mov cx, 16          ; 16 colors
    xor bx, bx          ; Start with color 0
    
.set_color:
    mov dx, 0x3C8      ; DAC write address register
    mov al, bl
    out dx, al
    
    inc dx              ; 0x3C9 - DAC data register
    
    ; Set RGB values
    mov al, [si]        ; Red
    out dx, al
    inc si
    
    mov al, [si]        ; Green  
    out dx, al
    inc si
    
    mov al, [si]        ; Blue
    out dx, al
    inc si
    
    inc bx
    loop .set_color
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; video_clear_screen: Clear screen with current color
; ============================================================
video_clear_screen:
    push ax
    push cx
    push di
    
    mov al, [current_color]
    mov ah, al          ; AH = AL = color for stosw
    mov cx, SCREEN_SIZE / 2
    xor di, di          ; Start at beginning of video memory
    rep stosw            ; Clear screen
    
    pop di
    pop cx
    pop ax
    ret

; ============================================================
; video_draw_pixel: Draw a pixel
; Input: AX = X, BX = Y
; ============================================================
video_draw_pixel:
    push ax
    push bx
    push di
    
    ; Calculate offset: Y * 320 + X
    mov di, ax          ; DI = X
    mov ax, bx          ; AX = Y
    mov bx, SCREEN_WIDTH
    mul bx              ; AX = Y * 320
    add di, ax          ; DI = Y * 320 + X
    
    ; Draw pixel
    mov al, [current_color]
    mov [es:di], al
    
    pop di
    pop bx
    pop ax
    ret

; ============================================================
; video_draw_line: Draw a line
; Input: AX = X1, BX = Y1, CX = X2, DX = Y2
; ============================================================
video_draw_line:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Bresenham's line algorithm (simplified)
    mov si, cx          ; SI = X2
    mov di, dx          ; DI = Y2
    
    ; Calculate deltas
    sub cx, ax          ; CX = X2 - X1
    sub dx, bx          ; DX = Y2 - Y1
    
    ; Get absolute values
    jns .dx_positive
    neg dx
.dx_positive:
    
    jns .cx_positive  
    neg cx
.cx_positive:
    
    ; Simple line drawing (for demonstration)
    cmp cx, dx
    jg .steep
    
.shallow:
    ; Shallow line - step in X
    mov si, cx
    test si, si
    jz .done_line
    
.draw_x:
    call video_draw_pixel
    inc ax
    dec si
    jnz .draw_x
    jmp .done_line
    
.steep:
    ; Steep line - step in Y
    mov si, dx
    test si, si
    jz .done_line
    
.draw_y:
    call video_draw_pixel
    inc bx
    dec si
    jnz .draw_y
    
.done_line:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; video_draw_rect: Draw a rectangle
; Input: AX = X, BX = Y, CX = Width, DX = Height
; ============================================================
video_draw_rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    mov si, cx          ; SI = width
    mov di, dx          ; DI = height
    
    ; Draw top edge
    push ax
    push bx
    add cx, ax          ; CX = X + Width
    call video_draw_line
    pop bx
    pop ax
    
    ; Draw bottom edge
    push ax
    add bx, di          ; BX = Y + Height
    push bx
    add cx, ax          ; CX = X + Width
    call video_draw_line
    pop bx
    pop ax
    
    ; Draw left edge
    push ax
    push bx
    add dx, bx          ; DX = Y + Height
    mov cx, ax          ; CX = X
    call video_draw_line
    pop bx
    pop ax
    
    ; Draw right edge
    push ax
    add ax, si          ; AX = X + Width
    push ax
    add dx, bx          ; DX = Y + Height
    mov cx, ax          ; CX = X
    call video_draw_line
    pop ax
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; video_fill_rect: Fill a rectangle
; Input: AX = X, BX = Y, CX = Width, DX = Height
; ============================================================
video_fill_rect:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Calculate starting position
    mov di, ax          ; DI = X
    mov ax, bx          ; AX = Y
    mov bx, SCREEN_WIDTH
    mul bx              ; AX = Y * 320
    add di, ax          ; DI = Y * 320 + X
    
    ; Fill rectangle
    mov al, [current_color]
    mov dx, cx          ; DX = width
    
.fill_row:
    push cx
    mov cx, dx
    rep stosb            ; Fill one row
    pop cx
    
    ; Move to next row
    add di, SCREEN_WIDTH
    sub di, dx          ; Subtract width to get to start of next row
    dec dx              ; Decrement height
    jnz .fill_row
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; video_draw_desktop: Draw Amiga-style desktop with icons
; ============================================================
video_draw_desktop:
    push ax
    push bx
    push cx
    push dx
    
    ; Draw background gradient (simplified)
    mov byte [current_color], 2    ; Blue
    call video_clear_screen
    
    ; Draw workbench bar at top
    mov byte [current_color], 13   ; Gray
    mov ax, 0
    mov bx, 0
    mov cx, SCREEN_WIDTH
    mov dx, 20
    call video_fill_rect
    
    ; Draw desktop icons using icon system
    ; DF0: icon at position (20, 40)
    mov ax, 20
    mov bx, 40
    call icon_draw_df0
    
    ; DH0: icon at position (60, 40)
    mov ax, 60
    mov bx, 40
    call icon_draw_dh0
    
    ; Folder icon at position (100, 40)
    mov ax, 100
    mov bx, 40
    call icon_draw_folder
    
    ; File icon at position (140, 40)
    mov ax, 140
    mov bx, 40
    call icon_draw_file
    
    ; Trash can at position (180, 40)
    mov ax, 180
    mov bx, 40
    call icon_draw_trash
    
    ; Draw sample window
    mov byte [current_color], 14   ; Light gray
    mov ax, 100
    mov bx, 60
    mov cx, 120
    mov dx, 80
    call video_fill_rect
    
    ; Window border
    mov byte [current_color], 1    ; White
    mov ax, 100
    mov bx, 60
    mov cx, 120
    mov dx, 80
    call video_draw_rect
    
    ; Window title bar
    mov byte [current_color], 8    ; Orange
    mov ax, 102
    mov bx, 62
    mov cx, 116
    mov dx, 16
    call video_fill_rect
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; Include icon system
; ---------------------------------------------------------------------------
%include "icons.asm"

; ============================================================
; video_set_color: Set current drawing color
; Input: AL = color index (0-15)
; ============================================================
video_set_color:
    mov [current_color], al
    ret

; ============================================================
; video_get_mouse_pos: Get mouse position
; Output: AX = X, BX = Y
; ============================================================
video_get_mouse_pos:
    mov ax, [mouse_x]
    mov bx, [mouse_y]
    ret

; ============================================================
; video_set_mouse_pos: Set mouse position
; Input: AX = X, BX = Y
; ============================================================
video_set_mouse_pos:
    mov [mouse_x], ax
    mov [mouse_y], bx
    ret

; ============================================================
; video_draw_mouse: Draw mouse cursor
; ============================================================
video_draw_mouse:
    push ax
    push bx
    push cx
    
    cmp byte [mouse_visible], 0
    je .done
    
    mov ax, [mouse_x]
    mov bx, [mouse_y]
    
    ; Draw simple crosshair cursor
    mov byte [current_color], 1    ; White
    
    ; Horizontal line
    mov cx, ax
    sub cx, 5
    mov dx, ax
    add dx, 5
    call video_draw_line
    
    ; Vertical line
    mov cx, ax
    mov dx, bx
    sub dx, 5
    call video_draw_line
    mov dx, bx
    add dx, 5
    call video_draw_line
    
.done:
    pop cx
    pop bx
    pop ax
    ret
