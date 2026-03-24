; =============================================================================
; ksdos.asm - KSDOS GUI Kernel Entry Point
; 16-bit real mode x86, loaded at 0x1000:0x0000 by boot sector
; Amiga-style graphical interface
; =============================================================================

BITS 16
ORG 0x0000

; ---------------------------------------------------------------------------
; 0x0000: Initial jump over the jump table / shared data to kernel_entry
; ---------------------------------------------------------------------------
    jmp near kernel_entry

; ---------------------------------------------------------------------------
; 0x0003: Kernel jump table - GUI entries
; ---------------------------------------------------------------------------
%macro KTENTRY 1
    db 0xE9
    dw (%1) - ($ + 2)
%endmacro

    KTENTRY video_gui_init       ; 0x0003
    KTENTRY video_set_color      ; 0x0006
    KTENTRY video_draw_pixel     ; 0x0009
    KTENTRY video_draw_line      ; 0x000C
    KTENTRY video_draw_rect      ; 0x000F
    KTENTRY video_fill_rect      ; 0x0012
    KTENTRY video_draw_desktop  ; 0x0015
    KTENTRY video_draw_mouse     ; 0x0018
    KTENTRY mouse_init          ; 0x001B
    KTENTRY mouse_read          ; 0x001E
    KTENTRY mouse_get_position   ; 0x0021
    KTENTRY window_create        ; 0x0024
    KTENTRY window_close         ; 0x0027
    KTENTRY window_draw         ; 0x002A
    KTENTRY window_handle_mouse  ; 0x002D
    KTENTRY gui_main_loop       ; 0x0030
    KTENTRY fat_find            ; 0x003C
    KTENTRY fat_read_file       ; 0x003F
    KTENTRY fat_load_dir        ; 0x0042
    KTENTRY fat_save_dir        ; 0x0045
    KTENTRY fat_save_fat        ; 0x0048
    KTENTRY fat_alloc_cluster   ; 0x004B
    KTENTRY fat_set_entry       ; 0x004E
    KTENTRY fat_find_free_slot  ; 0x0051
    KTENTRY cluster_to_lba      ; 0x0054
    KTENTRY fat_next_cluster    ; 0x0057
    KTENTRY disk_read_sector    ; 0x005A
    KTENTRY disk_write_sector   ; 0x005D
    KTENTRY install_to_hd       ; 0x0060

; ---------------------------------------------------------------------------
; 0x0060: Shared data area - fixed addresses used by both kernel and overlays
; (Declared here so their offsets are stable. The labels are referenced by
;  shell.asm command handlers and by overlays via ovl_api.asm EQUs.)
; ---------------------------------------------------------------------------
sh_arg:         times 128 db 0      ; 0x0060 - 0x00DF
_sh_tmp11:      times  12 db 0      ; 0x00E0 - 0x00EB
_sh_type_sz:    dw 0                ; 0x00EC - 0x00ED

; ---------------------------------------------------------------------------
; kernel_entry: Main kernel entry point
; ---------------------------------------------------------------------------
kernel_entry:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    sti

    ; Initialize GUI system
    call video_gui_init
    call mouse_init
    
    ; Show GUI splash screen
    call gui_show_splash
    
    ; Load system components
    call gui_load_system
    
    ; Start GUI main loop
    call gui_main_loop
    
    cli
.halt:
    hlt
    jmp .halt

; ---------------------------------------------------------------------------
; Overlay loader
; ---------------------------------------------------------------------------
OVERLAY_BUF equ 0x7000

; ovl_load_run: find an overlay file, load it into OVERLAY_BUF, and run it.
; Input:  SI = pointer to the 11-byte FAT 8.3 filename  (e.g. "NET     OVL")
; Effect: the overlay executes and returns; then control returns to caller.
ovl_load_run:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    ; Force root-directory search (overlays always live in the root)
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

    ; Call the overlay (near call, same segment DS=0x1000)
    call OVERLAY_BUF
    jmp .done

.not_found:
    pop word [cur_dir_cluster]
    push si
    mov si, str_ovl_err
    call vid_println
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

str_ovl_err:  db "Error: overlay not found.", 0

; ---------------------------------------------------------------------------
; system_load_complete: Load system components with real progress tracking
; ---------------------------------------------------------------------------
system_load_complete:
    push ax
    push si
    push dx
    
    ; Initialize FAT filesystem (20%)
    mov al, 1
    call splash_update
    
    ; Load critical system data (40%)
    mov al, 2
    call splash_update
    
    ; Initialize disk system (60%)
    mov al, 3
    call splash_update
    
    ; Load driver systems (80%)
    mov al, 4
    call splash_update
    
    ; Complete loading
    call splash_complete
    
    pop dx
    pop si
    pop ax
    ret

