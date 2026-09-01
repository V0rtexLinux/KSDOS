; =============================================================================
; KSDOS - FAT12 Boot Sector (512 bytes)
; 16-bit Real Mode
; Loads KSDOS.SYS from FAT12 filesystem into memory at 0x1000:0x0000
; =============================================================================
BITS 16
ORG 0x7C00

; =============================================================================
; FAT12 BIOS Parameter Block (BPB)
; NOTE: Values here must match mkimage.pl and be consistent
; =============================================================================
    jmp short boot_code
    nop

    ; BPB (offset 0x03)
OEM:            db "KSDOS1.0"   ; 0x03  8 bytes
BPS:            dw 512          ; 0x0B  bytes per sector
SPC:            db 1            ; 0x0D  sectors per cluster
RSC:            dw 1            ; 0x0E  reserved sectors
FATCNT:         db 2            ; 0x10  number of FATs
ROOTENT:        dw 224          ; 0x11  root directory entries
TOTSEC:         dw 2880         ; 0x13  total sectors
MEDIA:          db 0xF0         ; 0x15  media descriptor
SPF:            dw 9            ; 0x16  sectors per FAT
SPT:            dw 18           ; 0x18  sectors per track
HEADS:          dw 2            ; 0x1A  number of heads
HIDSEC:         dd 0            ; 0x1C  hidden sectors
TOTSEC32:       dd 0            ; 0x20  total sectors (32-bit)
DRVNUM:         db 0            ; 0x24  drive number
RSVD:           db 0            ; 0x25
BOOTSIG:        db 0x29         ; 0x26
VOLID:          dd 0x4B534453   ; 0x27
VOLLBL:         db "KSDOS      "; 0x2B  11 bytes
FSTYPE:         db "FAT12   "   ; 0x36  8 bytes

; =============================================================================
; Boot code (starts at offset 0x3E)
;
; Two BIOS/QEMU floppy quirks were found and fixed here (see git history for
; the full diagnosis):
;   1. The INT 13h AH=42h (EDD) failure check used to run *after* an
;      `add sp,16` that stack-cleanup instruction clobbers CF, so a failed
;      EDD call was always misread as success and the CHS fallback never
;      ran, silently leaving destination buffers unfilled.
;   2. Once EDD is (correctly) detected as unsupported on this floppy, many
;      chained single-sector INT 13h AH=02h CHS reads in a row eventually
;      hang the emulated floppy controller. Fewer, larger reads (one BIOS
;      call per track instead of one per sector) avoid it, so rd_sectors
;      now batches a whole track per call, and the kernel is loaded with a
;      single contiguous read sized from its directory entry instead of
;      walking the FAT12 chain one cluster/sector at a time.
; =============================================================================
boot_code:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7BFE
    sti

    mov [DRVNUM], dl        ; save boot drive

    ; Query actual drive geometry (INT 13h AH=08h) so the CHS fallback's
    ; track math lines up with what the BIOS/controller actually expects.
    mov ah, 0x08
    int 0x13
    jc .geom_done            ; if unsupported, keep BPB defaults
    and cl, 0x3F             ; CL bits 5-0 = sectors per track (CH holds
                              ; the low byte of max cylinder here, NOT 0 -
                              ; must not leak into SPT below)
    movzx ax, cl
    mov [SPT], ax
    movzx ax, dh             ; DH = max head (0-based)
    inc ax
    mov [HEADS], ax
.geom_done:

    ; Print loading message
    mov si, msg_load
    call prints

    ; --- Load Root Directory into 0xA400 (sector 19, 14 sectors) ---
    ; Root dir start = reserved(1) + fatcount(2)*spf(9) = 19
    ; (FAT1 itself is never needed here: KSDOS.SYS is always written as one
    ; contiguous run by mkimage.pl, so no FAT12 chain walk is required, and
    ; the kernel re-reads its own FAT copy into FAT_BUF once it is running.)
    mov ax, 19
    mov cx, 14
    mov bx, 0xA400
    call rd_sectors

    ; --- Search root directory for "KSDOS   SYS" ---
    mov di, 0xA400
    mov cx, 224
.search:
    cmp byte [di], 0x00     ; end of directory
    je .notfound
    cmp byte [di], 0xE5     ; deleted entry
    je .next
    test byte [di+11], 0x08 ; volume label attribute?
    jnz .next
    ; Compare 11-byte name
    push cx
    push di
    push si
    mov si, kern11
    mov cx, 11
    repe cmpsb
    pop si
    pop di
    pop cx
    je .found
.next:
    add di, 32
    dec cx
    jnz .search
.notfound:
    mov si, msg_nf
    call prints
    jmp halt

.found:
    ; DI = start of directory entry.
    ; Cluster (offset 26) -> starting LBA; file size (offset 28, low word)
    ; -> sector count. The whole file is read in one go (mkimage.pl always
    ; allocates it as a single contiguous run, and MAX_FILE_DATA there caps
    ; it well under 64KB, so it can never wrap the 0x1000 segment).
    mov ax, [di+26]
    sub ax, 2
    add ax, 33               ; AX = starting LBA
    mov cx, [di+28]          ; file size (low word)
    add cx, 511
    shr cx, 9                ; CX = sector count, rounded up

    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    call rd_sectors          ; reads the whole kernel into 0x1000:0x0000

    ; Jump to kernel
    mov dl, [DRVNUM]
    jmp 0x1000:0x0000

halt:
    cli
    hlt
    jmp halt

; =============================================================================
; rd_sectors: Read CX sectors starting at LBA AX into ES:BX
;   Tries INT 13h AH=42h (EDD/LBA) for the whole request in one call first;
;   falls back to AH=02h (CHS), batching as many sectors as fit on the
;   current track per BIOS call (never crosses a track boundary in a
;   single call). Preserves ES; clobbers AX/BX/CX/DX/DI/SI internally but
;   restores them via the save/restore pair below.
; =============================================================================
rd_sectors:
    push ax
    push bx
    push cx
    push dx
    push di
    push si

.rs_loop:
    test cx, cx
    jz .rs_done

    mov [_rs_lba], ax

    ; Once EDD has failed once, it will fail for every future call on this
    ; drive too (it's a per-drive capability, not per-request) - skip
    ; straight to CHS instead of burning an INT 13h call finding that out
    ; again. Every INT 13h call, EDD attempts included, was found to count
    ; against a small budget before the emulated floppy controller hangs.
    cmp byte [_rs_no_edd], 0
    jne .chs_fallback

    ; --- Try EDD for the entire remaining request in one DAP call ---
    push word 0              ; LBA bits 48-63
    push word 0              ; LBA bits 32-47
    push word 0              ; LBA bits 16-31
    push ax                  ; LBA bits 0-15
    push es                  ; transfer buffer segment
    push bx                  ; transfer buffer offset
    push cx                  ; sectors to transfer
    push word 0x0010         ; packet size = 16, reserved = 0

    mov ah, 0x42
    mov dl, [DRVNUM]
    mov si, sp
    int 0x13
    jc .edd_failed            ; check CF *before* it gets clobbered below
    add sp, 16
    jmp .rs_done              ; EDD transferred the whole request
.edd_failed:
    add sp, 16                ; discard the DAP (SP was never adjusted above)
    mov byte [_rs_no_edd], 1

.chs_fallback:
    ; --- CHS fallback: batch up to the rest of the current track ---
    mov ax, [_rs_lba]
    xor dx, dx
    mov di, [SPT]
    div di                    ; ax = track index, dx = sector (0-based)
    mov si, [SPT]
    sub si, dx                ; si = sectors left on this track
    cmp si, cx
    jbe .batch_ok
    mov si, cx                ; clamp to what's actually left to transfer
.batch_ok:
    mov [_rs_batch], si
    inc dx
    mov cl, dl                ; CL = starting sector (1-based)

    xor dx, dx
    mov di, [HEADS]
    div di                    ; ax = cylinder, dx = head
    mov dh, dl
    mov ch, al

    mov ah, 0x02
    mov al, [_rs_batch]
    mov dl, [DRVNUM]
    int 0x13
    jc .rs_err

    ; Advance LBA/buffer/remaining-count by however many sectors were read
    mov ax, [_rs_batch]
    mov si, ax
    shl si, 9                 ; si = batch * 512
    add bx, si
    mov ax, [_rs_lba]
    add ax, [_rs_batch]
    sub cx, [_rs_batch]
    jmp .rs_loop

.rs_err:
    mov si, msg_err
    call prints
    jmp halt

.rs_done:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; prints: Print null-terminated string at DS:SI via INT 10h TTY
; =============================================================================
prints:
    push ax
    push bx
.ps_lp:
    lodsb
    test al, al
    jz .ps_done
    mov ah, 0x0E
    mov bx, 7
    int 0x10
    jmp .ps_lp
.ps_done:
    pop bx
    pop ax
    ret

; =============================================================================
; Data
; =============================================================================
kern11:     db "KSDOS   SYS"   ; 8+3 name as stored in FAT12 directory
_rs_lba:    dw 0               ; rd_sectors scratch: current batch LBA
_rs_batch:  dw 0               ; rd_sectors scratch: sectors in this batch
_rs_no_edd: db 0                ; set once EDD is known unsupported on this drive

msg_load:   db "KSDOS v2.0...", 13, 10, 0
msg_nf:     db "KSDOS.SYS not found!", 13, 10, 0
msg_err:    db "Disk error!", 13, 10, 0

; =============================================================================
; Padding + Boot signature (must be last 2 bytes at offset 510/511)
; =============================================================================
    %if 510 - ($ - $$) > 0
        times 510 - ($ - $$) db 0
    %endif
    dw 0xAA55
