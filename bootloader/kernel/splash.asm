; =============================================================================
; splash.asm - KSDOS Splash Screen
; ASCII art display for KSDOS system startup
; =============================================================================

; ---- Splash screen ASCII art ----
splash_art:
    db 0x1B, "[H", 0x1B, "[2J"  ; Clear screen and home cursor
    db 0x0A, 0x0A
    db " _   __ ___________ _____ _____ ", 0x0A
    db "| | / //  ___|  _  \  _  /  ___|", 0x0A
    db "| |/ / \ `--.| | | | | | \ `--. ", 0x0A
    db "|    \  `--. \ | | | | | |`--. \", 0x0A
    db "| |\  \/\__/ / |/ /\ \_/ /\__/ /", 0x0A
    db "\_| \_/\____/|___/  \___/\____/ ", 0x0A
    db "                                ", 0x0A
    db 0x0A
    db "Kernel Soft Disk Operating System", 0x0A
    db 0x0A
    db "                    Loading System...", 0x0A, 0x0A, 0

; ---- Loading messages ----
splash_loading: db ". Loading kernel modules...", 0x0D, 0
splash_drivers: db ". Initializing device drivers...", 0x0D, 0
splash_filesys: db ". Mounting file systems...", 0x0D, 0
splash_services: db ". Starting system services...", 0x0D, 0
splash_complete_msg: db ". System ready!", 0x0A, 0x0A, 0

; ---- Progress bar ----
splash_progress_bar: db "[", 0
splash_progress_fill: db "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||", 0
splash_progress_empty: db "                                                                                                        ", 0
splash_progress_end: db "]", 0

; ============================================================
; splash_show: Display the splash screen with loading animation
; ============================================================
splash_show:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Display the main splash art
    mov si, splash_art
    call vid_print
    
    ; Initialize progress counter
    mov byte [splash_progress_count], 0
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; splash_update_progress: Update progress during system loading
; Input: SI = loading message
; ============================================================
splash_update_progress:
    push ax
    push bx
    push cx
    push dx
    push si
    
    ; Print the loading message
    call vid_print
    
    ; Update progress counter
    mov al, [splash_progress_count]
    add al, 20  ; Each step adds 20% (5 steps total)
    mov [splash_progress_count], al
    
    ; Print progress bar
    mov si, splash_progress_bar
    call vid_print
    
    ; Calculate filled portion (percentage)
    mov cl, al
    mov ch, 0
    mov bl, 100
    div bl          ; AL = percentage, AH = remainder
    
    ; Print filled portion based on percentage
    mov cl, al       ; Use percentage as count
    mov si, splash_progress_fill
.print_fill:
    test cl, cl
    jz .print_empty
    lodsb
    call vid_putchar
    dec cl
    jmp .print_fill

.print_empty:
    ; Calculate remaining spaces
    mov cl, 100
    sub cl, al
.print_empty_loop:
    test cl, cl
    jz .done
    mov al, ' '
    call vid_putchar
    dec cl
    jmp .print_empty_loop

.done:
    mov si, splash_progress_end
    call vid_print
    call vid_nl
    
    ; Small delay for visual effect
    call splash_delay
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; splash_complete: Mark loading as complete
; ============================================================
splash_complete:
    push ax
    push si
    
    mov si, splash_complete_msg
    call vid_print
    
    ; Final delay before proceeding
    call splash_delay_long
    
    pop si
    pop ax
    ret

; ============================================================
; splash_print_progress: Print loading message with progress bar
; Input: SI = message string
; ============================================================
splash_print_progress:
    push ax
    push bx
    push cx
    push dx
    push si
    
    ; Print the loading message
    call vid_print
    
    ; Calculate progress position (simple increment)
    mov al, [splash_progress_count]
    inc al
    mov [splash_progress_count], al
    
    ; Print progress bar
    mov si, splash_progress_bar
    call vid_print
    
    ; Print filled portion
    mov cl, al
    mov ch, 0
    mov si, splash_progress_fill
.print_fill:
    test cl, cl
    jz .print_empty
    lodsb
    call vid_putchar
    dec cl
    jmp .print_fill

.print_empty:
    ; Calculate remaining spaces
    mov cl, 100
    sub cl, [splash_progress_count]
.print_empty_loop:
    test cl, cl
    jz .done
    mov al, ' '
    call vid_putchar
    dec cl
    jmp .print_empty_loop

.done:
    mov si, splash_progress_end
    call vid_print
    call vid_nl
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; splash_delay: Short delay for animation effect
; ============================================================
splash_delay:
    push cx
    push dx
    mov cx, 0x5000
.delay1:
    mov dx, 0x5000
.delay2:
    dec dx
    jnz .delay2
    dec cx
    jnz .delay1
    pop dx
    pop cx
    ret

; ============================================================
; splash_delay_long: Longer delay for dramatic effect
; ============================================================
splash_delay_long:
    push cx
    push dx
    mov cx, 0xA000
.delay1:
    mov dx, 0xA000
.delay2:
    dec dx
    jnz .delay2
    dec cx
    jnz .delay1
    pop dx
    pop cx
    ret

; ---- Progress counter ----
splash_progress_count: db 0