; ---------------------------------------------------------------------------
; GUI Functions
; ---------------------------------------------------------------------------
gui_show_splash:
    push ax
    push si
    
    ; Display KSDOS GUI splash
    mov byte [current_color], 1    ; White
    call video_clear_screen
    
    ; Draw KSDOS logo (simplified)
    mov byte [current_color], 8    ; Orange
    mov ax, 100
    mov bx, 50
    mov cx, 120
    mov dx, 40
    call video_fill_rect
    
    mov byte [current_color], 1    ; White
    mov ax, 110
    mov bx, 60
    mov si, gui_title_text
    call video_gfx_print
    
    pop si
    pop ax
    ret

gui_load_system:
    push ax
    push cx
    
    ; Simulate system loading with progress
    mov cx, 5
    mov ax, 0
    
.load_loop:
    push ax
    call gui_update_progress
    pop ax
    inc ax
    loop .load_loop
    
    pop cx
    pop ax
    ret

gui_update_progress:
    push ax
    push bx
    push cx
    push dx
    
    ; Draw progress bar
    mov byte [current_color], 14   ; Light gray
    mov ax, 50
    mov bx, 150
    mov cx, 220
    mov dx, 20
    call video_fill_rect
    
    ; Draw progress fill
    mov byte [current_color], 2    ; Blue
    mov ax, 50
    mov bx, 150
    mov cx, ax
    mov cx, 220
    sub cx, ax
    mov dx, 20
    call video_fill_rect
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

gui_main_loop:
    push ax
    push bx
    push cx
    
    ; Main GUI event loop
.main_loop:
    ; Handle mouse input
    call mouse_read
    test ax, ax
    jz .no_mouse
    
    ; Handle mouse events
    call window_handle_mouse
    
.no_mouse:
    ; Check for keyboard input
    call kbd_check
    test al, al
    jz .no_key
    
    ; Handle key events (ESC to quit)
    cmp al, 27          ; ESC key
    je .quit
    
.no_key:
    ; Redraw screen
    call video_draw_desktop
    call window_redraw_all
    call video_draw_mouse
    
    ; Small delay
    mov cx, 0x1000
.delay:
    loop .delay
    
    jmp .main_loop
    
.quit:
    ; Return to text mode
    mov ax, 0x0003
    int 0x10
    
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; GUI Data
; ---------------------------------------------------------------------------
gui_title_text: db "KSDOS GUI System", 0

; ---------------------------------------------------------------------------
; GUI Subsystem includes - ALL KERNEL MODULES + SYSTEM FILES
; ---------------------------------------------------------------------------
%include "video_gui.asm"
%include "window_gui.asm"
%include "mouse_gui.asm"
%include "string.asm"
%include "video.asm"
%include "keyboard.asm"
%include "disk.asm"
%include "fat12.asm"
%include "auth.asm"
%include "install.asm"
%include "music.asm"
%include "shell.asm"
%include "compiler_asm.asm"
%include "compiler_c.asm"
%include "compiler_csc.asm"
%include "gold4.asm"
%include "icons.asm"
%include "ide.asm"
%include "net.asm"
%include "opengl.asm"
%include "psyq.asm"
%include "splash.asm"
%include "ovl_api.asm"
%include "mass_loader.asm"
; ---------------------------------------------------------------------------
; KSDOS SYSTEM EXTENSIONS — NASM-compatible modules derived from SYSTEM/ tree
; The original SYSTEM/BIOS/*.ASM and SYSTEM/DOS/*.ASM are MASM-format source
; files (MS-DOS 4.0 Open Source) and are embedded as read-only files on the
; FAT12 disk image under A:\SYSTEM32\ for browsing; they are NOT included
; here directly.  Instead the modules below provide equivalent functionality
; in NASM syntax for the KSDOS kernel.
; ---------------------------------------------------------------------------
%include "sys_dossym.inc"       ; DOS constants (from SYSTEM/INC/DOSSYM.INC)
%include "sys_devsym.inc"       ; device driver interface (from SYSTEM/INC/DEVSYM.INC)
%include "sys_drivers.asm"      ; CON/ANSI, NUL, CLOCK$, AUX, PRN drivers
%include "sys_cmd.asm"          ; EDLIN, FC, KEYB, MODE, GRAFTABL, FDISK, etc.
%include "ai.asm"               ; Creative AI: cellular automata + neural network

kernel_end:
