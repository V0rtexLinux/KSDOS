; =============================================================================
; ksdos.asm - KSDOS Kernel Entry Point
; 16-bit real mode x86, loaded at 0x1000:0x0000 by boot sector
; =============================================================================

BITS 16
ORG 0x0000

; ============================================================
; Entry: boot sector jumps here with DL=boot drive
; ============================================================
kernel_entry:
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    mov [boot_drive], dl

    ; Set 80x25 text mode
    mov ax, 0x0003
    int 0x10

    ; Hide cursor blinking
    mov ah, 0x01
    mov cx, 0x2607
    int 0x10

    call shell_run

    cli
.halt:
    hlt
    jmp .halt

; ============================================================
; Subsystem includes (order matters for forward references)
; ============================================================
%include "string.asm"
%include "video.asm"
%include "keyboard.asm"
%include "disk.asm"
%include "fat12.asm"
%include "opengl.asm"
%include "psyq.asm"
%include "gold4.asm"
%include "ide.asm"
%include "compiler_asm.asm"
%include "compiler_c.asm"
%include "compiler_csc.asm"
%include "music.asm"
%include "net.asm"
%include "shell.asm"

kernel_end:
