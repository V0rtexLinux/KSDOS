; =============================================================================
; SETUP2.OVL  -  KSDOS Setup Disk 2 of 2 (File Copy / Completion Screen)
; Written in HolyC16 — data declarations and functions use HolyC16 style.
; Runs at CS=0x0000, DS=0x0000 (far-called from kernel).
; Uses only BIOS INT 10h/16h and direct video RAM (0xB800:0).
; NO kernel API calls available here — must end with RETF.
; =============================================================================
BITS 16
ORG 0x7000
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Video attribute constants
; ---------------------------------------------------------------------------
ATTR_BG     equ 0x17    ; white on blue
ATTR_BODY   equ 0x1F    ; bright white on blue
ATTR_STATUS equ 0x70    ; black on white
ATTR_HILITE equ 0x1E    ; bright yellow on blue

; ---------------------------------------------------------------------------
; Per-file copy counters
; ---------------------------------------------------------------------------
U16 s2_file_cnt, 0
U16 s2_total,    12

; ---------------------------------------------------------------------------
; Static string data
; ---------------------------------------------------------------------------
STR str2_title,       "KSDOS v2.0 Setup"
STR str2_status,      "Please wait while Setup copies files to your computer..."
STR str2_status_done, "ENTER=Continue to KSDOS Shell"
STR str2_head,        "Setup is copying files to your computer."
STR str2_desc1,       "This may take several minutes. Do not interrupt this process."
STR str2_desc2,       "Do not remove the Setup disk from the drive."
STR str2_dest_label,  "Destination:  "
STR str2_dest_val,    "A:\KSDOS"
STR str2_copy_label,  "Copying:  "
STR str2_prog_label,  "Progress: "
STR str2_f1,          "KSDOS.SYS    "
STR str2_f2,          "COMMAND.COM  "
STR str2_f3,          "CONFIG.SYS   "
STR str2_f4,          "SHELL.OVL    "
STR str2_f5,          "CC.OVL       "
STR str2_f6,          "MASM.OVL     "
STR str2_f7,          "CSC.OVL      "
STR str2_f8,          "NET.OVL      "
STR str2_f9,          "AI.OVL       "
STR str2_f10,         "IDE.OVL      "
STR str2_f11,         "OPENGL.OVL   "
STR str2_f12,         "MUSIC.OVL    "
STR str2_done_head,   "KSDOS v2.0 is now installed on your computer."
STR str2_done1,       "Setup is complete. Remove the Setup Disk from drive A."
STR str2_done2,       "Then press ENTER to continue."
STR str2_done3,       "If KSDOS does not start, see your Setup documentation."
STR str2_done_notice, "[ Setup has finished installing KSDOS v2.0 ]"
STR str2_restart,     "* Remove the Setup disk from drive A."
STR str2_press_enter, "To continue to the KSDOS shell, press ENTER."

; ---------------------------------------------------------------------------
; U0 ovl_entry()  -  far-called by kernel; must end with RETF
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    mov ax, 0x0003
    int 0x10

    mov ax, 0xB800
    mov es, ax

    ; Fill screen background
    xor di, di
    mov cx, 80*25
    mov ax, (ATTR_BG << 8) | ' '
    rep stosw

    ; Title bar row 0
    xor di, di
    mov cx, 80
    mov ax, (ATTR_BODY << 8) | ' '
    rep stosw

    ; Status bar row 24
    mov di, (24*80)*2
    mov cx, 80
    mov ax, (ATTR_STATUS << 8) | ' '
    rep stosw

    ; Title bar text
    mov di, (0*80 + 1)*2
    mov ah, ATTR_BODY
    mov si, str2_title
    call s2_puts

    ; Status bar text
    mov di, (24*80 + 0)*2
    mov ah, ATTR_STATUS
    mov si, str2_status
    call s2_puts

    ; Body content
    mov ah, ATTR_BODY

    mov di, (3*80 + 3)*2
    mov si, str2_head
    call s2_puts

    mov di, (5*80 + 3)*2
    mov si, str2_desc1
    call s2_puts

    mov di, (6*80 + 3)*2
    mov si, str2_desc2
    call s2_puts

    ; Destination line
    mov di, (8*80 + 3)*2
    mov si, str2_dest_label
    call s2_puts
    mov ah, ATTR_HILITE
    call s2_puts_cont
    mov si, str2_dest_val
    call s2_puts

    ; Copying label
    mov ah, ATTR_BODY
    mov di, (10*80 + 3)*2
    mov si, str2_copy_label
    call s2_puts

    ; Progress label
    mov di, (13*80 + 3)*2
    mov si, str2_prog_label
    call s2_puts

    ; Animate file copy
    call s2_do_copy

    ; ---- Done screen ----
    mov ax, 0xB800
    mov es, ax
    mov di, (2*80)*2
    mov cx, 80*22
    mov ax, (ATTR_BG << 8) | ' '
    rep stosw

    ; Update status bar
    mov di, (24*80)*2
    mov cx, 80
    mov ax, (ATTR_STATUS << 8) | ' '
    rep stosw
    mov di, (24*80 + 0)*2
    mov ah, ATTR_STATUS
    mov si, str2_status_done
    call s2_puts

    ; Done messages
    mov ah, ATTR_BODY

    mov di, (4*80 + 3)*2
    mov si, str2_done_head
    call s2_puts

    mov di, (6*80 + 3)*2
    mov si, str2_done1
    call s2_puts

    mov di, (7*80 + 3)*2
    mov si, str2_done2
    call s2_puts

    mov di, (9*80 + 3)*2
    mov si, str2_done3
    call s2_puts

    mov ah, ATTR_HILITE
    mov di, (11*80 + 3)*2
    mov si, str2_done_notice
    call s2_puts

    mov ah, ATTR_BODY
    mov di, (14*80 + 3)*2
    mov si, str2_restart
    call s2_puts

    mov di, (16*80 + 3)*2
    mov si, str2_press_enter
    call s2_puts

    ; Park cursor
    mov ah, 0x02
    xor bh, bh
    mov dh, 24
    mov dl, 79
    int 0x10

