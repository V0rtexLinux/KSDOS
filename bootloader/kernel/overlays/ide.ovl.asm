; =============================================================================
; IDE.OVL  -  Built-in text editor  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; sh_arg (0x0060) = filename to open (may be empty).
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    mov si, sh_arg      ; pass filename from shared arg buffer
    call ide_run
    ClearScreen
ENDFN

%include "../ide.asm"
