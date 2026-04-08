; =============================================================================
; NET.OVL  -  Network overlay  (NE2000 + TCP/IP + HTTP)  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Loaded on demand; reads command argument from sh_arg (0x0060).
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    call net_run
ENDFN

%include "../net.asm"
