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
; 0x0003: Kernel jump table - Essential system entries
; ---------------------------------------------------------------------------
%macro KTENTRY 1
    db 0xE9
    dw (%1) - ($ + 2)
%endmacro

    KTENTRY fat_find            ; 0x0003
    KTENTRY fat_read_file       ; 0x0006
    KTENTRY fat_load_dir        ; 0x0009
    KTENTRY fat_save_dir        ; 0x000C
    KTENTRY fat_save_fat        ; 0x000F
    KTENTRY fat_alloc_cluster   ; 0x0012
    KTENTRY fat_set_entry       ; 0x0015
    KTENTRY fat_find_free_slot  ; 0x0018
    KTENTRY cluster_to_lba      ; 0x001B
    KTENTRY fat_next_cluster    ; 0x001E
    KTENTRY disk_read_sector    ; 0x0021
    KTENTRY disk_write_sector   ; 0x0024
    KTENTRY install_to_hd       ; 0x0027

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

    ; Initialize text mode system
    call video_init_text_mode
    
    ; Show KSDOS text splash
    call splash_init
    
    ; Load system components with progress tracking
    call system_load_complete
    
    ; Start command shell
    call shell_main
    
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

    ; First try to find the overlay in mass-loaded files
    call mass_find_overlay
    jnc .found_in_memory

    ; If not found in memory, fall back to disk loading
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

.found_in_memory:
    ; Overlay is already loaded in memory at DI
    call di
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
; System Functions
; ---------------------------------------------------------------------------
video_init_text_mode:
    push ax
    mov ax, 0x0003      ; 80x25 text mode
    int 0x10
    pop ax
    ret

; ---------------------------------------------------------------------------
; System Data
; ---------------------------------------------------------------------------
ksdos_title_text: db "KSDOS Operating System", 0

; ---------------------------------------------------------------------------
; Essential system includes - ALL KERNEL MODULES + SYSTEM FILES
; ---------------------------------------------------------------------------
%include "string.asm"
%include "video.asm"
%include "keyboard.asm"
%include "disk.asm"
%include "fat12.asm"
%include "auth.asm"
%include "install.asm"
%include "shell.asm"
%include "splash.asm"
%include "ovl_api.asm"
%include "mass_loader.asm"
%include "compiler_asm.asm"
%include "compiler_c.asm"
%include "compiler_csc.asm"
%include "gold4.asm"
%include "icons.asm"
%include "ide.asm"
%include "music.asm"
%include "net.asm"
%include "opengl.asm"
%include "psyq.asm"
%include "ai.asm"
; ---------------------------------------------------------------------------
; SYSTEM DIRECTORY INCLUDES - ALL SYSTEM MODULES (NASM Compatible)
; ---------------------------------------------------------------------------
%include "system/BIOS/MSAUX.ASM"
%include "system/BIOS/MSCON.ASM"
%include "system/BIOS/MSDISK.ASM"
%include "system/BIOS/MSCLOCK.ASM"
%include "system/BIOS/MSHARD.ASM"
%include "system/BIOS/MSINIT.ASM"
%include "system/BIOS/MSLOAD.ASM"
%include "system/BIOS/MSLPT.ASM"
%include "system/BIOS/SYSCONF.ASM"
%include "system/BIOS/SYSIMES.ASM"
%include "system/BIOS/SYSINIT1.ASM"
%include "system/BIOS/SYSINIT2.ASM"
%include "system/DOS/ABORT.ASM"
%include "system/DOS/ALLOC.ASM"
%include "system/DOS/BUF.ASM"
%include "system/DOS/CLOSE.ASM"
%include "system/DOS/CPMIO.ASM"
%include "system/DOS/CPMIO2.ASM"
%include "system/DOS/CREATE.ASM"
%include "system/DOS/CRIT.ASM"
%include "system/DOS/CTRLC.ASM"
%include "system/DOS/DELETE.ASM"
%include "system/DOS/DEV.ASM"
%include "system/DOS/DINFO.ASM"
%include "system/DOS/DIR.ASM"
%include "system/DOS/DIR2.ASM"
%include "system/DOS/DIRCALL.ASM"
%include "system/DOS/DISK.ASM"
%include "system/DOS/DISK2.ASM"
%include "system/DOS/DISK3.ASM"
%include "system/DOS/DISP.ASM"
%include "system/DOS/DISPATCH.ASM"
%include "system/DOS/DOSMES.ASM"
%include "system/DOS/DUP.ASM"
%include "system/DOS/EXEC.ASM"
%include "system/DOS/EXTATTR.ASM"
%include "system/DOS/FAT.ASM"
%include "system/DOS/FCB.ASM"
%include "system/DOS/FCBIO.ASM"
%include "system/DOS/FCBIO2.ASM"
%include "system/DOS/FILE.ASM"
%include "system/DOS/FINFO.ASM"
%include "system/DOS/GETSET.ASM"
%include "system/DOS/HANDLE.ASM"
%include "system/DOS/IFS.ASM"
%include "system/DOS/IOCTL.ASM"
%include "system/DOS/ISEARCH.ASM"
%include "system/DOS/KSTRIN.ASM"
%include "system/DOS/LOCK.ASM"
%include "system/DOS/MACRO.ASM"
%include "system/DOS/MACRO2.ASM"
%include "system/DOS/MISC.ASM"
%include "system/DOS/MISC2.ASM"
%include "system/DOS/MKNODE.ASM"
%include "system/DOS/MSINIT.ASM"
%include "system/DOS/MS_CODE.ASM"
%include "system/DOS/MS_TABLE.ASM"
%include "system/DOS/OPEN.ASM"
%include "system/DOS/PARSE.ASM"
%include "system/DOS/PATH.ASM"
%include "system/DOS/PRINT.ASM"
%include "system/DOS/PROC.ASM"
%include "system/DOS/RENAME.ASM"
%include "system/DOS/ROM.ASM"
%include "system/DOS/SEARCH.ASM"
%include "system/DOS/SEGCHECK.ASM"
%include "system/DOS/SHARE.ASM"
%include "system/DOS/SRVCALL.ASM"
%include "system/DOS/STRIN.ASM"
%include "system/DOS/TIME.ASM"
%include "system/DOS/UTIL.ASM"

kernel_end:
