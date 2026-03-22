; =============================================================================
; splash.asm - KSDOS Splash Screen with Real Progress
; Works directly with boot.asm and bootsect.asm loading progress
; =============================================================================

; ---- Splash screen ASCII art ----
splash_art:
    db 0x1B, "[H", 0x1B, "[2J"  ; Clear screen and home cursor
    db 0x0A, 0x0A
    db " _   __ ___________ _____ _____ ", 0x0A
    db "| | / //  ___|  _  \  _  /  ___|", 0x0A
    db "| |/ / \ `--.| | | | | | \ `--. ", 0x0A
    db "|    \  `--. \ | | | | | |`--. \ ", 0x0A
    db "| |\  \/\__/ / |/ /\ \_/ /\__/ /", 0x0A
    db "\_| \_/\____/|___/  \___/\____/ ", 0x0A
    db 0x0A
    db "                                ", 0x0A
    db "Kernel Soft Disk Operating System", 0x0A
    db 0x0A, 0x0A
    db "                    Loading System...", 0x0A, 0x0A, 0

; ---- Progress bar ----
splash_progress_bar: db "[", 0
splash_progress_fill: db "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||", 0
splash_progress_empty: db "                                                                                                        ", 0
splash_progress_end: db "]", 0x0A, 0

; ---- Progress tracking ----
boot_progress     db 0          ; 0-100 percentage
total_steps       equ 5         ; Total loading steps

; ---- Loading messages ----
msg_boot_init     db "Initializing bootloader...", 0x0D, 0
msg_fat_load      db "Loading FAT tables...", 0x0D, 0
msg_root_load     db "Loading root directory...", 0x0D, 0
msg_kernel_find   db "Finding KSDOS.SYS...", 0x0D, 0
msg_kernel_load   db "Loading KSDOS kernel...", 0x0D, 0
msg_complete      db "System ready!", 0x0A, 0x0A, 0

; ============================================================
; prints: Print string function (from boot sector)
; Input: SI = pointer to string
; ============================================================
prints:
    push ax
    push si
    
.print_loop:
    lodsb
    cmp al, 0
    je .done
    
    mov ah, 0x0E
    int 0x10
    jmp .print_loop
    
.done:
    pop si
    pop ax
    ret

; ============================================================
; putc: Print character function (from boot sector)
; Input: AL = character
; ============================================================
putc:
    push ax
    
    mov ah, 0x0E
    int 0x10
    
    pop ax
    ret

; ============================================================
; splash_init: Initialize splash screen
; ============================================================
splash_init:
    push ax
    push si
    
    ; Display the splash art
    mov si, splash_art
    call prints
    
    ; Initialize progress
    mov byte [boot_progress], 0
    
    pop si
    pop ax
    ret

; ============================================================
; splash_update: Update progress based on boot stage
; Input: AL = stage number (0-4)
; ============================================================
splash_update:
    push ax
    push bx
    push cx
    push dx
    push si
    
    ; Calculate progress percentage
    mov bl, total_steps
    mul bl                  ; AX = stage * 5
    mov byte [boot_progress], al
    
    ; Display appropriate message
    cmp al, 0
    je .stage0
    cmp al, 20
    je .stage1
    cmp al, 40
    je .stage2
    cmp al, 60
    je .stage3
    cmp al, 80
    je .stage4
    jmp .done
    
.stage0:
    mov si, msg_boot_init
    call splash_print_progress
    jmp .done
    
.stage1:
    mov si, msg_fat_load
    call splash_print_progress
    jmp .done
    
.stage2:
    mov si, msg_root_load
    call splash_print_progress
    jmp .done
    
.stage3:
    mov si, msg_kernel_find
    call splash_print_progress
    jmp .done
    
.stage4:
    mov si, msg_kernel_load
    call splash_print_progress
    jmp .done
    
.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; splash_print_progress: Print progress bar with message
; Input: SI = message
; ============================================================
splash_print_progress:
    push ax
    push bx
    push cx
    push si
    
    ; Print message
    call prints
    
    ; Print progress bar
    mov si, splash_progress_bar
    call prints
    
    ; Get current progress
    mov al, [boot_progress]
    
    ; Calculate filled portion (percentage of 100 chars)
    mov bl, 100
    mul bl                  ; AX = progress * 100
    mov bl, total_steps * 100
    div bl                  ; AL = percentage (0-100)
    
    ; Print filled portion
    mov cl, al
    mov si, splash_progress_fill
.print_fill:
    test cl, cl
    jz .print_empty
    lodsb
    call putc
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
    call putc
    dec cl
    jmp .print_empty_loop

.done:
    mov si, splash_progress_end
    call prints
    
    pop si
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
    
    ; Set progress to 100%
    mov byte [boot_progress], 100
    
    ; Print completion message
    mov si, msg_complete
    call prints
    
    pop si
    pop ax
    ret
