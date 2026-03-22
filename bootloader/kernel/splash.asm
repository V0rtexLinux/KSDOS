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
splash_memory:      db "Initializing system memory...", 0x0D, 0
splash_critical:    db "Loading critical system files...", 0x0D, 0
splash_system32:    db "Loading System32 components...", 0x0D, 0
splash_drivers:     db "Installing device drivers...", 0x0D, 0
splash_apps:        db "Loading applications...", 0x0D, 0
splash_config:      db "Loading configuration files...", 0x0D, 0
splash_services:    db "Starting system services...", 0x0D, 0
splash_filesys:     db "Mounting file systems...", 0x0D, 0
splash_complete_msg: db "System ready!", 0x0A, 0x0A, 0

; ---- Progress bar ----
splash_progress_bar: db "[", 0
splash_progress_fill: db "█", 0
splash_progress_empty: db " ", 0
splash_progress_end: db "] ", 0

; Progress bar configuration
PROGRESS_WIDTH      equ 50  ; Width of progress bar
PROGRESS_CHAR_FULL   equ '█' ; Filled character
PROGRESS_CHAR_EMPTY  equ ' '  ; Empty character

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
    
    ; Initialize progress counter (0%)
    mov byte [splash_progress_count], 0
    
    ; Show initial progress bar
    call splash_draw_progress_bar
    
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
    
    ; Move cursor up to overwrite previous message
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    
    ; Print the loading message
    call vid_print
    
    ; Update progress counter based on message type
    call splash_get_progress_percentage
    mov [splash_progress_count], al
    
    ; Draw the progress bar
    call splash_draw_progress_bar
    
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
    
    ; Set progress to 100%
    mov byte [splash_progress_count], 100
    
    ; Draw final progress bar
    call splash_draw_progress_bar
    
    ; Move to next line
    call vid_nl
    
    ; Display completion message
    mov si, splash_complete_msg
    call vid_print
    
    ; Final delay before proceeding
    call splash_delay_long
    
    pop si
    pop ax
    ret

; ============================================================
; splash_get_progress_percentage: Get progress based on message
; Input: SI = message string
; Output: AL = percentage (0-100)
; ============================================================
splash_get_progress_percentage:
    push si
    push di
    
    ; Check message type and return appropriate percentage
    
    ; Memory initialization - 10%
    mov di, splash_memory
    call strcmp_test
    jc .memory_percent
    
    ; Critical files - 25%
    mov di, splash_critical
    call strcmp_test
    jc .critical_percent
    
    ; System32 files - 40%
    mov di, splash_system32
    call strcmp_test
    jc .system32_percent
    
    ; Drivers - 55%
    mov di, splash_drivers
    call strcmp_test
    jc .drivers_percent
    
    ; Applications - 70%
    mov di, splash_apps
    call strcmp_test
    jc .apps_percent
    
    ; Configuration - 85%
    mov di, splash_config
    call strcmp_test
    jc .config_percent
    
    ; Services - 90%
    mov di, splash_services
    call strcmp_test
    jc .services_percent
    
    ; File systems - 95%
    mov di, splash_filesys
    call strcmp_test
    jc .filesystem_percent
    
    ; Default: 0%
    xor ax, ax
    jmp .done
    
.memory_percent:
    mov al, 10
    jmp .done
    
.critical_percent:
    mov al, 25
    jmp .done
    
.system32_percent:
    mov al, 40
    jmp .done
    
.drivers_percent:
    mov al, 55
    jmp .done
    
.apps_percent:
    mov al, 70
    jmp .done
    
.config_percent:
    mov al, 85
    jmp .done
    
.services_percent:
    mov al, 90
    jmp .done
    
.filesystem_percent:
    mov al, 95
    jmp .done
    
.done:
    pop di
    pop si
    ret

; ============================================================
; splash_draw_progress_bar: Draw the progress bar
; ============================================================
splash_draw_progress_bar:
    push ax
    push bx
    push cx
    push dx
    
    ; Print opening bracket
    mov al, '['
    call vid_putchar
    
    ; Get current percentage
    mov al, [splash_progress_count]
    
    ; Calculate filled characters
    mov ah, 0
    mov bl, PROGRESS_WIDTH
    mul bl          ; AX = percentage * width
    mov bl, 100
    div bl          ; AL = filled characters, AH = remainder
    
    ; Print filled portion
    mov cl, al       ; Number of filled characters
.filled_loop:
    test cl, cl
    jz .empty_loop
    mov al, PROGRESS_CHAR_FULL
    call vid_putchar
    dec cl
    jmp .filled_loop
    
.empty_loop:
    ; Calculate remaining empty characters
    mov cl, PROGRESS_WIDTH
    sub cl, [splash_progress_count]
    mov ah, 0
    mov bl, PROGRESS_WIDTH
    mul bl          ; AX = percentage * width
    mov bl, 100
    div bl          ; AL = filled characters
    mov cl, PROGRESS_WIDTH
    sub cl, al       ; CL = empty characters
    
.empty_print:
    test cl, cl
    jz .done
    mov al, PROGRESS_CHAR_EMPTY
    call vid_putchar
    dec cl
    jmp .empty_print
    
.done:
    ; Print closing bracket and percentage
    mov al, ']'
    call vid_putchar
    
    ; Print percentage
    mov al, ' '
    call vid_putchar
    
    mov al, [splash_progress_count]
    call splash_print_number
    
    mov al, '%'
    call vid_putchar
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; splash_print_number: Print a number (0-100)
; Input: AL = number
; ============================================================
splash_print_number:
    push ax
    push bx
    push cx
    push dx
    
    ; Convert number to ASCII
    mov ah, 0
    mov bl, 10
    div bl          ; AL = tens, AH = ones
    
    ; Print tens digit
    add al, '0'
    call vid_putchar
    
    ; Print ones digit
    mov al, ah
    add al, '0'
    call vid_putchar
    
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
    mov cx, 0x3000
.delay1:
    mov dx, 0x3000
.delay2:
    dec dx
    jnz .delay2
    dec cx
    jnz .delay1
    pop dx
    pop cx
    ret

; ============================================================
; strcmp_test: Compare two strings (from system_loader.asm)
; Input: SI = string1, DI = string2
; Output: JC = match, JNC = no match
; ============================================================
strcmp_test:
    push ax
    push si
    push di
    
.compare_loop:
    mov al, [si]
    cmp al, [di]
    jne .different
    
    cmp al, 0
    je .equal
    
    inc si
    inc di
    jmp .compare_loop
    
.different:
    clc                 ; Clear carry (no match)
    jmp .done
    
.equal:
    stc                 ; Set carry (match)
    
.done:
    pop di
    pop si
    pop ax
    ret

; ============================================================
; splash_delay_long: Longer delay for dramatic effect
; ============================================================
splash_delay_long:
    push cx
    push dx
    mov cx, 0x6000
.delay1:
    mov dx, 0x6000
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
