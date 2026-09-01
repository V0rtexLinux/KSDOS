; =============================================================================
; NOTEPAD.OVL  -  Text file viewer (System32-style utility)  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Prompts for an 8.3 filename, loads it via the kernel's FAT12 driver, and
; displays it a screenful at a time. Read-only (a rushed write path risks
; corrupting the filesystem, so this deliberately stays a viewer).
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

FILEBUF_SIZE equ 8192
STRBUF filebuf, FILEBUF_SIZE
STRBUF fname11, 11
STRBUF namein,  9
STRBUF extin,   4

STR str_title,  "NOTEPAD - text file viewer"
STR str_name,   "File name (up to 8 chars, no ext): "
STR str_ext,    "Extension (up to 3 chars): "
STR str_nf,     "File not found."
STR str_toobig, "(file truncated to buffer size)"
STR str_more,   "-- more (any key), ESC to quit --"
STR str_again,  "View another file? (Y/N): "

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
.new_file:
    ClearScreen
    Banner CYAN, str_title
    NewLine

    Print str_name
    ReadLine namein, 8
    call _uc_str9
    Print str_ext
    ReadLine extin, 3
    call _uc_str4

    call np_build_name

    mov si, fname11
    call fat_find
    jc .notfound

    mov ax, [di+26]
    mov di, filebuf
    call fat_read_file
    ; fat_read_file returns CX = sectors read (approx); null-terminate
    ; defensively at the end of the buffer regardless
    mov word [filebuf + FILEBUF_SIZE - 2], 0

    ClearScreen
    Banner CYAN, str_title
    NewLine

    mov si, filebuf
    mov word [_np_lines], 0
.show:
    lodsb
    test al, al
    jz .shown
    call vid_putchar
    cmp al, 10
    jne .show
    inc word [_np_lines]
    mov ax, [_np_lines]
    cmp ax, 20
    jl .show
    mov word [_np_lines], 0
    PrintLn str_more
    GetKey
    cmp al, 27
    je .ask_again
    ClearScreen
    Banner CYAN, str_title
    NewLine
    jmp .show
.shown:
    NewLine
    NewLine
    Print str_more
    GetKey
    jmp .ask_again

.notfound:
    PrintLn str_nf
    GetKey

.ask_again:
    Print str_again
    GetKey
    NewLine
    cmp al, 'y'
    je .new_file
    cmp al, 'Y'
    je .new_file
ENDFN
_np_lines: dw 0

; _uc_str9 / _uc_str4: uppercase the namein/extin buffers in place
_uc_str9:
    push ax
    push si
    mov si, namein
    call _uc_loop
    pop si
    pop ax
    ret
_uc_str4:
    push ax
    push si
    mov si, extin
    call _uc_loop
    pop si
    pop ax
    ret
_uc_loop:
    push ax
.lp:
    mov al, [si]
    test al, al
    jz .done
    cmp al, 'a'
    jb .next
    cmp al, 'z'
    ja .next
    sub al, 32
    mov [si], al
.next:
    inc si
    jmp .lp
.done:
    pop ax
    ret

; np_build_name: build the 11-byte FAT name from namein/extin into fname11
np_build_name:
    push ax
    push cx
    push si
    push di
    mov di, fname11
    mov cx, 11
.padclr:
    mov byte [di], ' '
    inc di
    loop .padclr

    mov si, namein
    mov di, fname11
    mov cx, 8
.copyname:
    mov al, [si]
    test al, al
    jz .namedone
    mov [di], al
    inc si
    inc di
    loop .copyname
.namedone:

    mov si, extin
    mov di, fname11
    add di, 8
    mov cx, 3
.copyext:
    mov al, [si]
    test al, al
    jz .extdone
    mov [di], al
    inc si
    inc di
    loop .copyext
.extdone:
    pop di
    pop si
    pop cx
    pop ax
    ret
