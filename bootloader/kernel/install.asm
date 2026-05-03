; =============================================================================
; install.asm - KSDOS Full Disk Installation Routine
; Copies ALL sectors of the KSDOS disk image to internal SSD/HD
; 16-bit real mode BIOS disk operations
;
; The previous version only copied 1 sector (the MBR), which caused
; "KSDOS.SYS not found" on boot because the FAT tables, root directory,
; and kernel data were never written to the target drive.
;
; This version copies all TOTAL_INSTALL_SECS sectors (2880 = 1.44MB) from
; the source boot drive to the target hard disk, making it fully bootable.
; =============================================================================

; ---- Installation constants ----
INSTALL_BUFFER      equ 0x8000      ; Temporary single-sector buffer (512 bytes)
TOTAL_INSTALL_SECS  equ 2880        ; Full 1.44MB floppy = 2880 sectors
INSTALL_SUCCESS     equ 0x00
INSTALL_ERROR       equ 0x01

; ---- Strings ----
install_s_start:    db 0x0A, "KSDOS Disk Installer", 0x0A
                    db "====================", 0x0A, 0
install_s_reading:  db "Copying sectors to disk... ", 0
install_s_done_ln:  db 0x0A, 0
install_s_dot:      db ".", 0
install_s_success:  db 0x0A, "Installation complete! Remove disk and reboot.", 0x0A, 0
install_s_error:    db 0x0A, "ERROR: Installation failed at sector ", 0
install_s_retry:    db "Retrying... ", 0
install_s_verify:   db "Verifying... ", 0
install_s_vok:      db "OK", 0x0A, 0
install_s_vfail:    db "FAIL", 0x0A, 0
install_s_progress: db 0x0D, "Progress: ", 0

; ---- State ----
install_cur_sec:    dw 0            ; current sector being copied
install_src_drive:  db 0            ; source drive (saved from DL on entry)
install_lba_tmp:    dw 0            ; saved LBA for CHS fallback

; ============================================================
; install_to_hd: Copy entire disk image to internal HD (0x80)
;
; Reads each sector from the source floppy/USB (drive in DL at call)
; and writes it to the internal HD (drive 0x80), sector by sector.
;
; Input:  DL = source drive number (from boot: usually 0x00 or removable)
; Returns: CF=0 on success, CF=1 on error
; ============================================================
install_to_hd:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Save source drive
    mov [install_src_drive], dl

    ; Print header
    mov si, install_s_start
    call vid_print

    mov si, install_s_reading
    call vid_print

    ; Loop over all TOTAL_INSTALL_SECS sectors
    mov word [install_cur_sec], 0

.copy_loop:
    mov ax, [install_cur_sec]
    cmp ax, TOTAL_INSTALL_SECS
    jae .copy_done

    ; --- Read sector AX from source drive ---
    push ax
    mov dl, [install_src_drive]
    call install_read_sector    ; AX=LBA, DL=drive -> buf at INSTALL_BUFFER
    pop ax
    jc .read_error

    ; --- Write sector AX to target HD (0x80) ---
    push ax
    mov dl, 0x80
    call install_write_sector   ; AX=LBA, DL=drive <- buf at INSTALL_BUFFER
    pop ax
    jc .write_error

    ; Progress dot every 64 sectors (~32KB)
    test ax, 0x003F
    jnz .no_dot
    mov si, install_s_dot
    call vid_print
.no_dot:

    inc word [install_cur_sec]
    jmp .copy_loop

.copy_done:
    mov si, install_s_success
    call vid_print
    clc
    jmp .inst_done

.read_error:
    mov si, install_s_error
    call vid_print
    stc
    jmp .inst_done

.write_error:
    mov si, install_s_error
    call vid_print
    stc

.inst_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; install_to_ssd: Alias — identical to install_to_hd.
; SSDs appear as drive 0x80 just like HDDs under BIOS.
; ============================================================
install_to_ssd:
    jmp install_to_hd

; ============================================================
; install_read_sector: Read one 512-byte sector into INSTALL_BUFFER
; Input:  AX = LBA sector number, DL = drive number
; Output: CF=0 success, CF=1 error
; Buffer: flat address INSTALL_BUFFER (0x0000:0x8000)
; ============================================================
install_read_sector:
    push ax
    push bx
    push cx
    push dx
    push si

    ; Save LBA for CHS fallback
    mov [install_lba_tmp], ax

    ; Try EDD (INT 13h AH=42h) first
    push word 0             ; LBA bits 48-63
    push word 0             ; LBA bits 32-47
    push word 0             ; LBA bits 16-31
    push ax                 ; LBA bits 0-15
    push word 0x0000        ; buffer segment (DS=0)
    push word INSTALL_BUFFER; buffer offset
    push word 1             ; sectors to transfer
    push word 0x0010        ; packet size=16, reserved=0
    mov ah, 0x42
    mov si, sp
    int 0x13
    add sp, 16
    jnc .rs_done

    ; EDD failed — fall back to CHS using saved LBA
    mov ax, [install_lba_tmp]
    cmp dl, 0x80
    jb .chs_floppy

    ; HD/SSD CHS (geometry varies — use 63 SPT, 255 heads)
    xor dx, dx
    mov bx, 63
    div bx              ; AX=track, DX=sector-1
    inc dx
    mov cl, dl          ; CL = sector (1-based)
    xor dx, dx
    mov bx, 255
    div bx              ; AX=cylinder, DX=head
    mov dh, dl          ; DH = head
    mov ch, al          ; CH = cylinder (low 8)
    shl ah, 6
    or  cl, ah          ; CL bits 7:6 = cylinder high
    jmp .chs_read

