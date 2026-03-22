; =============================================================================
; mouse_gui.asm - KSDOS GUI Mouse Driver
; PS/2 mouse support for Amiga-style interface
; =============================================================================

; ---- Mouse constants ----
MOUSE_PORT_DATA     equ 0x60
MOUSE_PORT_STATUS   equ 0x64
MOUSE_PORT_COMMAND  equ 0x64
MOUSE_CMD_ENABLE   equ 0xA8
MOUSE_CMD_WRITE    equ 0xD4
MOUSE_CMD_SAMPLE   equ 0xF4
MOUSE_ACK          equ 0xFA

; ---- Mouse state ----
mouse_x           dw 160        ; Current X position
mouse_y           dw 100        ; Current Y position
mouse_buttons      db 0          ; Current button state
mouse_last_x       dw 160        ; Last X position
mouse_last_y       dw 100        ; Last Y position
mouse_last_buttons db 0          ; Last button state
mouse_enabled     db 0          ; Mouse enabled flag
mouse_sensitivity  db 3          ; Mouse sensitivity

; ---- Mouse packet structure ----
mouse_packet       db 3 dup(0)   ; 3-byte PS/2 packet
mouse_packet_index db 0          ; Current packet byte index

; ============================================================
; mouse_init: Initialize PS/2 mouse
; ============================================================
mouse_init:
    push ax
    push cx
    push dx
    
    ; Wait for input buffer empty
    call mouse_wait_input
    
    ; Send enable command to mouse
    mov al, MOUSE_CMD_ENABLE
    out MOUSE_PORT_COMMAND, al
    
    ; Wait for acknowledge
    call mouse_wait_output
    in al, MOUSE_PORT_DATA
    cmp al, MOUSE_ACK
    jne .error
    
    ; Enable mouse data reporting
    call mouse_wait_input
    mov al, MOUSE_CMD_SAMPLE
    out MOUSE_PORT_COMMAND, al
    
    ; Wait for acknowledge
    call mouse_wait_output
    in al, MOUSE_PORT_DATA
    cmp al, MOUSE_ACK
    jne .error
    
    ; Mouse initialized successfully
    mov byte [mouse_enabled], 1
    mov byte [mouse_packet_index], 0
    
    xor ax, ax
    jmp .done
    
.error:
    ; Mouse initialization failed
    mov byte [mouse_enabled], 0
    mov ax, -1
    
.done:
    pop dx
    pop cx
    pop ax
    ret

; ============================================================
; mouse_wait_input: Wait for input buffer to be empty
; ============================================================
mouse_wait_input:
    push ax
.wait:
    in al, MOUSE_PORT_STATUS
    test al, 0x02          ; Input buffer flag
    jnz .wait
    pop ax
    ret

; ============================================================
; mouse_wait_output: Wait for output buffer to be full
; ============================================================
mouse_wait_output:
    push ax
.wait:
    in al, MOUSE_PORT_STATUS
    test al, 0x01          ; Output buffer flag
    jz .wait
    pop ax
    ret

; ============================================================
; mouse_read: Read mouse data packet
; Output: AX = X movement, BX = Y movement, CX = buttons
; ============================================================
mouse_read:
    push ax
    push bx
    push cx
    push dx
    push si
    
    ; Check if mouse data is available
    in al, MOUSE_PORT_STATUS
    test al, 0x01
    jz .no_data
    
    ; Read byte from mouse
    in al, MOUSE_PORT_DATA
    
    ; Store in packet buffer
    mov si, [mouse_packet_index]
    mov [mouse_packet + si], al
    inc si
    cmp si, 3
    jne .store_packet
    
    ; Complete packet received
    mov byte [mouse_packet_index], 0
    call mouse_process_packet
    jmp .done
    
.store_packet:
    mov [mouse_packet_index], si
    
.done:
    ; Calculate movement since last read
    mov ax, [mouse_x]
    sub ax, [mouse_last_x]
    mov bx, [mouse_y]
    sub bx, [mouse_last_y]
    mov cx, [mouse_buttons]
    
    ; Update last positions
    mov ax, [mouse_x]
    mov [mouse_last_x], ax
    mov ax, [mouse_y]
    mov [mouse_last_y], ax
    mov al, [mouse_buttons]
    mov [mouse_last_buttons], al
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
.no_data:
    ; No mouse data available
    xor ax, ax
    xor bx, bx
    xor cx, cx
    jmp .done

