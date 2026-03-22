; =============================================================================
; window_gui.asm - KSDOS Amiga-style Window Manager
; =============================================================================

; ---- Window structure ----
WINDOW_MAX       equ 8
WINDOW_SIZE      equ 32

; Window structure in memory:
; 0:  X position (word)
; 2:  Y position (word)  
; 4:  Width (word)
; 6:  Height (word)
; 8:  Flags (byte)
; 9:  Title color (byte)
; 10: Body color (byte)
; 11: Border color (byte)
; 12: Title pointer (word)
; 14: Data pointer (word)
; 16-31: Reserved

; ---- Window flags ----
WINDOW_ACTIVE    equ 0x01
WINDOW_VISIBLE   equ 0x02
WINDOW_DRAGGABLE equ 0x04
WINDOW_RESIZABLE equ 0x08
WINDOW_CLOSEABLE equ 0x10

; ---- Window memory area ----
windows:
    times WINDOW_MAX * WINDOW_SIZE db 0

active_window    dw -1
window_count     db 0
drag_window      dw -1
drag_offset_x    dw 0
drag_offset_y    dw 0

; ============================================================
; window_create: Create a new window
; Input: AX = X, BX = Y, CX = Width, DX = Height
;        SI = Title string pointer
; Output: AX = window handle (-1 if error)
; ============================================================
window_create:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    
    ; Find free window slot
    mov bp, WINDOW_MAX
    mov di, windows
.find_slot:
    cmp byte [di + 8], 0    ; Check flags
    je .found_slot
    add di, WINDOW_SIZE
    dec bp
    jnz .find_slot
    
    ; No free slots
    mov ax, -1
    jmp .done
    
.found_slot:
    ; Initialize window structure
    mov [di], ax          ; X
    mov [di + 2], bx     ; Y
    mov [di + 4], cx     ; Width
    mov [di + 6], dx     ; Height
    mov byte [di + 8], WINDOW_VISIBLE | WINDOW_DRAGGABLE | WINDOW_CLOSEABLE
    mov byte [di + 9], 8   ; Title color (orange)
    mov byte [di + 10], 14  ; Body color (light gray)
    mov byte [di + 11], 1  ; Border color (white)
    mov [di + 12], si     ; Title pointer
    mov word [di + 14], 0  ; Data pointer
    
    ; Calculate window handle
    mov ax, di
    sub ax, windows
    mov bx, WINDOW_SIZE
    xor dx, dx
    div bx              ; AX = slot index
    
    ; Increment window count
    inc byte [window_count]
    
    ; Make it active
    mov [active_window], ax
    
    ; Draw the window
    call window_draw
    
.done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; window_draw: Draw a window
; Input: AX = window handle
; ============================================================
window_draw:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    
    ; Get window pointer
    mov bp, WINDOW_SIZE
    mul bp
    mov di, windows
    add di, ax
    
    ; Check if visible
    test byte [di + 8], WINDOW_VISIBLE
    jz .done
    
    ; Get window properties
    mov bx, [di]          ; X
    mov cx, [di + 2]      ; Y
    mov dx, [di + 4]      ; Width
    mov si, [di + 6]      ; Height
    
    ; Draw window body
    push ax
    mov al, [di + 10]     ; Body color
    call video_set_color
    mov ax, bx
    mov bx, cx
    add bx, 16             ; Skip title bar
    sub si, 16             ; Reduce height for title bar
    call video_fill_rect
    pop ax
    
    ; Draw window border
    push ax
    mov al, [di + 11]     ; Border color
    call video_set_color
    mov ax, bx
    mov bx, cx
    call video_draw_rect
    pop ax
    
    ; Draw title bar
    push ax
    mov al, [di + 9]      ; Title color
    call video_set_color
    mov ax, bx
    mov bx, cx
    add ax, 2
    add bx, 2
    sub dx, 4
    call video_fill_rect
    pop ax
    
    ; Draw title text (simplified)
    push ax
    mov si, [di + 12]     ; Title pointer
    test si, si
    jz .no_title
    
    mov al, [di + 11]     ; Border color for text
    call video_set_color
    mov ax, bx
    add ax, 8
    add bx, 6
    call video_gfx_print
    
