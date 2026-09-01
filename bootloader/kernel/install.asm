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
;
; Two bugs were found and fixed here (mirroring the boot sector's own
; history - see bootsect.asm):
;   1. install_read_sector/install_write_sector checked the EDD carry flag
;      *after* `add sp,16`, which clobbers CF, so a failed EDD call was
;      always misread as success.
;   2. Copying sector-by-sector (2880 read+write BIOS call pairs) was found
;      to eventually hang the emulated floppy controller on some BIOS/QEMU
;      combinations. Both routines now batch as many sectors as fit on the
;      current CHS track per BIOS call.
; =============================================================================

; ---- Installation constants ----
INSTALL_BUFFER      equ 0x8000      ; Batch transfer buffer (up to 18*512 bytes)
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
install_batch:      dw 0            ; sectors in the current batch
install_no_edd:     db 0            ; set once EDD is known unsupported
install_force_chs:  db 0            ; set by install_set_force_chs to skip EDD entirely

; ============================================================
; install_to_hd: Copy entire disk image to internal HD (0x80)
;
; Reads a batch of sectors from the source floppy/USB (drive in DL at
; call) and writes the same batch to the internal HD (drive 0x80).
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
    cmp byte [install_force_chs], 0
    je .reset_edd_flag
    mov byte [install_no_edd], 1
    jmp .edd_flag_set
.reset_edd_flag:
    mov byte [install_no_edd], 0
.edd_flag_set:

    ; Print header
    mov si, install_s_start
    call vid_print

    mov si, install_s_reading
    call vid_print

    mov word [install_cur_sec], 0

.copy_loop:
    mov ax, [install_cur_sec]
    cmp ax, TOTAL_INSTALL_SECS
    jae .copy_done

    ; batch size = sectors left on this track, clamped to what remains
    xor dx, dx
    mov bx, 18                  ; assume 18 SPT for batching purposes; the
                                 ; underlying CHS fallback recomputes real
                                 ; geometry per drive type if EDD is absent
    div bx
    mov cx, 18
    sub cx, dx                  ; sectors left on this 18-sector track
    mov bx, TOTAL_INSTALL_SECS
    sub bx, [install_cur_sec]
    cmp cx, bx
    jbe .batch_ok
    mov cx, bx
.batch_ok:
    mov [install_batch], cx

    ; --- Read the batch from the source drive ---
    mov ax, [install_cur_sec]
    mov dl, [install_src_drive]
    mov cx, [install_batch]
    call install_read_batch
    jc .read_error

    ; --- Write the same batch to the target HD (0x80) ---
    mov ax, [install_cur_sec]
    mov dl, 0x80
    mov cx, [install_batch]
    call install_write_batch
    jc .write_error

    mov si, install_s_dot
    call vid_print

    mov ax, [install_batch]
    add [install_cur_sec], ax
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
; install_read_batch: Read CX sectors starting at LBA AX into
; INSTALL_BUFFER (flat address 0x0000:0x8000)
; Input:  AX = starting LBA, CX = sector count (<=18), DL = drive number
; Output: CF=0 success, CF=1 error
; ============================================================
install_read_batch:
    push ax
    push bx
    push cx
    push dx
    push si

    mov [install_lba_tmp], ax
    mov [_irb_batch], cx
    cmp byte [install_no_edd], 0
    jne .chs

    ; Try EDD (INT 13h AH=42h) for the whole batch in one call
    push word 0             ; LBA bits 48-63
    push word 0             ; LBA bits 32-47
    push word 0             ; LBA bits 16-31
    push ax                 ; LBA bits 0-15
    push word 0x0000        ; buffer segment (DS=0)
    push word INSTALL_BUFFER; buffer offset
    push cx                 ; sectors to transfer
    push word 0x0010        ; packet size=16, reserved=0
    mov ah, 0x42
    mov si, sp
    int 0x13
    jc .edd_failed
    add sp, 16
    jmp .rs_done
.edd_failed:
    add sp, 16
    mov byte [install_no_edd], 1

.chs:
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
    mov ah, 0x02
    mov al, [_irb_batch]
    mov bx, INSTALL_BUFFER
    push es
    push ds
    pop es
    int 0x13
    pop es
    jc .rs_err
    jmp .rs_done

.rs_err:
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
_irb_batch: dw 0

; ============================================================
; install_write_batch: Write CX sectors from INSTALL_BUFFER to LBA AX
; Input:  AX = starting LBA, CX = sector count (<=18), DL = drive number
; Output: CF=0 success, CF=1 error
; ============================================================
install_write_batch:
    push ax
    push bx
    push cx
    push dx
    push si

    mov [install_lba_tmp], ax
    mov [_iwb_batch], cx
    cmp byte [install_no_edd], 0
    jne .chs

    ; Try EDD write (INT 13h AH=43h) for the whole batch
    push word 0             ; LBA bits 48-63
    push word 0             ; LBA bits 32-47
    push word 0             ; LBA bits 16-31
    push ax                 ; LBA bits 0-15
    push word 0x0000        ; buffer segment
    push word INSTALL_BUFFER; buffer offset
    push cx                 ; sectors
    push word 0x0010        ; packet size=16
    mov ah, 0x43
    mov al, 0x00            ; write without verify
    mov si, sp
    int 0x13
    jc .edd_wfailed
    add sp, 16
    jmp .ws_done
.edd_wfailed:
    add sp, 16
    mov byte [install_no_edd], 1

.chs:
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
    mov ah, 0x03
    mov al, [_iwb_batch]
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
_iwb_batch: dw 0

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
; install_run: Install using the drive KSDOS actually booted from,
; so overlays (which have no access to the kernel's internal
; boot_drive variable) can trigger a real install without guessing
; a drive number themselves.
; Returns: CF=0 success, CF=1 failure
; ============================================================
install_run:
    push dx
    mov dl, [boot_drive]
    call install_with_retry
    pop dx
    ret

; ============================================================
; install_run_verify: Verify using the boot drive, same reasoning
; as install_run.
; Returns: CF=0 match, CF=1 mismatch
; ============================================================
install_run_verify:
    push dx
    mov dl, [boot_drive]
    call install_verify
    pop dx
    ret

; ============================================================
; install_set_force_chs: AL=0/1, sets/clears the force-CHS-only flag.
; Must be called before install_run to take effect (install_to_hd
; consults this flag itself instead of always resetting it).
; ============================================================
install_set_force_chs:
    mov [install_force_chs], al
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
    mov cx, 16               ; verify first 16 sectors
    xor ax, ax               ; start at sector 0

.vloop:
    ; Read from source into INSTALL_BUFFER
    mov dl, [install_src_drive]
    push cx
    mov cx, 1
    call install_read_batch
    pop cx
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
    push cx
    mov cx, 1
    call install_read_batch
    pop cx
    jc .vfail

    ; Compare
    push es
    push ds
    pop es
    mov si, INSTALL_BUFFER
    mov di, 0x9000
    mov bx, 256         ; compare 512 bytes (256 words)
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