.wait:
    xor ah, ah
    int 0x16
    cmp al, 0x0D
    je  .done
    jmp .wait

.done:
    mov ax, 0x0003
    int 0x10
    retf
; (no ENDFN — far return embedded above)

; ---------------------------------------------------------------------------
; U0 s2_do_copy()  -  animate all 12 files sequentially
; ---------------------------------------------------------------------------
FN U0, s2_do_copy
    PUSH_ALL

    mov si, str2_f1
    call s2_copy_file
    mov si, str2_f2
    call s2_copy_file
    mov si, str2_f3
    call s2_copy_file
    mov si, str2_f4
    call s2_copy_file
    mov si, str2_f5
    call s2_copy_file
    mov si, str2_f6
    call s2_copy_file
    mov si, str2_f7
    call s2_copy_file
    mov si, str2_f8
    call s2_copy_file
    mov si, str2_f9
    call s2_copy_file
    mov si, str2_f10
    call s2_copy_file
    mov si, str2_f11
    call s2_copy_file
    mov si, str2_f12
    call s2_copy_file

    POP_ALL
ENDFN

; ---------------------------------------------------------------------------
; U0 s2_copy_file()  -  show one file copying and advance progress bar
; Input: SI = filename string
; ---------------------------------------------------------------------------
FN U0, s2_copy_file
    PUSH_ALL

    ; Increment file counter
    mov ax, [s2_file_cnt]
    inc ax
    mov [s2_file_cnt], ax

    ; Clear filename field (row 10, col 12, 20 chars)
    mov ax, 0xB800
    mov es, ax
    mov di, (10*80 + 12)*2
    mov cx, 20
    mov ax, (ATTR_HILITE << 8) | ' '
    rep stosw

    ; Write highlighted filename
    mov di, (10*80 + 12)*2
    mov ah, ATTR_HILITE
    call s2_puts        ; SI still = filename

    ; Filled bar blocks = file_cnt * 50 / total
    mov ax, [s2_file_cnt]
    mov bx, 50
    mul bx
    mov bx, [s2_total]
    div bx
    mov cx, ax          ; CX = filled blocks
    mov bx, 50
    sub bx, cx          ; BX = empty blocks

    ; Draw progress bar at row 13, col 3
    mov di, (13*80 + 3)*2

    ; Opening bracket
    mov ax, (ATTR_BODY << 8) | '['
    stosw

    ; Filled portion
    push bx
    mov ax, (ATTR_HILITE << 8) | 0xDB
.fill:
    test cx, cx
    jz   .fill_done
    stosw
    dec cx
    jmp  .fill
.fill_done:
    pop bx

    ; Empty portion
    mov ax, (ATTR_BG << 8) | 0xB0
.empty:
    test bx, bx
    jz   .empty_done
    stosw
    dec bx
    jmp  .empty
.empty_done:

    ; Closing bracket
    mov ax, (ATTR_BODY << 8) | ']'
    stosw

    ; Percentage: file_cnt * 100 / total
    mov ax, (ATTR_BODY << 8) | ' '
    stosw
    mov ax, [s2_file_cnt]
    mov bx, 100
    mul bx
    mov bx, [s2_total]
    div bx
    call s2_print_num
    mov ax, (ATTR_BODY << 8) | '%'
    stosw

    ; Short hardware delay
    mov cx, 0xBFFF
.delay:
    loop .delay

    POP_ALL
ENDFN

; ---------------------------------------------------------------------------
; U0 s2_print_num()
; Write AX as decimal digits to ES:DI (advances DI).
; ---------------------------------------------------------------------------
FN U0, s2_print_num
    push ax
    push bx
    push cx
    push dx
    xor cx, cx
.digit:
    xor dx, dx
    mov bx, 10
    div bx
    push dx
    inc cx
    test ax, ax
    jnz  .digit
.ploop:
    pop dx
    mov al, dl
    add al, '0'
    mov ah, ATTR_BODY
    stosw
    loop .ploop
    pop dx
    pop cx
    pop bx
    pop ax
ENDFN

; ---------------------------------------------------------------------------
; U0 s2_puts()
; Write null-terminated DS:SI with attribute AH into ES:DI.
; Advances DI; preserves all other registers.
; ---------------------------------------------------------------------------
FN U0, s2_puts
    push ax
    push si
.loop:
    lodsb
    test al, al
    jz   .done
    stosw
    jmp  .loop
.done:
    pop si
    pop ax
ENDFN

; ---------------------------------------------------------------------------
; U0 s2_puts_cont()
; Placeholder — DI already advanced correctly by prior s2_puts call.
; ---------------------------------------------------------------------------
FN U0, s2_puts_cont
ENDFN
