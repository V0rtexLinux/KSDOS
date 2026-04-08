; =============================================================================
; CC.OVL  -  KSDOS C / C++ Compiler  (KSDOS-CC / KSDOS-G++)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; sh_arg (0x0060) = source filename (.c / .cpp)
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Overlay-local working variables  (mirrors shell _sh_copy_* vars)
; ---------------------------------------------------------------------------
U16 _sh_copy_sz, 0
U16 _sh_copy_cl, 0

; ---------------------------------------------------------------------------
; Static string data
; ---------------------------------------------------------------------------
STR str_banner, "KSDOS-CC C/C++ Compiler v1.0  [16-bit real mode]"
STR str_comp,   "Compiling: "
STR str_nf,     "File not found."
STR str_usage,  "Usage: CC <file.c>  or  GCC/CPP/G++ <file>"

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

    Print   str_comp
    PrintLn sh_arg

    call ovl_load_src
    ON_ERROR .not_found

    call cc_run
    ret

.not_found:
    PrintLn str_nf
ENDFN

; ---------------------------------------------------------------------------
; U0 ovl_load_src()
; Reads filename from sh_arg, finds it on FAT, loads into FILE_BUF.
; Sets _sh_type_sz = file size in bytes.  CF=1 on error.
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
; Compiler module code
; ---------------------------------------------------------------------------
%include "../compiler_asm.asm"
%include "../compiler_c.asm"
