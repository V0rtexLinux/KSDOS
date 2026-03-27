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
%include "SYSTEM/BIOS/MSAUX.ASM"
%include "SYSTEM/BIOS/MSCON.ASM"
%include "SYSTEM/BIOS/MSDISK.ASM"
%include "SYSTEM/BIOS/MSCLOCK.ASM"
%include "SYSTEM/BIOS/MSHARD.ASM"
%include "SYSTEM/BIOS/MSINIT.ASM"
%include "SYSTEM/BIOS/MSLOAD.ASM"
%include "SYSTEM/BIOS/MSLPT.ASM"
%include "SYSTEM/BIOS/SYSCONF.ASM"
%include "SYSTEM/BIOS/SYSIMES.ASM"
%include "SYSTEM/BIOS/SYSINIT1.ASM"
%include "SYSTEM/BIOS/SYSINIT2.ASM"
%include "SYSTEM/DOS/ABORT.ASM"
%include "SYSTEM/DOS/ALLOC.ASM"
%include "SYSTEM/DOS/BUF.ASM"
%include "SYSTEM/DOS/CLOSE.ASM"
%include "SYSTEM/DOS/CPMIO.ASM"
%include "SYSTEM/DOS/CPMIO2.ASM"
%include "SYSTEM/DOS/CREATE.ASM"
%include "SYSTEM/DOS/CRIT.ASM"
%include "SYSTEM/DOS/CTRLC.ASM"
%include "SYSTEM/DOS/DELETE.ASM"
%include "SYSTEM/DOS/DEV.ASM"
%include "SYSTEM/DOS/DINFO.ASM"
%include "SYSTEM/DOS/DIR.ASM"
%include "SYSTEM/DOS/DIR2.ASM"
%include "SYSTEM/DOS/DIRCALL.ASM"
%include "SYSTEM/DOS/DISK.ASM"
%include "SYSTEM/DOS/DISK2.ASM"
%include "SYSTEM/DOS/DISK3.ASM"
%include "SYSTEM/DOS/DISP.ASM"
%include "SYSTEM/DOS/DISPATCH.ASM"
%include "SYSTEM/DOS/DOSMES.ASM"
%include "SYSTEM/DOS/DUP.ASM"
%include "SYSTEM/DOS/EXEC.ASM"
%include "SYSTEM/DOS/EXTATTR.ASM"
%include "SYSTEM/DOS/FAT.ASM"
%include "SYSTEM/DOS/FCB.ASM"
%include "SYSTEM/DOS/FCBIO.ASM"
%include "SYSTEM/DOS/FCBIO2.ASM"
%include "SYSTEM/DOS/FILE.ASM"
%include "SYSTEM/DOS/FINFO.ASM"
%include "SYSTEM/DOS/GETSET.ASM"
%include "SYSTEM/DOS/HANDLE.ASM"
%include "SYSTEM/DOS/IFS.ASM"
%include "SYSTEM/DOS/IOCTL.ASM"
%include "SYSTEM/DOS/ISEARCH.ASM"
%include "SYSTEM/DOS/KSTRIN.ASM"
%include "SYSTEM/DOS/LOCK.ASM"
%include "SYSTEM/DOS/MACRO.ASM"
%include "SYSTEM/DOS/MACRO2.ASM"
%include "SYSTEM/DOS/MISC.ASM"
%include "SYSTEM/DOS/MISC2.ASM"
%include "SYSTEM/DOS/MKNODE.ASM"
%include "SYSTEM/DOS/MSINIT.ASM"
%include "SYSTEM/DOS/MS_CODE.ASM"
%include "SYSTEM/DOS/MS_TABLE.ASM"
%include "SYSTEM/DOS/OPEN.ASM"
%include "SYSTEM/DOS/PARSE.ASM"
%include "SYSTEM/DOS/PATH.ASM"
%include "SYSTEM/DOS/PRINT.ASM"
%include "SYSTEM/DOS/PROC.ASM"
%include "SYSTEM/DOS/RENAME.ASM"
%include "SYSTEM/DOS/ROM.ASM"
%include "SYSTEM/DOS/SEARCH.ASM"
%include "SYSTEM/DOS/SEGCHECK.ASM"
%include "SYSTEM/DOS/SHARE.ASM"
%include "SYSTEM/DOS/SRVCALL.ASM"
%include "SYSTEM/DOS/STRIN.ASM"
%include "SYSTEM/DOS/TIME.ASM"
%include "SYSTEM/DOS/UTIL.ASM"

kernel_end:
