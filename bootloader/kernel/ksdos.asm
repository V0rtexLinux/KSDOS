; =============================================================================
; ksdos.asm  -  KSDOS Kernel Entry Point
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; 16-bit real mode x86, loaded at 0x1000:0x0000 by the boot sector.
; =============================================================================

BITS 16
ORG 0x0000

; ---------------------------------------------------------------------------
; 0x0000: Initial far-jump over the jump table to kernel_entry
; ---------------------------------------------------------------------------
    jmp near kernel_entry

; ---------------------------------------------------------------------------
; 0x0003: Kernel jump table
; Each entry is a 3-byte near JMP pointing to the real kernel function.
; Overlays call these via the EQU addresses defined in ovl_api.asm.
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
    KTENTRY ovl_load_run        ; 0x002A

; ---------------------------------------------------------------------------
; 0x0060: Shared data area — fixed addresses used by kernel and overlays.
; Labels must match the EQU declarations in ovl_api.asm exactly.
; ---------------------------------------------------------------------------
%define BUILDING_KERNEL
sh_arg:         times 128 db 0      ; 0x0060–0x00DF
_sh_tmp11:      times  12 db 0      ; 0x00E0–0x00EB
_sh_type_sz:    dw 0                ; 0x00EC–0x00ED

; ---------------------------------------------------------------------------
; Include HolyC16 macro library  (after BUILDING_KERNEL define)
; ---------------------------------------------------------------------------
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; U0 kernel_entry()  -  main kernel entry point
; ---------------------------------------------------------------------------
FN U0, kernel_entry
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE
    sti

    call video_init_text_mode
    call splash_init
    call system_load_complete
    call setup_firstrun_check
    call shell_run

    cli
.halt:
    hlt
    jmp .halt
; (intentionally no ENDFN — kernel never returns)

; ---------------------------------------------------------------------------
; OVERLAY_BUF: fixed address where overlay binaries are loaded
; ---------------------------------------------------------------------------
OVERLAY_BUF equ 0x7000

; ---------------------------------------------------------------------------
; U0 ovl_load_run()
; Load an overlay file into OVERLAY_BUF and execute it.
; Input:  SI = pointer to 11-byte FAT 8.3 filename (e.g. "NET     OVL")
; Effect: overlay executes and returns; control returns to caller.
; ---------------------------------------------------------------------------
FN U0, ovl_load_run
    PUSH_ALL
    push es

    ; Check if the overlay is already mass-loaded in memory
    call mass_find_overlay
    ON_OK .found_in_memory

    ; Force root-directory search (overlays always live in the root)
    push word [cur_dir_cluster]
    mov  word [cur_dir_cluster], 0

    call fat_find               ; SI = 11-byte name → DI = dir entry / CF
    ON_ERROR .not_found

    ; Read overlay clusters into OVERLAY_BUF
    mov ax, [di+26]             ; starting cluster from dir entry
    mov di, OVERLAY_BUF
    call fat_read_file

    pop word [cur_dir_cluster]

    ; Far-call the overlay at 0x0000:OVERLAY_BUF
    db  0x9A
    dw  OVERLAY_BUF
    dw  0x0000
    jmp .done

.found_in_memory:
    call di
    jmp .done

.not_found:
    pop word [cur_dir_cluster]
    push si
    PrintLn str_ovl_err
    pop si

.done:
    pop es
    POP_ALL
ENDFN

STR str_ovl_err, "Error: overlay not found."

; ---------------------------------------------------------------------------
; U0 setup_firstrun_check()
; Auto-detect installer disk (Disk 1).  If SETUP1.OVL exists, run it.
; Then chain to SETUP2.OVL if present.  On a normal disk, does nothing.
; ---------------------------------------------------------------------------
FN U0, setup_firstrun_check
    PUSH_ALL
    push word [cur_dir_cluster]

    call fat_init
    call fat_load_root

    ; Build "SETUP1  OVL" on the stack (DS=0 space, safe for fat_find)
    sub sp, 12
    mov si, sp
    mov byte [si+0],  'S'
    mov byte [si+1],  'E'
    mov byte [si+2],  'T'
    mov byte [si+3],  'U'
    mov byte [si+4],  'P'
    mov byte [si+5],  '1'
    mov byte [si+6],  ' '
    mov byte [si+7],  ' '
    mov byte [si+8],  'O'
    mov byte [si+9],  'V'
    mov byte [si+10], 'L'
    mov byte [si+11], 0

    mov word [cur_dir_cluster], 0
    call fat_find
    ON_ERROR .no_setup

    ; Load and far-call SETUP1.OVL (must end with RETF)
    mov ax, [di+26]
    mov di, OVERLAY_BUF
    call fat_read_file

    add sp, 12
    pop word [cur_dir_cluster]

    db  0x9A
    dw  OVERLAY_BUF
    dw  0x0000

    ; After SETUP1 returns, chain to SETUP2 if present
    push word [cur_dir_cluster]
    sub sp, 12
    mov si, sp
    mov byte [si+0],  'S'
    mov byte [si+1],  'E'
    mov byte [si+2],  'T'
    mov byte [si+3],  'U'
    mov byte [si+4],  'P'
    mov byte [si+5],  '2'
    mov byte [si+6],  ' '
    mov byte [si+7],  ' '
    mov byte [si+8],  'O'
    mov byte [si+9],  'V'
    mov byte [si+10], 'L'
    mov byte [si+11], 0

    mov word [cur_dir_cluster], 0
    call fat_find
    ON_ERROR .no_setup2

    mov ax, [di+26]
    mov di, OVERLAY_BUF
    call fat_read_file

    add sp, 12
    pop word [cur_dir_cluster]

    db  0x9A
    dw  OVERLAY_BUF
    dw  0x0000

    POP_ALL
    ret

.no_setup2:
    add sp, 12
    pop word [cur_dir_cluster]
    POP_ALL
    ret

.no_setup:
    add sp, 12
    pop word [cur_dir_cluster]
    POP_ALL
ENDFN

; ---------------------------------------------------------------------------
; U0 system_load_complete()
; Advance the splash progress bar through loading stages.
; ---------------------------------------------------------------------------
FN U0, system_load_complete
    push ax
    push si
    push dx

    mov al, 1
    call splash_update      ; 20% — FAT initialised

    mov al, 2
    call splash_update      ; 40% — system data loaded

    mov al, 3
    call splash_update      ; 60% — disk system ready

    mov al, 4
    call splash_update      ; 80% — drivers loaded

    call splash_complete    ; 100% — done

    pop dx
    pop si
    pop ax
ENDFN

; ---------------------------------------------------------------------------
; U0 video_init_text_mode()
; Switch to 80x25 colour text mode via BIOS INT 10h.
; ---------------------------------------------------------------------------
FN U0, video_init_text_mode
    push ax
    mov ax, 0x0003          ; BIOS: set video mode 3 (80x25 text)
    int 0x10
    pop ax
ENDFN

; ---------------------------------------------------------------------------
; Kernel string data
; ---------------------------------------------------------------------------
STR ksdos_title_text, "KSDOS Operating System"

; ---------------------------------------------------------------------------
; Essential system module includes (order matters — forward refs resolved here)
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
; NOTE: SYSTEM/BIOS and SYSTEM/DOS contain MS-DOS 4.0 source in MASM syntax.
; They are preserved as historical reference only; they cannot be assembled
; with NASM and are not included here.
; ---------------------------------------------------------------------------

kernel_end:
