; =============================================================================
; sys_devsym.inc — NASM-compatible device driver interface
; Derived from SYSTEM/INC/DEVSYM.INC  (MS-DOS 4.0 Open Source)
; Converted from MASM STRUC to NASM struc for KSDOS kernel
; =============================================================================

%ifndef SYS_DEVSYM_DEFINED
%define SYS_DEVSYM_DEFINED

; ---------------------------------------------------------------------------
; Device Header Structure (SYSDEV)
; Every device driver starts with this 18-byte header
; Derived from SYSTEM/INC/DEVSYM.INC
; ---------------------------------------------------------------------------
struc SYSDEV
    .next_seg   resw 1  ; +0  segment of next device header (0xFFFF = last)
    .next_off   resw 1  ; +2  offset of next device header
    .attribute  resw 1  ; +4  device attribute word (see DEV_ATTR_* below)
    .strategy   resw 1  ; +6  strategy entry point offset
    .interrupt  resw 1  ; +8  interrupt entry point offset
    .name       resb 8  ; +10 device name (8 chars, space-padded)
endstruc               ; = 18 bytes total

; ---------------------------------------------------------------------------
; Device Attribute Bits (SYSDEV.attribute)
; From SYSTEM/INC/DEVSYM.INC attribute bit masks
; ---------------------------------------------------------------------------

; --- Character device attributes (bit 15 = 1) ---
DEV_CHR         equ 0x8000  ; bit 15: character device (vs block device)
DEV_IOCTL       equ 0x4000  ; bit 14: supports IOCTL control strings
DEV_OUB         equ 0x2000  ; bit 13: output-until-busy capable
DEV_OPEN_CLOSE  equ 0x0800  ; bit 11: supports open/close/removable media
DEV_INT29H      equ 0x0010  ; bit  4: recipient of INT 29h fast output
DEV_CLOCK       equ 0x0008  ; bit  3: CLOCK$ device
DEV_NUL         equ 0x0004  ; bit  2: NUL device
DEV_STDOUT      equ 0x0002  ; bit  1: standard output device (CON out)
DEV_STDIN       equ 0x0001  ; bit  0: standard input device (CON in)

; --- Block device attributes (bit 15 = 0) ---
DEV_BLK_REMOVABLE equ 0x0800 ; bit 11: removable media
DEV_BLK_32BIT_SEC equ 0x0002 ; bit  1: uses 32-bit sector addressing

; --- Combined attribute words for common devices ---
DEV_ATTR_CON    equ DEV_CHR | DEV_INT29H | DEV_STDIN | DEV_STDOUT   ; 0x8013
DEV_ATTR_AUX    equ DEV_CHR                                          ; 0x8000
DEV_ATTR_PRN    equ DEV_CHR | DEV_OUB                                ; 0xA000
DEV_ATTR_CLOCK  equ DEV_CHR | DEV_CLOCK                              ; 0x8008
DEV_ATTR_NUL    equ DEV_CHR | DEV_NUL                                ; 0x8004
DEV_ATTR_ANSI   equ DEV_CHR | DEV_INT29H | DEV_STDIN | DEV_STDOUT | DEV_IOCTL  ; 0xC013

; ---------------------------------------------------------------------------
; Device Request Header (passed to strategy/interrupt routines)
; From SYSTEM/INC/DEVSYM.INC / SYSTEM/DEV/DRIVER/
; ---------------------------------------------------------------------------
struc DEV_REQ
    .length     resb 1  ; +0  total length of request packet
    .unit       resb 1  ; +1  unit code (block devices only)
    .command    resb 1  ; +2  command code
    .status     resw 1  ; +3  status word (set by driver)
    .reserved   resb 8  ; +5  reserved for DOS
endstruc               ; = 13 bytes (base)

; Device request status word bits
DEV_STATUS_ERROR    equ 0x8000  ; bit 15: error occurred
DEV_STATUS_BUSY     equ 0x0200  ; bit  9: device busy
DEV_STATUS_DONE     equ 0x0100  ; bit  8: operation complete

; Device command codes (from SYSTEM/DEV/DRIVER/DEVMARK.INC)
DEVCMD_INIT         equ  0  ; initialise driver
DEVCMD_MEDIA_CHK    equ  1  ; media check (block only)
DEVCMD_BUILD_BPB    equ  2  ; build BPB (block only)
DEVCMD_IOCTL_INPUT  equ  3  ; IOCTL input
DEVCMD_INPUT        equ  4  ; input (read)
DEVCMD_INPUT_NOWAITA equ 5  ; non-destructive input (peek)
DEVCMD_INPUT_STATUS equ  6  ; input status
DEVCMD_INPUT_FLUSH  equ  7  ; flush input buffer
DEVCMD_OUTPUT       equ  8  ; output (write)
DEVCMD_OUTPUT_VERIFY equ 9  ; output with verify
DEVCMD_OUTPUT_STATUS equ 10 ; output status
DEVCMD_OUTPUT_FLUSH equ 11  ; flush output buffer
DEVCMD_IOCTL_OUTPUT equ 12  ; IOCTL output
DEVCMD_DEVICE_OPEN  equ 13  ; open device
DEVCMD_DEVICE_CLOSE equ 14  ; close device
DEVCMD_REMOVABLE    equ 15  ; removable media check (block only)
DEVCMD_OUTPUT_BUSY  equ 16  ; output until busy (char only)

; ---------------------------------------------------------------------------
; IOCTL Data Structures (from SYSTEM/CMD/MODE/  and SYSTEM/DEV/)
; ---------------------------------------------------------------------------

; Generic IOCTL get/set info block
struc IOCTL_INFO
    .info_level resb 1  ; information level
    .reserved   resb 4  ; must be zero
endstruc

; Disk Parameter Block (mini) for FAT12
struc DISK_DPB
    .drive      resb 1  ; logical drive number (0=A, 1=B, ...)
    .unit       resb 1  ; unit number within driver
    .sec_size   resw 1  ; bytes per sector
    .clus_mask  resb 1  ; sectors per cluster - 1
    .clus_shift resb 1  ; log2(sectors per cluster)
    .fat_start  resw 1  ; LBA of first FAT
    .fat_count  resb 1  ; number of FATs
    .root_cnt   resw 1  ; number of root directory entries
    .data_start resw 1  ; LBA of first data sector
    .max_clus   resw 1  ; total number of clusters + 1
    .fat_size   resb 1  ; sectors per FAT (FAT12/16)
    .dir_start  resw 1  ; LBA of root directory
    .dev_ptr_off resw 1 ; offset of device driver header
    .dev_ptr_seg resw 1 ; segment of device driver header
    .media_id   resb 1  ; media ID byte
    .access     resb 1  ; 0xFF = disk not yet accessed
    .next_dpb_off resw 1; next DPB offset (chain)
    .next_dpb_seg resw 1; next DPB segment
endstruc

; ---------------------------------------------------------------------------
; Driver name constants (used in device header .name fields)
; ---------------------------------------------------------------------------
DEV_NAME_CON    db 'CON     '
DEV_NAME_AUX    db 'AUX     '
DEV_NAME_PRN    db 'PRN     '
DEV_NAME_NUL    db 'NUL     '
DEV_NAME_CLOCK  db 'CLOCK$  '
DEV_NAME_ANSI   db 'CON     '  ; ANSI.SYS replaces CON

%endif ; SYS_DEVSYM_DEFINED
