; =============================================================================
; install.asm - KSDOS Disk Installation Routine
; Copies KSDOS from USB boot drive to internal hard disk
; 16-bit real mode BIOS disk operations
; =============================================================================

; ---- Constants ----
INSTALL_BUFFER   equ 0x8000      ; Temporary buffer in RAM (32KB area)
INSTALL_SUCCESS  equ 0x00
INSTALL_ERROR    equ 0x01

; ---- Strings ----
install_s_reading:   db "Reading from USB drive...", 0x0A, 0x0D, 0
install_s_writing:   db "Writing to internal HD...", 0x0A, 0x0D, 0
install_s_success:   db "Installation completed successfully!", 0x0A, 0x0D, 0
install_s_error:     db "Installation failed!", 0x0A, 0x0D, 0
install_s_retry:     db "Retrying...", 0x0A, 0x0D, 0

; ============================================================
; install_to_hd: Main installation routine
; Copies boot sector from USB (boot drive in DL) to internal HD (80h)
; Returns: CF=0 on success, CF=1 on error
; ============================================================
install_to_hd:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Display reading message
    mov si, install_s_reading
    call vid_print

    ; 1. LER DO PENDRIVE (BIOS coloca o ID do boot em DL)
    mov ah, 02h        ; Função LER setores
    mov al, 1          ; Ler 1 setor (512 bytes)
    mov ch, 0          ; Cilindro 0
    mov cl, 1          ; Setor 1 (o próprio MBR do pendrive)
    mov dh, 0          ; Cabeça 0
    ; DL já está com o ID do pendrive
    mov bx, INSTALL_BUFFER ; Endereço temporário na memória RAM
    int 13h            ; Chama a BIOS
    
    jc .read_error     ; Se o Carry Flag estiver ativo, deu erro
    
    ; Display writing message
    mov si, install_s_writing
    call vid_print

    ; 2. GRAVAR NO HD INTERNO (ID 80h)
    mov ah, 03h        ; Função GRAVAR setores
    mov al, 1          ; Gravar 1 setor
    mov ch, 0          ; Cilindro 0
    mov cl, 1          ; Setor 1 (MBR do HD)
    mov dh, 0          ; Cabeça 0
    mov dl, 80h        ; <--- FORÇA O HD INTERNO
    mov bx, INSTALL_BUFFER ; Pega os dados que lemos do pendrive
    int 13h            ; Chama a BIOS

    jc .write_error    ; Se o Carry Flag estiver ativo, deu erro
    
    ; Success message
    mov si, install_s_success
    call vid_print
    clc                ; Clear carry flag (success)
    jmp .done

.read_error:
    mov si, install_s_error
    call vid_print
    stc                ; Set carry flag (error)
    jmp .done

.write_error:
    mov si, install_s_error
    call vid_print
    stc                ; Set carry flag (error)
    jmp .done

.done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; install_with_retry: Installation with retry mechanism
; Attempts installation up to 3 times before giving up
; Returns: CF=0 on success, CF=1 on error
; ============================================================
install_with_retry:
    push cx
    push si
    
    mov cx, 3          ; Maximum 3 attempts

.retry_loop:
    call install_to_hd
    jnc .success       ; If successful, exit
    
    dec cx
    jz .failed         ; If no more attempts, fail
    
    ; Display retry message
    mov si, install_s_retry
    call vid_print
    
    ; Small delay before retry
    call delay_short
    jmp .retry_loop

.success:
    clc                ; Clear carry flag (success)
    jmp .done

.failed:
    stc                ; Set carry flag (failed)

.done:
    pop si
    pop cx
    ret

; ============================================================
; delay_short: Small delay for retry operations
; Simple busy-wait delay
; ============================================================
delay_short:
    push cx
    push dx
    
    mov cx, 0xFFFF
    mov dx, 0xFFFF
    
.delay_loop:
    dec dx
    jnz .delay_loop
    dec cx
    jnz .delay_loop
    
    pop dx
    pop cx
    ret

; ============================================================
; install_verify: Verify installation by reading back and comparing
; Returns: CF=0 on verification success, CF=1 on failure
; ============================================================
install_verify:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    ; Read back from internal HD
    mov ax, 0
    mov es, ax
    mov ah, 02h        ; Read sectors
    mov al, 1          ; Read 1 sector
    mov ch, 0          ; Cylinder 0
    mov cl, 1          ; Sector 1
    mov dh, 0          ; Head 0
    mov dl, 80h        ; Internal HD
    mov bx, INSTALL_BUFFER + 512 ; Use second half of buffer
    int 13h
    jc .verify_failed
    
    ; Compare original with read-back
    mov si, INSTALL_BUFFER       ; Original from USB
    mov di, INSTALL_BUFFER + 512 ; Read-back from HD
    mov cx, 256                  ; Compare 512 bytes (256 words)
    rep cmpsw
    jne .verify_failed
    
    ; Verification successful
    clc
    jmp .done

.verify_failed:
    stc

.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