.no_title:
    pop ax
    
    ; Draw close gadget
    push ax
    mov al, 3              ; Red color
    call video_set_color
    mov ax, bx
    add ax, dx
    sub ax, 12
    add bx, 4
    mov cx, 8
    mov dx, 8
    call video_fill_rect
    pop ax
    
.done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; window_close: Close a window
; Input: AX = window handle
; ============================================================
window_close:
    push ax
    push bx
    push di
    push bp
    
    ; Get window pointer
    mov bp, WINDOW_SIZE
    mul bp
    mov di, windows
    add di, ax
    
    ; Clear window flags
    mov byte [di + 8], 0
    
    ; Decrement window count
    dec byte [window_count]
    
    ; If this was active, find new active window
    cmp ax, [active_window]
    jne .done
    call window_find_new_active
    
.done:
    ; Redraw desktop
    call video_draw_desktop
    call window_redraw_all
    
    pop bp
    pop di
    pop bx
    pop ax
    ret

; ============================================================
; window_find_new_active: Find new active window
; ============================================================
window_find_new_active:
    push ax
    push bx
    push di
    
    mov [active_window], -1
    mov bx, WINDOW_MAX
    mov di, windows
    
.find_loop:
    cmp byte [di + 8], 0
    je .next
    cmp byte [di + 8], WINDOW_VISIBLE
    jne .next
    
    ; Found visible window
    mov ax, di
    sub ax, windows
    mov bx, WINDOW_SIZE
    xor dx, dx
    div bx
    mov [active_window], ax
    jmp .done
    
.next:
    add di, WINDOW_SIZE
    dec bx
    jnz .find_loop
    
.done:
    pop di
    pop bx
    pop ax
    ret

; ============================================================
; window_redraw_all: Redraw all visible windows
; ============================================================
window_redraw_all:
    push ax
    push bx
    push cx
    push di
    
    mov cx, WINDOW_MAX
    mov di, windows
    xor bx, bx          ; Window index
    
.redraw_loop:
    cmp byte [di + 8], WINDOW_VISIBLE
    jz .next
    
    push bx
    call window_draw
    pop bx
    
.next:
    add di, WINDOW_SIZE
    inc bx
    loop .redraw_loop
    
    pop di
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; window_handle_mouse: Handle mouse input for windows
; Input: AX = Mouse X, BX = Mouse Y, CX = Mouse buttons
; ============================================================
window_handle_mouse:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    
    ; Check for close gadget click
    mov dx, cx
    test dl, 1              ; Left button
    jz .check_drag
    
    call window_check_close_gadget
    cmp ax, 0
    jne .done
    
.check_drag:
    ; Check for window drag
    test dl, 1
    jz .done
    
    call window_check_drag
    cmp ax, 0
    jne .done
    
.done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; window_check_close_gadget: Check if close gadget was clicked
; Input: AX = Mouse X, BX = Mouse Y
; Output: AX = 1 if clicked, 0 if not
; ============================================================
window_check_close_gadget:
    push ax
    push bx
    push cx
    push dx
    push di
    push bp
    
    mov dx, WINDOW_MAX
    mov di, windows
    
.check_loop:
    cmp byte [di + 8], WINDOW_VISIBLE
    jz .next_window
    cmp byte [di + 8], WINDOW_CLOSEABLE
    jz .next_window
    
    ; Get window properties
    mov cx, [di]          ; X
    mov bp, [di + 2]      ; Y
    mov si, [di + 4]      ; Width
    mov dx, [di + 6]      ; Height
    
    ; Check close gadget position (top-right corner)
    add cx, si
    sub cx, 12             ; Close gadget X
    add bp, 4              ; Close gadget Y
    
    ; Check if mouse is in close gadget area
    cmp ax, cx
    jl .next_window
    cmp ax, cx
    jg .close_gadget_end
    add cx, 8              ; Gadget width
    cmp ax, cx
    jg .next_window
    
