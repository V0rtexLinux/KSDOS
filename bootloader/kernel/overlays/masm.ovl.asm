; =============================================================================
; MASM.OVL  -  KSDOS Macro Assembler  (MASM / NASM compatible)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; sh_arg (0x0060) = source filename (.asm)
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Overlay-local working variables
; ---------------------------------------------------------------------------
U16 _sh_copy_sz, 0
U16 _sh_copy_cl, 0

; ---------------------------------------------------------------------------
; Static string data
; ---------------------------------------------------------------------------
STR str_banner, "KSDOS-ASM Macro Assembler v1.0  [MASM/NASM compatible]"
STR str_asm,    "Assembling: "
STR str_nf,     "File not found."
STR str_usage,  "Usage: MASM <file.asm>  or  NASM <file.asm>"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    Banner CYAN, str_banner

    cmp byte [sh_arg], 0
    IF e
        PrintLn str_usage
        ret
    ENDIF

    Print   str_asm
    PrintLn sh_arg

    call ovl_load_src
    ON_ERROR .not_found

    call asm_run
    ret

.not_found:
    PrintLn str_nf
ENDFN

; ---------------------------------------------------------------------------
; U0 ovl_load_src()
; Reads filename from sh_arg, finds it on FAT, loads into FILE_BUF.
; CF=1 on error.
; ---------------------------------------------------------------------------
FN U0, ovl_load_src
    mov si, sh_arg
    mov di, _sh_tmp11
    call str_to_dosname
    call fat_load_dir
    mov si, _sh_tmp11
    call fat_find
    ON_ERROR .nf

    mov ax, [di+28]
    mov [_sh_type_sz], ax
    mov ax, [di+26]
    push ax
    mov di, FILE_BUF
    call fat_read_file
    pop ax
    clc
    ret

.nf:
    stc
ENDFN

; ---------------------------------------------------------------------------
; Assembler module code
; ---------------------------------------------------------------------------
%include "../compiler_asm.asm"
