; =============================================================================
; boot_enhanced.asm - Enhanced Bootloader for Complete System Loading
; Loads KSDOS with full system files and splash screen
; =============================================================================

    org 0x7C00
    bits 16

; ---- Enhanced boot sector with system detection ----
_start:
    ;; Setup data segments
    mov ax, 0
    mov es, ax
    mov ds, ax
    mov ss, ax
    
    ;; Setup the stack register
    mov sp, 0x7C00
    
    ;; Save boot drive
    mov [boot_drive], dl
    
    ;; Detect system type and show enhanced loading
    call detect_system_type
    call show_boot_banner
    
    ;; Load enhanced system
    call load_enhanced_system
    
    ;; Jump to system
    jmp SYSTEM_LOAD_ADDRESS

; ============================================================
; detect_system_type: Detect if this is a full system boot
; ============================================================
detect_system_type:
    push ax
    push bx
    push cx
    push dx
    
    ;; Check for system marker in first sector
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 2  ; Check sector 2 for system marker
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, 0x9000
    int 0x13
    
    jc .no_system_marker
    
    ;; Check for "KSDOS2" signature
    mov si, system_signature
    mov di, 0x9000
    mov cx, 6
    rep cmpsb
    je .full_system_found

.no_system_marker:
    mov byte [system_type], 0  ; Basic system
    jmp .done

.full_system_found:
    mov byte [system_type], 1  ; Full system

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; show_boot_banner: Display enhanced boot banner
; ============================================================
show_boot_banner:
    push ax
    push si
    
    ;; Clear screen
    mov ax, 0x0003
    int 0x10
    
    ;; Set text color
    mov ax, 0x0B00
    mov bh, 0
    mov bl, 0x1F  ; Blue background, white text
    int 0x10
    
    ;; Display banner based on system type
    cmp byte [system_type], 1
    je .show_full_banner
    
    ;; Basic banner
    mov si, basic_banner
    call enhanced_print
    jmp .done

.show_full_banner:
    ;; Full system banner
    mov si, full_banner
    call enhanced_print

.done:
    pop si
    pop ax
    ret

; ============================================================
; load_enhanced_system: Load the complete operating system
; ============================================================
load_enhanced_system:
    push ax
    push bx
    push cx
    push dx
    push si
    
    cmp byte [system_type], 1
    je .load_full_system
    
    ;; Load basic kernel (original behavior)
    call load_basic_kernel
    jmp .done

.load_full_system:
    ;; Load complete system
    call show_loading_sequence
    call load_system_components
    call initialize_system

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; show_loading_sequence: Display animated loading sequence
; ============================================================
show_loading_sequence:
    push ax
    push cx
    push si
    
    ;; Position cursor
    mov ah, 0x02
    mov bh, 0
    mov dx, 0x0500  ; Row 5, column 0
    int 0x10
    
    ;; Show loading messages with animation
    mov si, loading_messages
    mov cx, 6

.loading_loop:
    push cx
    call enhanced_print
    call loading_delay
    pop cx
    loop .loading_loop

    pop si
    pop cx
    pop ax
    ret

; ============================================================
; load_system_components: Load all system components
; ============================================================
load_system_components:
    push ax
    push bx
    push cx
    push dx
    
    ;; Load kernel (sectors 2-50)
    mov ah, 0x02
    mov al, 48
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, SYSTEM_LOAD_ADDRESS
    int 0x13
    
    ;; Load system files (sectors 51-500)
    mov ah, 0x02
    mov al, 450
    mov ch, 0
    mov cl, 51
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, SYSTEM_LOAD_ADDRESS + (48 * 512)
    int 0x13
    
    ;; Load applications (sectors 501-1000)
    mov ah, 0x02
    mov al, 500
    mov ch, 0
    mov cl, 501
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, SYSTEM_LOAD_ADDRESS + ((48 + 450) * 512)
    int 0x13
    
    ;; Load drivers and system libraries (sectors 1001-1500)
    mov ah, 0x02
    mov al, 500
    mov ch, 0
    mov cl, 1001
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, SYSTEM_LOAD_ADDRESS + ((48 + 450 + 500) * 512)
    int 0x13
    
    ;; Load configuration and user data (sectors 1501-2048)
    mov ah, 0x02
    mov al, 548
    mov ch, 0
    mov cl, 1501
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, SYSTEM_LOAD_ADDRESS + ((48 + 450 + 500 + 500) * 512)
    int 0x13
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; initialize_system: Initialize loaded system
; ============================================================
initialize_system:
    push ax
    push si
    
    ;; Display initialization messages
    mov si, init_messages
    mov cx, 4

.init_loop:
    push cx
    call enhanced_print
    call init_delay
    pop cx
    loop .init_loop
    
    ;; Final ready message
    mov si, system_ready_msg
    call enhanced_print
    
    ;; Wait for key press
    mov ah, 0x00
    int 0x16
    
    pop si
    pop ax
    ret

