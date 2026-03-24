; =============================================================================
; sys_dossym.inc — NASM-compatible DOS symbol definitions
; Derived from SYSTEM/INC/DOSSYM.INC  (MS-DOS 4.0 Open Source)
; Converted from MASM syntax to NASM syntax for KSDOS kernel build
; =============================================================================

%ifndef SYS_DOSSYM_DEFINED
%define SYS_DOSSYM_DEFINED

; ---------------------------------------------------------------------------
; Boolean constants (from DOSMAC.INC)
; ---------------------------------------------------------------------------
DOS_TRUE        equ 0xFFFF
DOS_FALSE       equ 0x0000

; ---------------------------------------------------------------------------
; ASCII / Control character definitions (from DOSSYM.INC)
; ---------------------------------------------------------------------------
c_DEL           equ 0x7F    ; ASCII rubout or delete previous char
c_BS            equ 0x08    ; ^H  ASCII backspace
c_CR            equ 0x0D    ; ^M  ASCII carriage return
c_LF            equ 0x0A    ; ^J  ASCII linefeed
c_ETB           equ 0x17    ; ^W  ASCII end of transmission block
c_NAK           equ 0x15    ; ^U  ASCII negative acknowledge
c_ETX           equ 0x03    ; ^C  ASCII end of text
c_HT            equ 0x09    ; ^I  ASCII horizontal tab
c_BEL           equ 0x07    ; ^G  ASCII bell
c_ESC           equ 0x1B    ;     ASCII escape
c_FF            equ 0x0C    ; ^L  ASCII form feed (clear screen)
c_SUB           equ 0x1A    ; ^Z  ASCII end of file marker

