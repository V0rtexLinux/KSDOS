; =============================================================================
; splash.asm - KSDOS Enhanced VGA Boot Screen
; Direct VGA text buffer writes - full color, no ANSI dependency
; 16-bit real mode, DS=0x0000 (flat)
; =============================================================================

; ---------------------------------------------------------------------------
; VGA text mode color attribute constants  (background<<4 | foreground)
; Foreground: 0=black 1=blue 2=green 3=cyan 4=red 5=magenta 6=brown 7=lgray
;             8=dgray 9=lblue A=lgreen B=lcyan C=lred D=lmagenta E=yellow F=white
; Background: same but bits 4-6 only (0-7)
; ---------------------------------------------------------------------------
ATTR_FILL       equ 0x17    ; light gray on blue  — screen background
ATTR_TOPBAR     equ 0x70    ; black on white       — top title bar
ATTR_LOGO       equ 0x1F    ; bright white on blue — ASCII art logo
ATTR_SUBTITLE   equ 0x1B    ; bright cyan on blue  — subtitle line
ATTR_VERSION    equ 0x1E    ; yellow on blue       — version/date
ATTR_STATUS     equ 0x17    ; light gray on blue   — loading messages
ATTR_BAR_BORDER equ 0x1F    ; bright white on blue — [ and ] brackets
ATTR_BAR_FILL   equ 0x2A    ; bright green on green — filled portion
ATTR_BAR_EMPTY  equ 0x18    ; dark yellow on blue  — empty portion
ATTR_BOTBAR     equ 0x71    ; blue on white        — bottom status bar
ATTR_HIGHLIGHT  equ 0x1C    ; bright red on blue   — highlights

VGA_SEG         equ 0xB800
SCREEN_COLS     equ 80
SCREEN_ROWS     equ 25

; ---------------------------------------------------------------------------
; Splash state
; ---------------------------------------------------------------------------
splash_stage    db 0        ; current stage 0-5

; ---------------------------------------------------------------------------
; Logo lines (6 rows, 33 chars each — centered at col 23 for 80-col screen)
; ---------------------------------------------------------------------------
splash_logo0: db " _   __ ___________ ___  _____ ", 0
splash_logo1: db "| | / //  ___|  _  \  _  \  ___|", 0
splash_logo2: db "| |/ / \ `--. | | | | | | \ `--.  ", 0
splash_logo3: db "|    \  `--. \| | | | | |  `--. \ ", 0
splash_logo4: db "| |\  \/\__/ // |/ /\ \_/ /\__/ /", 0
splash_logo5: db "\_| \_/\____/ |___/  \___/\____/  ", 0

; ---------------------------------------------------------------------------
; Fixed strings
; ---------------------------------------------------------------------------
splash_title:    db "  KSDOS v2.0  -  Kernel Soft Disk Operating System  ", 0
splash_subtitle: db "Kernel Soft Disk Operating System", 0
splash_ver:      db "Version 2.0  |  Build 2024  |  16-bit Real Mode x86", 0
splash_copy:     db "Copyright (c) 2024 KSDOS Project. All rights reserved.", 0
splash_botbar:   db " KSDOS v2.0  |  Loading...  |  Please wait...       ", 0

; Loading stage messages
splash_msg0: db "Initializing system...", 0
splash_msg1: db "Loading FAT filesystem tables...", 0
splash_msg2: db "Mounting root directory...", 0
splash_msg3: db "Loading disk subsystem...", 0
splash_msg4: db "Initializing device drivers...", 0
splash_msg5: db "System ready!                  ", 0

; Bar characters
splash_bar_l:  db "[", 0
splash_bar_r:  db "]", 0
splash_bar_x:  db 219, 0    ; full block char (CP437)
splash_bar_sp: db 176, 0    ; light shade (empty portion)

; Percent strings for each stage
splash_pct0: db "  0%", 0
splash_pct1: db " 20%", 0
splash_pct2: db " 40%", 0
splash_pct3: db " 60%", 0
splash_pct4: db " 80%", 0
splash_pct5: db "100%", 0

; ============================================================
; vga_fill_screen: fill entire screen with space + given attribute
; Input: BL = attribute byte
; ============================================================
vga_fill_screen:
    push ax
    push cx
    push di
    push es
    mov ax, VGA_SEG
    mov es, ax
    xor di, di
    mov cx, SCREEN_COLS * SCREEN_ROWS
    mov ah, bl
    mov al, ' '
.floop:
    mov es:[di],   al
    mov es:[di+1], ah
    add di, 2
    dec cx
    jnz .floop
    pop es
    pop di
    pop cx
    pop ax
    ret

; ============================================================
; vga_fill_row: fill one row with char AL and attribute BL
; Input: DH = row, AL = char, BL = attribute
; ============================================================
vga_fill_row:
    push ax
    push bx
    push cx
    push di
    push es
    mov bx, ax              ; save char in BL slot temp
    mov ax, VGA_SEG
    mov es, ax
    xor ax, ax
    mov al, dh
    mov cx, 160
    mul cx
    mov di, ax              ; di = row * 160
    mov ah, bl              ; attribute
    mov al, bh              ; char (saved from BH via original BX=char)
    ; Actually redo: BL=attr was overwritten. Let me use stack
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ; Rebuild cleanly
    push ax
    push bx
    push cx
    push di
    push es
    push ax                 ; save char (AL)
    push bx                 ; save attr (BL)
    mov ax, VGA_SEG
    mov es, ax
    pop bx                  ; restore attr -> BL
    pop ax                  ; restore char -> AL
    push ax
    xor ax, ax
    mov al, dh
    mov cx, 160
    mul cx
    mov di, ax
    pop ax                  ; char back in AL
    mov ah, bl              ; attr in AH
    mov cx, SCREEN_COLS
.frloop:
    mov es:[di],   al
    mov es:[di+1], ah
    add di, 2
    dec cx
    jnz .frloop
    pop es
    pop di
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; vga_write_at: write null-terminated string at (row, col) with attribute
; Input: DH = row, DL = col, BL = attribute, SI = string pointer
; Clobbers nothing (all saved/restored)
; ============================================================
vga_write_at:
    push ax
    push cx
    push di
    push es
    mov ax, VGA_SEG
    mov es, ax
    ; offset = (row * 80 + col) * 2
    xor ax, ax
    mov al, dh
    mov cx, 160
    mul cx              ; ax = row * 160
    mov di, ax
    xor ax, ax
    mov al, dl
    shl ax, 1
    add di, ax          ; di = row*160 + col*2
    mov ah, bl          ; attribute in AH
.waloop:
    lodsb
    test al, al
    jz .wadone
    mov es:[di],   al
    mov es:[di+1], ah
    add di, 2
    jmp .waloop
.wadone:
    pop es
    pop di
    pop cx
    pop ax
    ret

; ============================================================
; vga_write_centered: write string centered on given row
; Input: DH = row, BL = attribute, SI = string pointer
; ============================================================
vga_write_centered:
    push ax
    push cx
    push dx
    push si
    ; measure string length
    push si
    xor cx, cx
.cwclen:
    lodsb
    test al, al
    jz .cwcgot
    inc cx
    jmp .cwclen
.cwcgot:
    pop si
    ; DL = (80 - len) / 2
    mov ax, SCREEN_COLS
    sub ax, cx
    shr ax, 1
    mov dl, al
    call vga_write_at
    pop si
    pop dx
    pop cx
    pop ax
    ret

