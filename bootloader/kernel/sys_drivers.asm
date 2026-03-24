; =============================================================================
; sys_drivers.asm — KSDOS Device Driver Subsystem
; Derived from SYSTEM/DEV/ (MS-DOS 4.0 Open Source, NASM port)
;
; Implements:
;   CON   — console I/O with ANSI sequence processing (from SYSTEM/DEV/ANSI/)
;   NUL   — null device (reads EOF, discards writes)
;   CLOCK$— software real-time clock (from SYSTEM/BIOS/MSCLOCK.ASM patterns)
;   AUX   — auxiliary serial port stub (COM1)
;   PRN   — printer device stub (LPT1)
; =============================================================================

%ifndef SYS_DRIVERS_DEFINED
%define SYS_DRIVERS_DEFINED

%include "sys_dossym.inc"
%include "sys_devsym.inc"

; ---------------------------------------------------------------------------
; Driver chain head — NUL device is always first per DOS spec
; (from SYSTEM/DOS/DOSMES.ASM: NUL device is hard-coded into SYSVAR)
; ---------------------------------------------------------------------------

; ============================================================
; NUL Device Driver  (SYSTEM/DEV/ pattern, always first in chain)
; Attribute: 0x8004 (CHR | NUL)
; ============================================================
drv_NUL_header:
    dw  drv_CLOCK_header        ; next device offset (chain)
    dw  0x0000                  ; next device segment (same seg for all)
    dw  DEV_CHR | DEV_NUL       ; attribute
    dw  drv_NUL_strategy        ; strategy entry
    dw  drv_NUL_interrupt       ; interrupt entry
    db  'NUL     '              ; name (8 bytes)

drv_NUL_strategy:
    ret

drv_NUL_interrupt:
    ; All commands on NUL device return status DONE with zero data
    ; Input commands: return 0 bytes, status = DONE | no-data
    ; Output commands: pretend to write, status = DONE
    push bx
    ; BX:AX = request packet pointer (set by strategy routine)
    ; For simplicity, just mark status as done
    ; Real implementation would check [bx+2] for command code
    pop bx
    ret

; ============================================================
; CLOCK$ Device Driver  (from SYSTEM/BIOS/MSCLOCK.ASM patterns)
; Provides system date/time via device read/write
; ============================================================
drv_CLOCK_header:
    dw  drv_CON_header
    dw  0x0000
    dw  DEV_CHR | DEV_CLOCK
    dw  drv_CLOCK_strategy
    dw  drv_CLOCK_interrupt
    db  'CLOCK$  '

drv_CLOCK_strategy:
    mov [_drv_rq_ptr], ax   ; save request packet pointer
    ret

drv_CLOCK_interrupt:
    push ax
    push bx
    push cx
    push dx

    ; Read BIOS real-time clock via INT 1Ah
    ; INT 1Ah AH=02: get RTC time → CH=hours BCD, CL=minutes BCD, DH=seconds BCD
    mov ah, 0x02
    int 0x1A
    jc .clock_no_rtc

    ; Convert BCD to binary
    ; hours
    mov al, ch
    call bcd_to_bin
    mov [_clk_hours], al
    ; minutes
    mov al, cl
    call bcd_to_bin
    mov [_clk_minutes], al
    ; seconds
    mov al, dh
    call bcd_to_bin
    mov [_clk_seconds], al

    ; Get date: INT 1Ah AH=04: get RTC date → CH=century BCD, CL=year BCD, DH=month BCD, DL=day BCD
    mov ah, 0x04
    int 0x1A
    jc .clock_no_date

    mov al, dh
    call bcd_to_bin
    mov [_clk_month], al
    mov al, dl
    call bcd_to_bin
    mov [_clk_day], al
    mov al, cl
    call bcd_to_bin
    mov [_clk_year], ax
    xor ax, ax
    mov al, ch
    call bcd_to_bin
    ; century: 19 or 20
    cmp al, 20
    jne .c19
    add word [_clk_year], 2000
    jmp .clock_no_date
.c19:
    add word [_clk_year], 1900