; ---------------------------------------------------------------------------
; File Attributes (from DOSSYM.INC / FAT spec)
; ---------------------------------------------------------------------------
ATTR_READONLY   equ 0x01    ; file is read-only
ATTR_HIDDEN     equ 0x02    ; file is hidden (DIR won't show it)
ATTR_SYSTEM     equ 0x04    ; file is a system file
ATTR_VOLID      equ 0x08    ; directory entry is volume label
ATTR_DIRECTORY  equ 0x10    ; entry is a subdirectory
ATTR_ARCHIVE    equ 0x20    ; file has been modified since last backup

; Combined attribute shortcuts
ATTR_KSDOS_SYS  equ ATTR_READONLY | ATTR_HIDDEN | ATTR_SYSTEM  ; 0x07

; ---------------------------------------------------------------------------
; DOS Error Codes (INT 21h, AX on error return)
; ---------------------------------------------------------------------------
EXTERR_NONE         equ  0   ; success
EXTERR_INV_FUNC     equ  1   ; invalid function number
EXTERR_NO_FILE      equ  2   ; file not found
EXTERR_NO_PATH      equ  3   ; path not found
EXTERR_NO_HANDLE    equ  4   ; too many open files
EXTERR_ACCESS       equ  5   ; access denied
EXTERR_INV_HANDLE   equ  6   ; invalid handle
EXTERR_MCB_DEST     equ  7   ; memory control blocks destroyed
EXTERR_NOMEM        equ  8   ; insufficient memory
EXTERR_INV_MEM_BLK  equ  9   ; invalid memory block address
EXTERR_INV_ENV      equ 10   ; invalid environment
EXTERR_INV_FMT      equ 11   ; invalid format
EXTERR_INV_ACC      equ 12   ; invalid access code
EXTERR_INV_DATA     equ 13   ; invalid data
EXTERR_DRIVE_NR     equ 15   ; invalid drive was specified
EXTERR_CUR_DIR      equ 16   ; attempt to remove the current directory
EXTERR_NOT_SAME_DEV equ 17   ; not same device
EXTERR_NO_MORE_FILES equ 18  ; no more files
EXTERR_WRITE_PROT   equ 19   ; write protected disk
EXTERR_UNKNOWN_UNIT equ 20   ; unknown unit
EXTERR_DRIVE_NR2    equ 21   ; drive not ready
EXTERR_INV_CMD      equ 22   ; unknown command
EXTERR_DATA_ERR     equ 23   ; data error (CRC)
EXTERR_BAD_RQ_LEN   equ 24   ; bad request structure length
EXTERR_SEEK_ERR     equ 25   ; seek error
EXTERR_UNKNOWN_MEDIA equ 26  ; unknown media type
EXTERR_NO_SECTOR    equ 27   ; sector not found
EXTERR_NO_PAPER     equ 28   ; printer out of paper
EXTERR_WRITE_FAULT  equ 29   ; write fault
EXTERR_READ_FAULT   equ 30   ; read fault
EXTERR_GEN_FAIL     equ 31   ; general failure
EXTERR_SHARING      equ 32   ; sharing violation
EXTERR_LOCK         equ 33   ; lock violation
EXTERR_INV_DISK     equ 34   ; invalid disk change
EXTERR_FCB_UNAVAIL  equ 35   ; FCB unavailable
EXTERR_SHARE_BUF_OV equ 36   ; sharing buffer overflow

; ---------------------------------------------------------------------------
; DOS System Calls (INT 21h subfunctions) — key ones
; ---------------------------------------------------------------------------
DOS_PRINT_CHAR      equ 0x02 ; print character in DL
DOS_PRINT_STRING    equ 0x09 ; print $-terminated string at DS:DX
DOS_STDIN_READ      equ 0x0A ; buffered keyboard input
DOS_GET_VERSION     equ 0x30 ; get DOS version
DOS_TERMINATE       equ 0x4C ; terminate with return code

; ---------------------------------------------------------------------------
; BIOS Interrupt constants
; ---------------------------------------------------------------------------
INT_VIDEO           equ 0x10 ; BIOS video services
INT_KEYBOARD        equ 0x16 ; BIOS keyboard services
INT_DISK            equ 0x13 ; BIOS disk services
INT_MISC            equ 0x15 ; BIOS misc services
INT_TIMER           equ 0x1C ; timer tick interrupt
INT_DOSAPI          equ 0x21 ; DOS API

; ---------------------------------------------------------------------------
; Memory Layout (real mode)
; ---------------------------------------------------------------------------
SEG_IVT             equ 0x0000  ; Interrupt Vector Table
SEG_BDA             equ 0x0040  ; BIOS Data Area
SEG_BOOT            equ 0x07C0  ; Boot sector loads here
SEG_KSDOS           equ 0x1000  ; KSDOS kernel segment
SEG_OVERLAY         equ 0x0700  ; Overlay buffer (OVERLAY_BUF=0x7000)
SEG_EBDA            equ 0x9000  ; Extended BIOS Data Area (typical)
SEG_VGA_TEXT        equ 0xB800  ; VGA text mode framebuffer
SEG_VGA_GFX         equ 0xA000  ; VGA graphics framebuffer
SEG_VBIOS           equ 0xC000  ; Video BIOS ROM
SEG_BIOS_ROM        equ 0xF000  ; System BIOS ROM

; ---------------------------------------------------------------------------
; BPB offsets (from SYSTEM/INC/BPB.INC) — FAT12 floppy BPB layout
; ---------------------------------------------------------------------------
BPB_BYTSPERSEC      equ 0x0B    ; bytes per sector (word)
BPB_SECPERCLUS      equ 0x0D    ; sectors per cluster (byte)
BPB_RSVDSECCNT      equ 0x0E    ; reserved sectors count (word)
BPB_NUMFATS         equ 0x10    ; number of FAT copies (byte)
BPB_ROOTENTCNT      equ 0x11    ; root entry count (word)
BPB_TOTSEC16        equ 0x13    ; total sectors 16-bit (word)
BPB_MEDIA           equ 0x15    ; media type (byte)
BPB_FATSZ16         equ 0x16    ; sectors per FAT (word)
BPB_SECPERTRK       equ 0x18    ; sectors per track (word)
BPB_NUMHEADS        equ 0x1A    ; number of heads (word)
BPB_HIDDSEC         equ 0x1C    ; hidden sectors (dword)
BPB_TOTSEC32        equ 0x20    ; total sectors 32-bit (dword)

; ---------------------------------------------------------------------------
; Directory Entry offsets (FAT 8.3 format, from SYSTEM/INC/DIRENT.INC)
; ---------------------------------------------------------------------------
DIRENT_NAME         equ 0x00    ; 8.3 name, 11 bytes
DIRENT_ATTR         equ 0x0B    ; attribute byte
DIRENT_NTRES        equ 0x0C    ; reserved for WinNT (KSDOS: unused)
DIRENT_CRTTIME_10MS equ 0x0D    ; creation time fine
DIRENT_CRTTIME      equ 0x0E    ; creation time (word)
DIRENT_CRTDATE      equ 0x10    ; creation date (word)
DIRENT_LASTACC      equ 0x12    ; last access date (word)
DIRENT_FSTCLUSHI    equ 0x14    ; high word of first cluster (FAT32 only)
DIRENT_WRTTIME      equ 0x16    ; last write time (word)
DIRENT_WRTDATE      equ 0x18    ; last write date (word)
DIRENT_FSTCLUSLO    equ 0x1A    ; low word of first cluster (word)
DIRENT_FILESIZE     equ 0x1C    ; file size in bytes (dword)
DIRENT_SIZE         equ 32      ; size of one directory entry

; ---------------------------------------------------------------------------
; FAT12 / FAT16 special cluster values
; ---------------------------------------------------------------------------
FAT12_FREE          equ 0x000   ; cluster is free
FAT12_RSVD          equ 0x001   ; reserved
FAT12_EOC           equ 0xFF8   ; end-of-chain marker (0xFF8..0xFFF)
FAT12_BAD           equ 0xFF7   ; bad cluster marker
FAT12_ENTRY_MASK    equ 0xFFF   ; 12-bit mask

; ---------------------------------------------------------------------------
; Video / Display constants (from SYSTEM/DEV/DISPLAY)
; ---------------------------------------------------------------------------
VID_COLS            equ 80      ; text mode columns
VID_ROWS            equ 25      ; text mode rows
VID_TABSIZE         equ 8       ; tab stop every 8 columns

; Video attribute bits (CGA/EGA/VGA text mode)
VATTR_FG_BLACK      equ 0x00
VATTR_FG_BLUE       equ 0x01
VATTR_FG_GREEN      equ 0x02
VATTR_FG_CYAN       equ 0x03
VATTR_FG_RED        equ 0x04
VATTR_FG_MAGENTA    equ 0x05
VATTR_FG_BROWN      equ 0x06
VATTR_FG_LGREY      equ 0x07
VATTR_FG_DGREY      equ 0x08
VATTR_FG_LBLUE      equ 0x09
VATTR_FG_LGREEN     equ 0x0A
VATTR_FG_LCYAN      equ 0x0B
VATTR_FG_LRED       equ 0x0C
VATTR_FG_LMAG       equ 0x0D
VATTR_FG_YELLOW     equ 0x0E
VATTR_FG_WHITE      equ 0x0F
VATTR_BG_SHIFT      equ 4       ; background colour starts at bit 4
VATTR_BLINK         equ 0x80    ; bit 7 = blink

; Common attribute combos
VATTR_NORMAL        equ (VATTR_FG_LGREY)                        ; 0x07
VATTR_BRIGHT        equ (VATTR_FG_WHITE)                        ; 0x0F
VATTR_TITLE         equ (VATTR_FG_YELLOW | (VATTR_FG_BLUE << 4)) ; 0x1E
VATTR_WARN          equ (VATTR_FG_YELLOW | (VATTR_FG_RED  << 4)) ; 0x4E
VATTR_ERR           equ (VATTR_FG_LRED)                         ; 0x0C
VATTR_SUCCESS       equ (VATTR_FG_LGREEN)                       ; 0x0A

; ---------------------------------------------------------------------------
; Keyboard scan codes (from SYSTEM/DEV/KEYBOARD)
; ---------------------------------------------------------------------------
KEY_ESC             equ 0x011B  ; ESC
KEY_BACKSPACE       equ 0x0E08
KEY_TAB             equ 0x0F09
KEY_ENTER           equ 0x1C0D
KEY_F1              equ 0x3B00
KEY_F2              equ 0x3C00
KEY_F3              equ 0x3D00
KEY_F4              equ 0x3E00
KEY_F5              equ 0x3F00
KEY_F6              equ 0x4000
KEY_F7              equ 0x4100
KEY_F8              equ 0x4200
KEY_F9              equ 0x4300
KEY_F10             equ 0x4400
KEY_HOME            equ 0x4700
KEY_UP              equ 0x4800
KEY_PGUP            equ 0x4900
KEY_LEFT            equ 0x4B00
KEY_RIGHT           equ 0x4D00
KEY_END             equ 0x4F00
KEY_DOWN            equ 0x5000
KEY_PGDN            equ 0x5100
KEY_INS             equ 0x5200
KEY_DEL             equ 0x5300
KEY_F11             equ 0x8500
KEY_F12             equ 0x8600

; ---------------------------------------------------------------------------
; Stack frame sizes used by DOS kernel (from SYSTEM/DOS/DOSSEG.ASM)
; ---------------------------------------------------------------------------
CBSTACK             equ 0x0080  ; 128 bytes for interrupt stack frame

; ---------------------------------------------------------------------------
; KSDOS extended constants (beyond original DOS 4.0)
; ---------------------------------------------------------------------------
KSDOS_VERSION_MAJ   equ 1
KSDOS_VERSION_MIN   equ 0
KSDOS_BUILD_YEAR    equ 2024

; Overlay buffer EQU (matches OVERLAY_BUF in ovl_api.asm)
KSDOS_OVL_BUF       equ 0x7000

; KSDOS specific return codes
KSDOS_OK            equ 0
KSDOS_ERR           equ 1
KSDOS_ERR_FULL      equ 2
KSDOS_ERR_NOFILE    equ 3
KSDOS_ERR_IO        equ 4

%endif ; SYS_DOSSYM_DEFINED