.chs_floppy:
    ; Floppy: 18 SPT, 2 heads
    xor dx, dx
    mov bx, 18
    div bx              ; AX=track, DX=sector-1
    inc dx
    mov cl, dl          ; sector
    xor dx, dx
    mov bx, 2
    div bx              ; AX=cylinder, DX=head
    mov dh, dl
    mov ch, al

.chs_read:
    mov ax, 0x0201      ; AH=02 read, AL=1 sector
    mov bx, INSTALL_BUFFER
    push es
    push ds
    pop es
    int 0x13
    pop es
    jc .rs_err
    jmp .rs_done

.rs_err:
    ; Set CF
    stc
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.rs_done:
    clc
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; install_write_sector: Write INSTALL_BUFFER to one sector on target drive
; Input:  AX = LBA sector number, DL = drive number (0x80 = first HD/SSD)
; Output: CF=0 success, CF=1 error
; ============================================================
install_write_sector:
    push ax
    push bx
    push cx
    push dx
    push si

    ; Save LBA for CHS fallback
    mov [install_lba_tmp], ax

    ; Try EDD write (INT 13h AH=43h)
    push word 0             ; LBA bits 48-63
    push word 0             ; LBA bits 32-47
    push word 0             ; LBA bits 16-31
    push ax                 ; LBA bits 0-15
    push word 0x0000        ; buffer segment
    push word INSTALL_BUFFER; buffer offset
    push word 1             ; sectors
    push word 0x0010        ; packet size=16
    mov ah, 0x43
    mov al, 0x00            ; write without verify
    mov si, sp
    int 0x13
    add sp, 16
    jnc .ws_done

    ; EDD write failed — CHS fallback using saved LBA
    mov ax, [install_lba_tmp]
    cmp dl, 0x80
    jb .whs_floppy

    xor dx, dx
    mov bx, 63
    div bx
    inc dx
    mov cl, dl
    xor dx, dx
    mov bx, 255
    div bx
    mov dh, dl
    mov ch, al
    shl ah, 6
    or  cl, ah
    jmp .whs_write

.whs_floppy:
    xor dx, dx
    mov bx, 18
    div bx
    inc dx
    mov cl, dl
    xor dx, dx
    mov bx, 2
    div bx
    mov dh, dl
    mov ch, al

.whs_write:
    mov ax, 0x0301      ; AH=03 write, AL=1 sector
    mov bx, INSTALL_BUFFER
    push es
    push ds
    pop es
    int 0x13
    pop es
    jc .ws_err

.ws_done:
    clc
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.ws_err:
    stc
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; install_with_retry: Install with up to 3 retries on error
; Input:  DL = source drive
; Returns: CF=0 success, CF=1 failure
; ============================================================
install_with_retry:
    push cx
    push si
    mov cx, 3
.retry_loop:
    call install_to_hd
    jnc .ir_success
    dec cx
    jz  .ir_failed
    mov si, install_s_retry
    call vid_print
    call install_short_delay
    jmp .retry_loop
.ir_success:
    clc
    jmp .ir_done
.ir_failed:
    stc
.ir_done:
    pop si
    pop cx
    ret

; ============================================================
; install_verify: Read back first 16 sectors and compare to source
; Input: DL = source drive
; Returns: CF=0 if match, CF=1 if mismatch
; ============================================================
install_verify:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov si, install_s_verify
    call vid_print

    push dx                 ; save source drive
    mov cx, 16              ; verify first 16 sectors
    xor ax, ax              ; start at sector 0

.vloop:
    ; Read from source into INSTALL_BUFFER
    mov dl, [install_src_drive]
    call install_read_sector
    jc .vfail

    ; Save copy to 0x0000:0x9000 (just above install buffer)
    push es
    push ds
    pop es
    mov si, INSTALL_BUFFER
    mov di, 0x9000
    mov bx, 256
    rep movsw           ; copy 512 bytes
    pop es

    ; Read same sector from HD
    pop dx
    push dx
    mov dl, 0x80
    call install_read_sector
    jc .vfail

    ; Compare
    push es
    push ds
    pop es
    mov si, INSTALL_BUFFER
    mov di, 0x9000
    mov bx, 256         ; compare 512 bytes (256 words)
    xor cx, cx
.vcmp:
    mov dx, [es:si]
    cmp dx, [es:di]
    jne .vfail_cmp
    add si, 2
    add di, 2
    dec bx
    jnz .vcmp
    pop es

    inc ax
    dec cx
    jnz .vloop

    ; All matched
    pop dx
    mov si, install_s_vok
    call vid_print
    clc
    jmp .vdone

.vfail_cmp:
    pop es
.vfail:
    pop dx
    mov si, install_s_vfail
    call vid_print
    stc

.vdone:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; install_short_delay: brief busy-wait delay for retry
; ============================================================
install_short_delay:
    push cx
    push dx
    mov cx, 0x00FF
    mov dx, 0xFFFF
.dly:
    dec dx
    jnz .dly
    dec cx
    jnz .dly
    pop dx
    pop cx
    ret