; ============================================================
; splash_draw_full: draw entire boot screen from scratch
; ============================================================
splash_draw_full:
    push ax
    push bx
    push cx
    push dx
    push si

    ; 1. Fill entire screen with blue background
    mov bl, ATTR_FILL
    call vga_fill_screen

    ; 2. Top title bar (row 0) — white-on-black bar spanning full width
    mov dh, 0
    mov bl, ATTR_TOPBAR
    mov si, splash_title
    mov dl, 0
    call vga_write_at

    ; 3. ASCII art logo — rows 2..7, starting col 23
    mov si, splash_logo0
    mov dh, 2
    mov dl, 23
    mov bl, ATTR_LOGO
    call vga_write_at

    mov si, splash_logo1
    mov dh, 3
    mov dl, 23
    call vga_write_at

    mov si, splash_logo2
    mov dh, 4
    mov dl, 23
    call vga_write_at

    mov si, splash_logo3
    mov dh, 5
    mov dl, 23
    call vga_write_at

    mov si, splash_logo4
    mov dh, 6
    mov dl, 23
    call vga_write_at

    mov si, splash_logo5
    mov dh, 7
    mov dl, 23
    call vga_write_at

    ; 4. Subtitle (row 9)
    mov dh, 9
    mov bl, ATTR_SUBTITLE
    mov si, splash_subtitle
    call vga_write_centered

    ; 5. Version string (row 10)
    mov dh, 10
    mov bl, ATTR_VERSION
    mov si, splash_ver
    call vga_write_centered

    ; 6. Copyright (row 11)
    mov dh, 11
    mov bl, ATTR_STATUS
    mov si, splash_copy
    call vga_write_centered

    ; 7. "Loading:" label (row 14)
    mov dh, 14
    mov dl, 2
    mov bl, ATTR_VERSION
    mov si, splash_lbl_loading
    call vga_write_at

    ; 8. Progress bar frame (row 15)
    ;    [<58 chars>] XX%  starting col 2
    mov dh, 15
    mov dl, 2
    mov bl, ATTR_BAR_BORDER
    mov si, splash_bar_l
    call vga_write_at
    ; Empty bar body
    mov cx, 58
    mov bl, ATTR_BAR_EMPTY
.empty_bar:
    mov si, splash_bar_sp
    push dx
    mov dl, 0           ; will be set per char below - use loop with di
    pop dx
    dec cx
    ; actually just draw all empty first - will be redrawn on update
    jnz .empty_bar
    ; closing bracket and percent
    mov dh, 15
    mov dl, 61
    mov bl, ATTR_BAR_BORDER
    mov si, splash_bar_r
    call vga_write_at
    mov dl, 63
    mov bl, ATTR_VERSION
    mov si, splash_pct0
    call vga_write_at

    ; 9. Status message (row 16)
    mov dh, 16
    mov dl, 2
    mov bl, ATTR_STATUS
    mov si, splash_msg0
    call vga_write_at

    ; 10. Bottom status bar (row 24)
    mov dh, 24
    mov dl, 0
    mov bl, ATTR_BOTBAR
    mov si, splash_botbar
    call vga_write_at

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

splash_lbl_loading: db "Loading system components:", 0

; ============================================================
; splash_draw_bar: draw the progress bar fill for stage AL (0-5)
; Input: AL = stage (0=0%, 1=20%, 2=40%, 3=60%, 4=80%, 5=100%)
; ============================================================
splash_draw_bar:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov bl, al          ; save stage in BL

    ; filled_cols = stage * 58 / 5  (bar is 58 chars wide)
    ; stage 0->0, 1->11, 2->23, 3->34, 4->46, 5->58
    mov al, bl
    xor ah, ah
    mov cx, 58
    mul cx              ; ax = stage * 58
    mov cx, 5
    xor dx, dx
    div cx              ; ax = filled count, dx = remainder
    mov cx, ax          ; CX = filled cols

    ; draw filled portion (char 219 bright green on green)
    mov ax, VGA_SEG
    mov es, ax
    ; offset for row 15, col 3 = (15*80+3)*2 = (1200+3)*2 = 2406
    mov di, (15 * 160) + (3 * 2)
    mov ah, ATTR_BAR_FILL
    mov al, 219         ; full block
    push cx
.fill_loop:
    test cx, cx
    jz .fill_done
    mov es:[di],   al
    mov es:[di+1], ah
    add di, 2
    dec cx
    jmp .fill_loop
.fill_done:
    pop cx

    ; draw empty portion
    mov ax, 58
    sub ax, cx          ; AX = empty cols
    mov cx, ax
    mov ah, ATTR_BAR_EMPTY
    mov al, 176         ; light shade
.empty_loop:
    test cx, cx
    jz .empty_done
    mov es:[di],   al
    mov es:[di+1], ah
    add di, 2
    dec cx
    jmp .empty_loop
