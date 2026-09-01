; =============================================================================
; WINFILE.OVL  -  File manager (System32-style utility)  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Lists the current directory (root, unless the shell has CD'd elsewhere):
; name, extension, size in bytes, and <DIR> for subdirectories.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

PAGE_SIZE equ 18
STR str_title,  "FILE MANAGER"
STR str_dir,    "<DIR>"
STR str_bytes,  " bytes"
STR str_more,   "-- more (any key), ESC to quit --"
STR str_empty,  "(empty directory)"
STR str_dot,    "."

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    call fat_load_dir

    ClearScreen
    Banner CYAN, str_title
    NewLine

    mov di, DIR_BUF
    mov cx, 224
    mov word [_wf_shown], 0
    mov word [_wf_line], 0
.scan:
    test cx, cx
    jz .scandone
    cmp byte [di], 0x00
    je .scandone
    cmp byte [di], 0xE5
    je .skip
    test byte [di+11], 0x08     ; volume label
    jnz .skip
    test byte [di+11], 0x02     ; hidden - skip in the listing
    jnz .skip

    call wf_print_entry
    inc word [_wf_shown]
    inc word [_wf_line]
    mov ax, [_wf_line]
    cmp ax, PAGE_SIZE
    jl .skip
    mov word [_wf_line], 0
    PrintLn str_more
    GetKey
    cmp al, 27
    je .done
    ClearScreen
    Banner CYAN, str_title
    NewLine
.skip:
    add di, 32
    dec cx
    jmp .scan
.scandone:
    cmp word [_wf_shown], 0
    jne .waitkey
    PrintLn str_empty
.waitkey:
    NewLine
    Print str_more
    GetKey
.done:
ENDFN
_wf_shown: dw 0
_wf_line:  dw 0

; wf_print_entry: DI = 32-byte directory entry -> prints "name.ext  size"
wf_print_entry:
    push ax
    push cx
    push si

    ; base name (8 chars, space-padded)
    mov si, di
    mov cx, 8
.pname:
    mov al, [si]
    cmp al, ' '
    je .pname_done
    call vid_putchar
    inc si
    loop .pname
.pname_done:

    ; extension, if present
    mov si, di
    add si, 8
    cmp byte [si], ' '
    je .noext
    Print str_dot
    mov cx, 3
.pext:
    mov al, [si]
    cmp al, ' '
    je .pext_done
    call vid_putchar
    inc si
    loop .pext
.pext_done:
.noext:

    ; pad to a fixed column, then size or <DIR>
    mov cx, 4
.pad:
    PrintChar ' '
    loop .pad

    test byte [di+11], 0x10
    jz .isfile
    Print str_dir
    jmp .pedone
.isfile:
    mov ax, [di+28]              ; size (low word)
    call print_word_dec
    Print str_bytes
.pedone:
    NewLine

    pop si
    pop cx
    pop ax
    ret
