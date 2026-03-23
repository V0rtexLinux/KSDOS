; =============================================================================
; BOOTLOADR.ASM - KSDOS Bootloader Manager
; Carregado pelo boot.asm, gerencia todos os componentes do bootloader
; =============================================================================

BITS 16
ORG 0x0000

; ---------------------------------------------------------------------------
; 0x0000: Initial jump over data to bootloader_entry
; ---------------------------------------------------------------------------
    jmp near bootloader_entry

; ---------------------------------------------------------------------------
; 0x0003: Bootloader jump table - Overlay system entries
; ---------------------------------------------------------------------------
%macro BTENTRY 1
    db 0xE9
    dw (%1) - ($ + 2)
%endmacro

    BTENTRY bootloader_init      ; 0x0003
    BTENTRY overlay_load_run     ; 0x0006
    BTENTRY fat_find            ; 0x0009
    BTENTRY fat_read_file       ; 0x000C
    BTENTRY fat_load_dir        ; 0x000F
    BTENTRY fat_save_dir        ; 0x0012
    BTENTRY disk_read_sector    ; 0x0015
    BTENTRY disk_write_sector   ; 0x0018
    BTENTRY boot_kernel         ; 0x001B

; ---------------------------------------------------------------------------
; 0x0060: Shared data area
; ---------------------------------------------------------------------------
bl_arg:         times 128 db 0      ; 0x0060 - 0x00DF
bl_tmp11:       times  12 db 0      ; 0x00E0 - 0x00EB
bl_type_sz:     dw 0                ; 0x00EC - 0x00ED

; ---------------------------------------------------------------------------
; bootloader_entry: Main bootloader entry point
; ---------------------------------------------------------------------------
bootloader_entry:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    sti

    ; Initialize bootloader systems
    call bootloader_init
    
    ; Load and boot kernel
    call boot_kernel
    
    ; Should never reach here
    cli
.halt:
    hlt
    jmp .halt

; ---------------------------------------------------------------------------
; bootloader_init: Initialize all bootloader subsystems
; ---------------------------------------------------------------------------
bootloader_init:
    push ax
    push si
    
    ; Show bootloader splash
    mov si, bl_splash_msg
    call bl_print_string
    
    ; Initialize FAT filesystem
    call fat_init
    
    ; Initialize disk system
    call disk_init
    
    pop si
    pop ax
    ret

; ---------------------------------------------------------------------------
; boot_kernel: Load and execute KERNEL.ASM
; ---------------------------------------------------------------------------
boot_kernel:
    push ax
    push si
    
    ; Find KERNEL.ASM
    mov si, kernel_name
    call fat_find
    jc .kernel_not_found
    
    ; Load kernel to 0x1000:0x0000
    mov ax, [di+26]         ; starting cluster
    mov di, 0x1000
    mov es, di
    xor di, di
    call fat_read_file
    jc .kernel_load_error
    
    ; Jump to kernel
    jmp 0x1000:0x0000
    
.kernel_not_found:
    mov si, kernel_error_msg
    call bl_print_string
    jmp .error
    
.kernel_load_error:
    mov si, load_error_msg
    call bl_print_string
    
.error:
    pop si
    pop ax
    ret

; ---------------------------------------------------------------------------
; Overlay system
; ---------------------------------------------------------------------------
OVERLAY_BUF equ 0x8000

; overlay_load_run: Load and run overlay file
; Input: SI = pointer to 11-byte filename
overlay_load_run:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    ; Force root-directory search
    push word [cur_dir_cluster]
    mov word [cur_dir_cluster], 0

    call fat_find           ; SI = 11-byte name, result: DI = dir entry / CF
    jc .not_found

    ; Read overlay clusters into OVERLAY_BUF
    mov ax, [di+26]         ; starting cluster
    mov di, OVERLAY_BUF
    call fat_read_file

    ; Restore working directory
    pop word [cur_dir_cluster]

    ; Call the overlay
    call OVERLAY_BUF
    jmp .done

.not_found:
    pop word [cur_dir_cluster]
    push si
    mov si, overlay_err_msg
    call bl_print_string
    pop si

.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; Basic print functions
; ---------------------------------------------------------------------------
bl_print_string:
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

; ---------------------------------------------------------------------------
; Data section
; ---------------------------------------------------------------------------
bl_splash_msg:       db 0x0A, 0x0A, "KSDOS Bootloader Manager", 0x0A, 0x0A, 0
kernel_name:         db "KERNEL  ASM", 0
kernel_error_msg:    db "ERROR: KERNEL.ASM not found!", 0x0A, 0
load_error_msg:      db "ERROR: Failed to load kernel!", 0x0A, 0
overlay_err_msg:     db "ERROR: Overlay not found.", 0x0A, 0

; ---------------------------------------------------------------------------
; Essential system includes
; ---------------------------------------------------------------------------
%include "kernel/fat12.asm"
%include "kernel/disk.asm"

bootloader_end:
