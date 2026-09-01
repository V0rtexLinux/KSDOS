; =============================================================================
; SYSINFO.OVL  -  System Information  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
;
; MSD.EXE-style hardware report: CPU class (via the classic FLAGS-toggle
; detection ladder, ending in CPUID when available), conventional memory,
; equipment list, video mode and floppy geometry. Pure BIOS/CPU queries —
; no filesystem access, so it works even off a bare boot disk.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Strings
; ---------------------------------------------------------------------------
STR str_title,      "KSDOS SYSINFO v1.0 - Hardware Report"
STR str_sep,         "----------------------------------------------------"
STR str_cpu_hdr,     "CPU:        "
STR str_cpu_8086,    "8086 / V20 / 80186 class"
STR str_cpu_286,     "80286"
STR str_cpu_386,     "80386 (no CPUID)"
STR str_cpu_cpuid,   "CPUID-capable (486+) - "
STR str_cpu_family,  "  Family "
STR str_cpu_model,   " Model "
STR str_cpu_step,    " Stepping "
STR str_mem_hdr,     "Memory:     "
STR str_mem_kb,      " KB conventional"
STR str_math_hdr,    "Math unit:  "
STR str_yes,          "present"
STR str_no,           "not detected"
STR str_video_hdr,   "Video:      mode "
STR str_video_comma, ", "
STR str_video_cols,  " columns"
STR str_floppy_hdr,  "Floppies:   "
STR str_disk_hdr,    "Drive A:    "
STR str_disk_c,      " cyl / "
STR str_disk_h,      " heads / "
STR str_disk_s,      " sect/trk"
STR str_disk_none,    "not present"
STR str_footer,      "Press any key to exit..."

STRBUF si_vendor, 13   ; 12-char CPUID vendor string + NUL
U16 si_sig, 0           ; CPUID EAX=1 signature (stepping/model/family bits)

; ---------------------------------------------------------------------------
; U0 si_test_eflags_bit(EAX=bit mask)
; Returns AL=1 if the EFLAGS bit is writable (round-trips through a real
; toggle), else AL=0. EFLAGS is always restored to its original value.
; ---------------------------------------------------------------------------
FN U0, si_test_eflags_bit
    push ebx
    push ecx
    mov ecx, eax               ; ecx = mask to test
    pushfd
    pop eax
    mov ebx, eax                ; ebx = original EFLAGS
    xor eax, ecx
    push eax
    popfd
    pushfd
    pop eax
    xor eax, ebx
    and eax, ecx
    push ebx
    popfd                       ; restore original EFLAGS
    mov ebx, eax
    xor eax, eax
    test ebx, ebx
    jz .bit_fixed
    mov al, 1
.bit_fixed:
    pop ecx
    pop ebx
ENDFN

; ---------------------------------------------------------------------------
; U0 si_detect_cpu()
; Returns AL = 0 (8086/186), 1 (286), 2 (386), 3 (CPUID-capable)
; ---------------------------------------------------------------------------
FN U0, si_detect_cpu
    push bx

    ; --- Tier 0/1: can bits 12-15 of FLAGS be forced to 0? (286+ can) ---
    pushf
    pop ax
    mov bx, ax
    and ax, 0x0FFF
    push ax
    popf
    pushf
    pop ax
    and ax, 0xF000
    push bx
    popf                      ; restore original FLAGS
    cmp ax, 0xF000
    jne .t_286plus
    mov al, 0
    jmp .cpu_ret
.t_286plus:
    ; --- Tier 2: can EFLAGS.AC (bit 18) be toggled? (386+ can) ---
    mov eax, 0x00040000       ; AC flag
    call si_test_eflags_bit
    cmp al, 1
    je .t_386plus
    mov al, 1
    jmp .cpu_ret
.t_386plus:
    ; --- Tier 3: can EFLAGS.ID (bit 21) be toggled? (CPUID present) ---
    mov eax, 0x00200000       ; ID flag
    call si_test_eflags_bit
    cmp al, 1
    je .has_cpuid
    mov al, 2
    jmp .cpu_ret
.has_cpuid:
    mov al, 3
.cpu_ret:
    pop bx
ENDFN

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    PUSH_ALL

    Banner CYAN, str_title
    PrintLn str_sep

    ; ---- CPU class ----
    Print str_cpu_hdr
    call si_detect_cpu
    cmp al, 0
    je .cpu_8086
    cmp al, 1
    je .cpu_286
    cmp al, 2
    je .cpu_386
    jmp .cpu_cpuid
.cpu_8086:
    PrintLn str_cpu_8086
    jmp .cpu_done
.cpu_286:
    PrintLn str_cpu_286
    jmp .cpu_done
.cpu_386:
    PrintLn str_cpu_386
    jmp .cpu_done
.cpu_cpuid:
    Print str_cpu_cpuid
    ; Vendor string (EAX=0 -> EBX:EDX:ECX = 12 ASCII chars)
    xor eax, eax
    cpuid
    mov [si_vendor], ebx
    mov [si_vendor+4], edx
    mov [si_vendor+8], ecx
    mov byte [si_vendor+12], 0
    PrintLn si_vendor

    ; Family / model / stepping (EAX=1 -> low word of EAX)
    xor eax, eax
    inc eax
    cpuid
    mov [si_sig], ax

    Print str_cpu_family
    mov ax, [si_sig]
    shr ax, 8
    and ax, 0x0F
    call print_word_dec

    Print str_cpu_model
    mov ax, [si_sig]
    shr ax, 4
    and ax, 0x0F
    call print_word_dec

    Print str_cpu_step
    mov ax, [si_sig]
    and ax, 0x0F
    call print_word_dec
    NewLine
.cpu_done:

    ; ---- Conventional memory ----
    Print str_mem_hdr
    int 0x12
    call print_word_dec
    PrintLn str_mem_kb

    ; ---- Equipment list (math coprocessor + floppy count) ----
    int 0x11
    push ax
    Print str_math_hdr
    test ax, 0x0002
    jz .no_fpu
    PrintLn str_yes
    jmp .fpu_done
.no_fpu:
    PrintLn str_no
.fpu_done:
    pop ax
    Print str_floppy_hdr
    test al, 0x01
    jz .no_floppy
    mov cx, ax
    shr cx, 6
    and cx, 0x03
    inc cx
    mov ax, cx
    call print_word_dec
    NewLine
    jmp .floppy_done
.no_floppy:
    xor ax, ax
    call print_word_dec
    NewLine
.floppy_done:

    ; ---- Video mode ----
    Print str_video_hdr
    mov ah, 0x0F
    int 0x10
    push ax
    xor ah, ah
    call print_word_dec
    Print str_video_comma
    pop ax
    mov al, ah
    xor ah, ah
    call print_word_dec
    PrintLn str_video_cols

    ; ---- Floppy drive A: geometry ----
    Print str_disk_hdr
    mov ah, 0x08
    xor dl, dl
    int 0x13
    jc .disk_absent
    push cx
    Print str_disk_c
    xor ax, ax
    mov al, ch
    mov ah, cl
    shr ah, 6
    inc ax
    call print_word_dec
    Print str_disk_h
    xor ax, ax
    mov al, dh
    inc ax
    call print_word_dec
    pop cx
    Print str_disk_s
    xor ax, ax
    mov al, cl
    and al, 0x3F
    call print_word_dec
    NewLine
    jmp .disk_done
.disk_absent:
    PrintLn str_disk_none
.disk_done:

    PrintLn str_sep
    Print str_footer
    GetKey

    POP_ALL
ENDFN
