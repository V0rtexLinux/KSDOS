; =============================================================================
; EDIT.COM - KSDOS Text Editor
; Simple text editor for command line
; =============================================================================

org 0x100

; ---- EDIT.COM header ----
db 'EDIT', 0, 0, 0           ; Signature
dw 0x0200                     ; Version 2.0
dd edit_start                  ; Entry point
dd edit_end - edit_start        ; Size
dd 0x00000000                  ; Reserved

edit_start:
    ; Text editor initialization
    ret

edit_end:
    db 'END', 0, 0, 0         ; End marker
