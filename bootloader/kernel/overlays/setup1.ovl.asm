; =============================================================================
; SETUP1.OVL  -  KSDOS Setup Disk 1 of 2 (Welcome Screen)
; Written in HolyC16 — data declarations and functions use HolyC16 style.
; Runs at CS=0x0000, DS=0x0000 (far-called from kernel).
; Uses only BIOS INT 10h/16h and direct video RAM (0xB800:0).
; NO kernel API calls available at this address — must end with RETF.
; =============================================================================
BITS 16
ORG 0x7000
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Video attribute constants (MS-DOS 6.22 Setup style)
; ---------------------------------------------------------------------------
ATTR_BG     equ 0x17    ; white on blue    (background fill)
ATTR_BODY   equ 0x1F    ; bright white on blue
ATTR_STATUS equ 0x70    ; black on white   (status bar)

; ---------------------------------------------------------------------------
; Static string data
; ---------------------------------------------------------------------------
STR str_title,    "KSDOS v2.0 Setup"
STR str_status,   "ENTER=Continue  F1=Help  F3=Exit  F5=Remove Color  F7=Install to a Floppy Disk"
STR str_welcome,  "Welcome to Setup."
STR str_intro1,   "The Setup program prepares KSDOS v2.0 to run on your"
STR str_intro2,   "computer."
STR str_b1,       "* To set up KSDOS now, press ENTER."
STR str_b2,       "* To learn more about Setup before continuing, press F1."
STR str_b3,       "* To exit Setup without installing KSDOS, press F3."
STR str_note1,    "Note: If you have not backed up your files recently, you"
STR str_note2,    "might want to do so before installing KSDOS. To back"
STR str_note3,    "up your files, press F3 to quit Setup now. Then, back"
STR str_note4,    "up your files by using a backup program."
STR str_continue, "To continue Setup, press ENTER."

; ---------------------------------------------------------------------------
; U0 ovl_entry()  -  overlay entry (far-called by kernel; must RETF)
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    ; 80x25 text mode — hardware clear
    mov ax, 0x0003
    int 0x10

    ; Point ES at the CGA/VGA text buffer
    mov ax, 0xB800
    mov es, ax

    ; Fill entire screen with background colour
    xor di, di
    mov cx, 80*25
    mov ax, (ATTR_BG << 8) | ' '
    rep stosw

    ; Title bar — row 0, bright white on blue
    xor di, di
    mov cx, 80
    mov ax, (ATTR_BODY << 8) | ' '
    rep stosw

    ; Status bar — row 24, black on white
    mov di, (24*80)*2
    mov cx, 80
    mov ax, (ATTR_STATUS << 8) | ' '
    rep stosw

    ; Write title bar text
    mov di, (0*80 + 1)*2
    mov ah, ATTR_BODY
    mov si, str_title
    call s1_puts

    ; Write status bar text
    mov di, (24*80 + 0)*2
    mov ah, ATTR_STATUS
    mov si, str_status
    call s1_puts

    ; Body content
    mov ah, ATTR_BODY

    mov di, (3*80 + 3)*2
    mov si, str_welcome
    call s1_puts

    mov di, (5*80 + 3)*2
    mov si, str_intro1
    call s1_puts

    mov di, (6*80 + 3)*2
    mov si, str_intro2
    call s1_puts

    mov di, (8*80 + 6)*2
    mov si, str_b1
    call s1_puts

    mov di, (10*80 + 6)*2
    mov si, str_b2
    call s1_puts

    mov di, (12*80 + 6)*2
    mov si, str_b3
    call s1_puts

    mov di, (14*80 + 3)*2
    mov si, str_note1
    call s1_puts

    mov di, (15*80 + 11)*2
    mov si, str_note2
    call s1_puts

    mov di, (16*80 + 11)*2
    mov si, str_note3
    call s1_puts

    mov di, (17*80 + 11)*2
    mov si, str_note4
    call s1_puts

    mov di, (20*80 + 3)*2
    mov si, str_continue
    call s1_puts

    ; Park cursor at bottom-right
    mov ah, 0x02
    xor bh, bh
    mov dh, 24
    mov dl, 79
    int 0x10

.wait:
    xor ah, ah
    int 0x16
    cmp al, 0x0D        ; ENTER — hand control back, kernel loads SETUP2
    je  .do_enter
    cmp ah, 0x3D        ; F3   — exit setup, boot straight to shell
    je  .do_exit
    jmp .wait

.do_enter:
    retf

.do_exit:
    mov ax, 0x0003
    int 0x10
    retf
; (no ENDFN — far return embedded above)

; ---------------------------------------------------------------------------
; U0 s1_puts()
; Write null-terminated DS:SI with attribute AH into ES:DI.
; Each character occupies 2 bytes in video RAM: [char][attr].
; Advances DI; preserves all other registers.
; ---------------------------------------------------------------------------
FN U0, s1_puts
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
