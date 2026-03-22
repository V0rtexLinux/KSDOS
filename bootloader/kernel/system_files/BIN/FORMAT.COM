; =============================================================================
; FORMAT.COM - KSDOS Disk Formatter
; Disk formatting utility for KSDOS
; =============================================================================

org 0x100

; ---- FORMAT.COM header ----
db 'FORM', 0, 0, 0           ; Signature
dw 0x0200                     ; Version 2.0
dd format_start                ; Entry point
dd format_end - format_start    ; Size
dd 0x00000000                  ; Reserved

format_start:
    ; Disk formatter initialization
    ret

format_end:
    db 'END', 0, 0, 0         ; End marker