.clock_no_date:
.clock_no_rtc:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Clock data (updated on each CLOCK$ read)
_clk_hours:     db 0
_clk_minutes:   db 0
_clk_seconds:   db 0
_clk_month:     db 1
_clk_day:       db 1
_clk_year:      dw 2024
_drv_rq_ptr:    dw 0

; BCD to binary: AL=BCD input → AL=binary output
bcd_to_bin:
    push bx
    mov bl, al
    shr al, 4
    mov bh, al
    mov al, 10
    mul bh          ; ax = high_nibble * 10
    and bl, 0x0F
    add al, bl
    pop bx
    ret

; ============================================================
; CON Device Driver with ANSI terminal emulation
; Derived from SYSTEM/DEV/ANSI/ (MSDOS 4.0 ANSI.SYS source)
;
; Supported ANSI sequences:
;   ESC[A       cursor up
;   ESC[B       cursor down
;   ESC[C       cursor right
;   ESC[D       cursor left
;   ESC[H       cursor home (0,0)
;   ESC[f       cursor home (same as H)
;   ESC[y;xH    set cursor position (row y, col x)
;   ESC[2J      erase display
;   ESC[K       erase to end of line
;   ESC[m       reset attributes
;   ESC[nm      set attribute (n = colour code)
;   ESC[s       save cursor position
;   ESC[u       restore cursor position
;   ESC[7m      reverse video
;   ESC[0m      normal video
; ============================================================
drv_CON_header:
    dw  drv_AUX_header
    dw  0x0000
    dw  DEV_ATTR_ANSI
    dw  drv_CON_strategy
    dw  drv_CON_interrupt
    db  'CON     '

drv_CON_strategy:
    ret

drv_CON_interrupt:
    ret

; ANSI state machine state
_ansi_state:    db 0        ; 0=normal, 1=got ESC, 2=got ESC[, 3=collecting params
_ansi_buf:      times 16 db 0
_ansi_blen:     db 0
_ansi_p1:       dw 0        ; first parameter
_ansi_p2:       dw 0        ; second parameter
_ansi_saved_row: db 0       ; saved cursor row
_ansi_saved_col: db 0       ; saved cursor col
_ansi_attr:     db VATTR_NORMAL ; current text attribute

; ============================================================
; ansi_write_char: process one output character through ANSI filter
; Input: AL = character to output
; Preserves all registers
; ============================================================
ansi_write_char:
    push ax
    push bx
    push cx
    push dx

    movzx bx, byte [_ansi_state]
    cmp bx, 0
    je .normal
    cmp bx, 1
    je .got_esc
    cmp bx, 2
    je .got_esc_bracket
    ; State 3: collecting parameters
    jmp .collecting

.normal:
    cmp al, c_ESC
    jne .raw_out
    mov byte [_ansi_state], 1
    jmp .done

.got_esc:
    cmp al, '['
    jne .esc_cancel
    mov byte [_ansi_state], 2
    mov byte [_ansi_blen], 0
    mov word [_ansi_p1], 0
    mov word [_ansi_p2], 0
    jmp .done
.esc_cancel:
    mov byte [_ansi_state], 0
    ; Fall through to output the character
    jmp .raw_out

.got_esc_bracket:
    ; Collecting first digit or command letter
    mov byte [_ansi_state], 3
    jmp .collecting

.collecting:
    cmp al, '0'
    jl .ansi_cmd
    cmp al, '9'
    jg .ansi_cmd
    ; Digit: add to current parameter
    mov bx, [_ansi_p2]
    mov cx, 10
    ; Shift which param we're filling
    movzx cx, byte [_ansi_blen]
    push ax
    mov ax, [_ansi_p1]
    cmp cx, 0       ; already have a ';' ?
    jne .dp2
    ; Filling p1
    mov bx, 10
    mul bx
    pop bx
    movzx bx, bl
    add ax, bx
    mov [_ansi_p1], ax
    jmp .coll_done
.dp2:
    mov ax, [_ansi_p2]
    mov bx, 10
    mul bx
    pop bx
    movzx bx, bl
    add ax, bx
    mov [_ansi_p2], ax
.coll_done:
    jmp .done

.ansi_cmd:
    ; It's a command terminator letter (or ';')
    cmp al, ';'
    jne .not_sep
    inc byte [_ansi_blen]   ; mark "we've seen the separator"
    jmp .done
.not_sep:
    mov byte [_ansi_state], 0
    ; Dispatch on command letter
    cmp al, 'A'
    je .cmd_cup
    cmp al, 'B'
    je .cmd_cdn
    cmp al, 'C'
    je .cmd_cright
    cmp al, 'D'
    je .cmd_cleft
    cmp al, 'H'
    je .cmd_goto
    cmp al, 'f'
    je .cmd_goto
    cmp al, 'J'
    je .cmd_erase
    cmp al, 'K'
    je .cmd_eraseeol
    cmp al, 'm'
    je .cmd_attr
    cmp al, 's'
    je .cmd_save
    cmp al, 'u'
    je .cmd_restore
    ; Unknown sequence — ignore
    jmp .done

.cmd_cup:
    ; Cursor up by p1 (default 1)
    mov cx, [_ansi_p1]
    test cx, cx
    jnz .cup_ok
    mov cx, 1
.cup_ok:
    mov ah, 0x03
    mov bh, 0
    int INT_VIDEO       ; get cursor pos: DH=row, DL=col
    sub dh, cl
    cmp dh, 0
    jge .cup_set
    xor dh, dh
.cup_set:
    mov ah, 0x02
    mov bh, 0
    int INT_VIDEO
    jmp .done

.cmd_cdn:
    mov cx, [_ansi_p1]
    test cx, cx
    jnz .cdn_ok
    mov cx, 1
.cdn_ok:
    mov ah, 0x03
    mov bh, 0
    int INT_VIDEO
    add dh, cl
    cmp dh, VID_ROWS - 1
    jle .cdn_set
    mov dh, VID_ROWS - 1
.cdn_set:
    mov ah, 0x02
    mov bh, 0
    int INT_VIDEO
    jmp .done

.cmd_cright:
    mov cx, [_ansi_p1]
    test cx, cx
    jnz .cr_ok
    mov cx, 1
.cr_ok:
    mov ah, 0x03
    mov bh, 0
    int INT_VIDEO
    add dl, cl
    cmp dl, VID_COLS - 1
    jle .cr_set
    mov dl, VID_COLS - 1
.cr_set:
    mov ah, 0x02
    mov bh, 0
    int INT_VIDEO
    jmp .done

.cmd_cleft:
    mov cx, [_ansi_p1]
    test cx, cx
    jnz .cl_ok
    mov cx, 1
.cl_ok:
    mov ah, 0x03
    mov bh, 0
    int INT_VIDEO
    sub dl, cl
    cmp dl, 0
    jge .cl_set
    xor dl, dl
.cl_set:
    mov ah, 0x02
    mov bh, 0
    int INT_VIDEO
    jmp .done

.cmd_goto:
    ; ESC[y;xH — row = p1-1, col = p2-1 (1-based input)
    mov ax, [_ansi_p1]
    test ax, ax
    jnz .go_r_ok
    mov ax, 1
.go_r_ok:
    dec ax
    mov dh, al              ; row
    mov ax, [_ansi_p2]
    test ax, ax
    jnz .go_c_ok
    mov ax, 1
.go_c_ok:
    dec ax
    mov dl, al              ; col
    mov ah, 0x02
    mov bh, 0
    int INT_VIDEO
    jmp .done

.cmd_erase:
    cmp word [_ansi_p1], 2
    jne .done               ; only support ESC[2J (erase full display)
    ; Clear screen via BIOS scroll
    mov ah, 0x06
    xor al, al              ; clear all lines
    xor cx, cx              ; top-left (0,0)
    mov dh, VID_ROWS - 1
    mov dl, VID_COLS - 1
    mov bh, [_ansi_attr]
    int INT_VIDEO
    ; Home cursor
    mov ah, 0x02
    mov bh, 0
    xor dx, dx
    int INT_VIDEO
    jmp .done

.cmd_eraseeol:
    ; ESC[K — erase from cursor to end of line
    mov ah, 0x03
    mov bh, 0
    int INT_VIDEO           ; get cursor: DH=row, DL=col
    push dx
    mov ah, 0x09
    mov al, ' '
    mov bh, 0
    mov bl, [_ansi_attr]
    mov cx, VID_COLS
    movzx cx, dl
    sub cx, VID_COLS
    neg cx                  ; cx = cols remaining
    int INT_VIDEO
    pop dx
    jmp .done

.cmd_attr:
    ; ESC[nm — set attribute
    mov ax, [_ansi_p1]
    cmp ax, 0
    je .attr_reset
    cmp ax, 1
    je .attr_bright
    cmp ax, 4
    je .attr_underscore
    cmp ax, 5
    je .attr_blink
    cmp ax, 7
    je .attr_reverse
    ; Colour codes 30-37: foreground, 40-47: background
    cmp ax, 30
    jl .done
    cmp ax, 37
    jle .attr_fg
    cmp ax, 40
    jl .done
    cmp ax, 47
    jle .attr_bg
    jmp .done
.attr_reset:
    mov byte [_ansi_attr], VATTR_NORMAL
    jmp .done
.attr_bright:
    or byte [_ansi_attr], 0x08
    jmp .done
.attr_underscore:
    ; Not directly supported in CGA, map to cyan fg
    mov byte [_ansi_attr], VATTR_FG_CYAN
    jmp .done
.attr_blink:
    or byte [_ansi_attr], VATTR_BLINK
    jmp .done
.attr_reverse:
    ; Swap foreground and background nibbles
    mov al, [_ansi_attr]
    mov ah, al
    shr ah, 4
    shl al, 4
    or al, ah
    and al, 0x77        ; clear blink/intensity to avoid artefacts
    mov [_ansi_attr], al
    jmp .done
.attr_fg:
    ; ANSI 30-37 → CGA 0-7
    sub ax, 30
    and byte [_ansi_attr], 0xF0     ; clear current fg
    ; ANSI colour order: black=30, red=31, green=32, yellow=33, blue=34, magenta=35, cyan=36, white=37
    ; CGA order:  0=black, 1=blue, 2=green, 3=cyan, 4=red, 5=magenta, 6=brown, 7=lgrey
    ; Map ANSI→CGA: 0→0, 1→4, 2→2, 3→6, 4→1, 5→5, 6→3, 7→7
    mov bx, ansi_fg_map
    xlat
    or byte [_ansi_attr], al
    jmp .done
.attr_bg:
    sub ax, 40
    and byte [_ansi_attr], 0x0F     ; clear current bg
    mov bx, ansi_fg_map
    xlat
    shl al, 4
    or byte [_ansi_attr], al
    jmp .done

.cmd_save:
    mov ah, 0x03
    mov bh, 0
    int INT_VIDEO
    mov [_ansi_saved_row], dh
    mov [_ansi_saved_col], dl
    jmp .done

.cmd_restore:
    mov dh, [_ansi_saved_row]
    mov dl, [_ansi_saved_col]
    mov ah, 0x02
    mov bh, 0
    int INT_VIDEO
    jmp .done

.raw_out:
    ; Output character directly via BIOS INT 10h
    mov ah, 0x0E
    mov bh, 0
    mov bl, [_ansi_attr]
    int INT_VIDEO

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ANSI colour to CGA colour lookup table
; Index = ANSI colour (0=black,1=red,2=green,3=yellow,4=blue,5=magenta,6=cyan,7=white)
; Value = CGA colour
ansi_fg_map: db 0, 4, 2, 6, 1, 5, 3, 7

; ============================================================
; AUX Device — serial port stub (COM1)
; Derived from SYSTEM/BIOS/MSAUX.ASM patterns
; ============================================================
drv_AUX_header:
    dw  drv_PRN_header
    dw  0x0000
    dw  DEV_CHR
    dw  drv_AUX_strategy
    dw  drv_AUX_interrupt
    db  'AUX     '

drv_AUX_strategy:
    ret

drv_AUX_interrupt:
    ; Minimal: AUX output via BIOS INT 14h
    push ax
    push dx
    mov ah, 0x01            ; INT 14h AH=01: write char to COM1
    xor dx, dx              ; COM1
    int 0x14
    pop dx
    pop ax
    ret

; ============================================================
; PRN Device — printer stub (LPT1)
; Derived from SYSTEM/BIOS/MSLPT.ASM patterns
; ============================================================
drv_PRN_header:
    dw  0xFFFF          ; next device offset: end of chain
    dw  0xFFFF          ; next device segment: end of chain
    dw  DEV_CHR | DEV_OUB
    dw  drv_PRN_strategy
    dw  drv_PRN_interrupt
    db  'PRN     '

drv_PRN_strategy:
    ret

drv_PRN_interrupt:
    ; Minimal: PRN output via BIOS INT 17h
    push ax
    push dx
    mov ah, 0x00            ; INT 17h AH=00: write char to LPT1
    xor dx, dx              ; LPT1
    int 0x17
    pop dx
    pop ax
    ret

; ============================================================
; sys_drivers_init: install device drivers into the system
; Call once during kernel boot
; ============================================================
sys_drivers_init:
    push ax
    push si
    ; Nothing to install in real mode — drivers are compiled in
    ; Just update CLOCK$ with current time on boot
    call drv_CLOCK_interrupt
    pop si
    pop ax
    ret

; ============================================================
; sys_gettime: return current time as string "HH:MM:SS"
; Output: DS:DI = pointer to null-terminated time string
; ============================================================
_sys_time_buf:  db "00:00:00", 0

sys_gettime:
    push ax
    push bx
    push dx

    call drv_CLOCK_interrupt    ; refresh clock data

    mov di, _sys_time_buf

    movzx ax, byte [_clk_hours]
    call byte_to_dec2
    mov byte [di+2], ':'

    movzx ax, byte [_clk_minutes]
    add di, 3
    call byte_to_dec2
    mov byte [di+2], ':'

    movzx ax, byte [_clk_seconds]
    add di, 3
    call byte_to_dec2
    sub di, 6

    mov di, _sys_time_buf

    pop dx
    pop bx
    pop ax
    ret

; ============================================================
; sys_getdate: return current date as string "YYYY-MM-DD"
; Output: DS:DI = pointer to null-terminated date string
; ============================================================
_sys_date_buf:  db "2024-01-01", 0

sys_getdate:
    push ax
    push bx
    push dx

    call drv_CLOCK_interrupt

    mov di, _sys_date_buf

    ; Year (4 digits)
    mov ax, [_clk_year]
    xor dx, dx
    mov bx, 1000
    div bx
    add al, '0'
    mov [di], al
    mov ax, dx
    xor dx, dx
    mov bx, 100
    div bx
    add al, '0'
    mov [di+1], al
    mov ax, dx
    xor dx, dx
    mov bx, 10
    div bx
    add al, '0'
    mov [di+2], al
    add dl, '0'
    mov [di+3], dl

    mov byte [di+4], '-'

    movzx ax, byte [_clk_month]
    add di, 5
    call byte_to_dec2
    mov byte [di+2], '-'

    movzx ax, byte [_clk_day]
    add di, 3
    call byte_to_dec2
    sub di, 8

    mov di, _sys_date_buf
    pop dx
    pop bx
    pop ax
    ret

; byte_to_dec2: convert byte AX (0..99) to 2 ASCII digits at [DI]
byte_to_dec2:
    push ax
    push bx
    push dx
    xor dx, dx
    mov bx, 10
    div bx              ; al=tens, dl=units
    add al, '0'
    mov [di], al
    add dl, '0'
    mov [di+1], dl
    pop dx
    pop bx
    pop ax
    ret

%endif ; SYS_DRIVERS_DEFINED