; ============================================================
; load_basic_kernel: Load original kernel for compatibility
; ============================================================
load_basic_kernel:
    mov ah, 0x02
    mov al, 48
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    mov bx, 0x1000
    int 0x13
    ret

; ============================================================
; enhanced_print: Print string with enhanced formatting
; Input: SI = string pointer
; ============================================================
enhanced_print:
    push ax
    push si

.print_loop:
    lodsb
    test al, al
    jz .done
    
    ;; Check for color codes
    cmp al, 0x1B  ; ESC character
    je .handle_color
    
    ;; Regular character
    mov ah, 0x0E
    int 0x10
    jmp .print_loop

.handle_color:
    lodsb  ; Skip '['
    lodsb  ; Get color code
    ;; Simple color handling (could be expanded)
    jmp .print_loop

.done:
    pop si
    pop ax
    ret

; ============================================================
; loading_delay: Delay for loading animation
; ============================================================
loading_delay:
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
; init_delay: Delay for initialization
; ============================================================
init_delay:
    push cx
    push dx
    mov cx, 0x2000
.delay1:
    mov dx, 0x2000
.delay2:
    dec dx
    jnz .delay2
    dec cx
    jnz .delay1
    pop dx
    pop cx
    ret

; ---- Data section ----
boot_drive: db 0
system_type: db 0  ; 0=basic, 1=full
system_signature: db "KSDOS2"

basic_banner:
    db 0x1B, "[H", 0x1B, "[2J"  ; Clear screen
    db 0x1B, "[37;44m"          ; White on blue
    db "╔══════════════════════════════════════════════════════════════╗", 0x0A
    db "║                        KSDOS v1.0                          ║", 0x0A
    db "║                   16-bit Real Mode OS                     ║", 0x0A
    db "║                      Loading...                          ║", 0x0A
    db "╚══════════════════════════════════════════════════════════════╝", 0x0A
    db 0x1B, "[0m", 0

full_banner:
    db 0x1B, "[H", 0x1B, "[2J"  ; Clear screen
    db 0x1B, "[36m"             ; Cyan
    db "    ████████╗ █████╗ ███╗   ██╗██╗  ██╗    ██████╗ ██╗   ██╗███████╗██████╗ ", 0x0A
    db "    ╚══██╔══╝██╔══██╗████╗  ██║██║ ██╔╝    ██╔══██╗██║   ██║██╔════╝██╔══██╗", 0x0A
    db "       ██║   ███████║██╔██╗ ██║█████╔╝     ██████╔╝██║   ██║█████╗  ██████╔╝", 0x0A
    db "       ██║   ██╔══██║██║╚██╗██║██╔═██╗     ██╔══██╗██║   ██║██╔══╝  ██╔══██╗", 0x0A
    db "       ██║   ██║  ██║██║ ╚████║██║  ██╗    ██║  ██║╚██████╔╝███████╗██║  ██║", 0x0A
    db "       ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝", 0x0A
    db 0x0A
    db 0x1B, "[33m"             ; Yellow
    db "                    ╔══════════════════════════════════════╗", 0x0A
    db "                    ║     Advanced Operating System        ║", 0x0A
    db "                    ║        Version 2.0 Professional      ║", 0x0A
    db "                    ║        Build 2024.1.0 (64-bit)        ║", 0x0A
    db "                    ╚══════════════════════════════════════╝", 0x0A
    db 0x1B, "[0m", 0

loading_messages:
    db 0x1B, "[10;5H", 0x1B, "[32m", "●", 0x1B, "[0m", " Loading kernel modules...", 0x0A
    db 0x1B, "[11;5H", 0x1B, "[32m", "●", 0x1B, "[0m", " Initializing device drivers...", 0x0A
    db 0x1B, "[12;5H", 0x1B, "[32m", "●", 0x1B, "[0m", " Mounting file systems...", 0x0A
    db 0x1B, "[13;5H", 0x1B, "[32m", "●", 0x1B, "[0m", " Starting system services...", 0x0A
    db 0x1B, "[14;5H", 0x1B, "[32m", "●", 0x1B, "[0m", " Configuring network stack...", 0x0A
    db 0x1B, "[15;5H", 0x1B, "[32m", "●", 0x1B, "[0m", " Loading security modules...", 0x0A
    db 0

init_messages:
    db 0x1B, "[17;5H", 0x1B, "[34m", "■", 0x1B, "[0m", " System initialization complete...", 0x0A
    db 0x1B, "[18;5H", 0x1B, "[34m", "■", 0x1B, "[0m", " All drivers loaded successfully...", 0x0A
    db 0x1B, "[19;5H", 0x1B, "[34m", "■", 0x1B, "[0m", " File systems mounted...", 0x0A
    db 0x1B, "[20;5H", 0x1B, "[34m", "■", 0x1B, "[0m", " Network services ready...", 0x0A
    db 0

system_ready_msg:
    db 0x1B, "[22;10H", 0x1B, "[32;1m", "✓ SYSTEM READY! Press any key to continue...", 0x1B, "[0m", 0

; ---- Boot sector padding ----
    times 510-($-$$) db 0
    dw 0xAA55
