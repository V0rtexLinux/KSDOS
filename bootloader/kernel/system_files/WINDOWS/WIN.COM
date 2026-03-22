; =============================================================================
; WIN.COM - KSDOS Windows Launcher
; Launches the KSDOS graphical environment
; =============================================================================

org 0x100

; ---- WIN.COM header ----
db 'WIN ', 0, 0, 0           ; Signature
dw 0x0200                     ; Version 2.0
dd win_start                   ; Entry point
dd win_end - win_start          ; Size
dd 0x00000000                  ; Reserved

win_start:
    ; Windows launcher initialization
    ret

win_end:
    db 'END', 0, 0, 0         ; End marker