; ============================================================
; mouse_process_packet: Process complete 3-byte mouse packet
; ============================================================
mouse_process_packet:
    push ax
    push bx
    push cx
    
    ; Get packet bytes
    mov al, [mouse_packet]      ; First byte
    mov bl, [mouse_packet + 1]  ; Second byte (X movement)
    mov cl, [mouse_packet + 2]  ; Third byte (Y movement)
    
    ; Extract button states
    mov ah, al
    and ah, 0x07              ; Mask button bits
    mov [mouse_buttons], ah
    
    ; Check X sign bit
    test al, 0x10
    jz .x_positive
    mov bh, 0xFF              ; Negative X
    jmp .x_done
    
.x_positive:
    xor bh, bh                  ; Positive X
    
.x_done:
    and bl, bh                  ; Apply sign to X movement
    
    ; Check Y sign bit
    test al, 0x20
    jz .y_positive
    mov bh, 0xFF              ; Negative Y
    jmp .y_done
    
.y_positive:
    xor bh, bh                  ; Positive Y
    
.y_done:
    and cl, bh                  ; Apply sign to Y movement
    
    ; Update mouse position with sensitivity
    mov al, [mouse_sensitivity]
    cbw
    imul bx                  ; AX = X movement * sensitivity
    add [mouse_x], ax
    
    mov al, [mouse_sensitivity]
    cbw
    imul cx                  ; AX = Y movement * sensitivity
    add [mouse_y], ax
    
    ; Clamp to screen bounds
    call mouse_clamp_position
    
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; mouse_clamp_position: Clamp mouse position to screen bounds
; ============================================================
mouse_clamp_position:
    push ax
    
    ; Clamp X
    mov ax, [mouse_x]
    cmp ax, 0
    jge .x_ok_min
    mov ax, 0
    jmp .x_clamped
    
.x_ok_min:
    cmp ax, SCREEN_WIDTH - 1
    jle .x_clamped
    mov ax, SCREEN_WIDTH - 1
    
.x_clamped:
    mov [mouse_x], ax
    
    ; Clamp Y
    mov ax, [mouse_y]
    cmp ax, 0
    jge .y_ok_min
    mov ax, 0
    jmp .y_clamped
    
.y_ok_min:
    cmp ax, SCREEN_HEIGHT - 1
    jle .y_clamped
    mov ax, SCREEN_HEIGHT - 1
    
.y_clamped:
    mov [mouse_y], ax
    
    pop ax
    ret

; ============================================================
; mouse_get_position: Get current mouse position
; Output: AX = X, BX = Y
; ============================================================
mouse_get_position:
    mov ax, [mouse_x]
    mov bx, [mouse_y]
    ret

; ============================================================
; mouse_set_position: Set mouse position
; Input: AX = X, BX = Y
; ============================================================
mouse_set_position:
    mov [mouse_x], ax
    mov [mouse_y], bx
    call mouse_clamp_position
    ret

; ============================================================
; mouse_get_buttons: Get current button state
; Output: AL = button state
; ============================================================
mouse_get_buttons:
    mov al, [mouse_buttons]
    ret

; ============================================================
; mouse_set_sensitivity: Set mouse sensitivity
; Input: AL = sensitivity (1-10)
; ============================================================
mouse_set_sensitivity:
    cmp al, 1
    jl .min_sens
    cmp al, 10
    jg .max_sens
    mov [mouse_sensitivity], al
    ret
    
.min_sens:
    mov al, 1
    mov [mouse_sensitivity], al
    ret
    
.max_sens:
    mov al, 10
    mov [mouse_sensitivity], al
    ret

; ============================================================
; mouse_is_enabled: Check if mouse is enabled
; Output: AL = 1 if enabled, 0 if not
; ============================================================
mouse_is_enabled:
    mov al, [mouse_enabled]
    ret

; ============================================================
; mouse_disable: Disable mouse
; ============================================================
mouse_disable:
    push ax
    
    ; Send disable command
    call mouse_wait_input
    mov al, MOUSE_CMD_WRITE
    out MOUSE_PORT_COMMAND, al
    call mouse_wait_input
    mov al, 0xF5          ; Disable data reporting
    out MOUSE_PORT_DATA, al
    
    mov byte [mouse_enabled], 0
    
    pop ax
    ret

; ============================================================
; mouse_enable: Enable mouse
; ============================================================
mouse_enable:
    push ax
    
    ; Send enable command
    call mouse_wait_input
    mov al, MOUSE_CMD_WRITE
    out MOUSE_PORT_COMMAND, al
    call mouse_wait_input
    mov al, MOUSE_CMD_SAMPLE
    out MOUSE_PORT_DATA, al
    
    mov byte [mouse_enabled], 1
    
    pop ax
    ret

; ============================================================
; mouse_interrupt_handler: Handle mouse interrupt (IRQ12)
; ============================================================
mouse_interrupt_handler:
    push ax
    push si
    
    ; Read mouse packet if available
    call mouse_read
    
    ; Handle GUI interaction
    call window_handle_mouse
    
    pop si
    pop ax
    ret