.close_gadget_end:
    cmp bx, bp
    jl .next_window
    cmp bx, bp
    jg .next_window
    add bp, 8              ; Gadget height
    cmp bx, bp
    jg .next_window
    
    ; Close gadget clicked!
    push ax
    mov ax, di
    sub ax, windows
    mov bx, WINDOW_SIZE
    xor dx, dx
    div bx
    call window_close
    pop ax
    mov ax, 1
    jmp .done
    
.next_window:
    add di, WINDOW_SIZE
    dec dx
    jnz .check_loop
    
    mov ax, 0
    
.done:
    pop bp
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; window_check_drag: Check if window should be dragged
; Input: AX = Mouse X, BX = Mouse Y
; Output: AX = 1 if dragging, 0 if not
; ============================================================
window_check_drag:
    push ax
    push bx
    push cx
    push dx
    push di
    push bp
    
    ; Check if already dragging
    cmp [drag_window], -1
    jne .continue_drag
    
    ; Start new drag
    mov dx, WINDOW_MAX
    mov di, windows
    
.find_title_bar:
    cmp byte [di + 8], WINDOW_VISIBLE
    jz .next
    cmp byte [di + 8], WINDOW_DRAGGABLE
    jz .next
    
    ; Get window properties
    mov cx, [di]          ; X
    mov bp, [di + 2]      ; Y
    mov si, [di + 4]      ; Width
    
    ; Check if mouse is in title bar area
    cmp ax, cx
    jl .next
    add cx, si
    cmp ax, cx
    jg .next
    
    cmp bx, bp
    jl .next
    add bp, 16             ; Title bar height
    cmp bx, bp
    jg .next
    
    ; Start dragging this window
    push ax
    mov ax, di
    sub ax, windows
    mov bx, WINDOW_SIZE
    xor dx, dx
    div bx
    mov [drag_window], ax
    pop ax
    
    ; Calculate drag offset
    sub ax, [di]
    mov [drag_offset_x], ax
    mov ax, bx
    sub ax, [di + 2]
    mov [drag_offset_y], ax
    
    mov ax, 1
    jmp .done
    
.next:
    add di, WINDOW_SIZE
    dec dx
    jnz .find_title_bar
    
    mov ax, 0
    jmp .done
    
.continue_drag:
    ; Continue dragging existing window
    mov di, [drag_window]
    mov bp, WINDOW_SIZE
    mul bp
    add di, windows
    
    ; Update window position
    mov cx, ax
    sub cx, [drag_offset_x]
    mov [di], cx
    mov cx, bx
    sub cx, [drag_offset_y]
    mov [di + 2], cx
    
    ; Redraw
    call video_draw_desktop
    call window_redraw_all
    
    mov ax, 1
    
.done:
    pop bp
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; window_stop_drag: Stop dragging windows
; ============================================================
window_stop_drag:
    mov [drag_window], -1
    ret

; ============================================================
; video_gfx_print: Print text in graphics mode (simplified)
; Input: AX = X, BX = Y, SI = text pointer
; ============================================================
video_gfx_print:
    push ax
    push bx
    push cx
    push si
    
.print_loop:
    lodsb
    cmp al, 0
    je .done
    
    ; For now, just draw a simple character representation
    call video_draw_char_simple
    
    inc ax
    jmp .print_loop
    
.done:
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; video_draw_char_simple: Draw simple character
; Input: AX = X, BX = Y, AL = character
; ============================================================
video_draw_char_simple:
    push ax
    push bx
    push cx
    push dx
    
    ; For simplicity, draw a small rectangle for each character
    mov cx, 6
    mov dx, 8
    call video_fill_rect
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