.empty_done:

    ; update percent display
    mov al, bl
    mov dh, 15
    mov dl, 63
    mov bl, ATTR_VERSION
    cmp al, 0
    je .pct0
    cmp al, 1
    je .pct1
    cmp al, 2
    je .pct2
    cmp al, 3
    je .pct3
    cmp al, 4
    je .pct4
    mov si, splash_pct5
    jmp .pct_draw
.pct0: mov si, splash_pct0
    jmp .pct_draw
.pct1: mov si, splash_pct1
    jmp .pct_draw
.pct2: mov si, splash_pct2
    jmp .pct_draw
.pct3: mov si, splash_pct3
    jmp .pct_draw
.pct4: mov si, splash_pct4
.pct_draw:
    call vga_write_at

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; splash_draw_status: write status message for stage AL
; Input: AL = stage (0-5)
; ============================================================
splash_draw_status:
    push ax
    push bx
    push dx
    push si
    mov dh, 16
    mov dl, 2
    mov bl, ATTR_STATUS
    cmp al, 0
    je .s0
    cmp al, 1
    je .s1
    cmp al, 2
    je .s2
    cmp al, 3
    je .s3
    cmp al, 4
    je .s4
    mov si, splash_msg5
    jmp .sdraw
.s0: mov si, splash_msg0
    jmp .sdraw
.s1: mov si, splash_msg1
    jmp .sdraw
.s2: mov si, splash_msg2
    jmp .sdraw
.s3: mov si, splash_msg3
    jmp .sdraw
.s4: mov si, splash_msg4
.sdraw:
    call vga_write_at
    pop si
    pop dx
    pop bx
    pop ax
    ret

; ============================================================
; splash_init: Initialize and display the boot splash screen
; Called once at kernel startup (after video_init_text_mode)
; ============================================================
splash_init:
    push ax
    push si
    mov byte [splash_stage], 0
    call splash_draw_full
    ; Draw initial bar at 0%
    mov al, 0
    call splash_draw_bar
    call splash_draw_status
    pop si
    pop ax
    ret

; ============================================================
; splash_update: Advance to stage AL (1-4) and refresh display
; Input: AL = stage number (1=20%, 2=40%, 3=60%, 4=80%)
; ============================================================
splash_update:
    push ax
    push bx
    push si
    mov [splash_stage], al
    call splash_draw_bar
    call splash_draw_status
    ; Small delay so user can see each step (BIOS-timed, not a raw
    ; CPU-cycle busy loop - see splash_delay_ms below for why)
    mov bx, 150
    call splash_delay_ms
    pop si
    pop bx
    pop ax
    ret

; ============================================================
; splash_complete: Show 100% complete state
; ============================================================
splash_complete:
    push ax
    push bx
    push dx
    push si
    mov byte [splash_stage], 5
    mov al, 5
    call splash_draw_bar
    call splash_draw_status
    ; Update bottom bar with "Ready" message
    mov dh, 24
    mov dl, 0
    mov bl, ATTR_BOTBAR
    mov si, splash_ready_bar
    call vga_write_at
    ; Short pause before shell (BIOS-timed, see splash_delay_ms)
    mov bx, 400
    call splash_delay_ms
    pop si
    pop dx
    pop bx
    pop ax
    ret

splash_ready_bar: db " KSDOS v2.0  |  System Ready  |  Starting shell...  ", 0

; ============================================================
; splash_delay_ms: wait BX milliseconds via BIOS INT 15h AH=86h
; (same mechanism as music.asm's spk_delay_ms). A raw CPU-cycle-count
; busy loop was used here previously, tuned for real 8086-class speed;
; under slow/interpreted emulation (no KVM, or a mobile emulator app)
; that made the splash screen appear to hang for minutes instead of
; pausing for a moment, since the same fixed instruction count takes
; wildly different wall-clock time depending on host emulation speed.
; A BIOS time-of-day wait is bounded by real elapsed time instead.
; ============================================================
splash_delay_ms:
    push ax
    push cx
    push dx
    xor dx, dx
    mov ax, bx
    mov cx, 1000
    mul cx              ; DX:AX = microseconds
    mov cx, dx          ; high word
    mov dx, ax          ; low word
    mov ah, 0x86
    int 0x15
    pop dx
    pop cx
    pop ax
    ret
