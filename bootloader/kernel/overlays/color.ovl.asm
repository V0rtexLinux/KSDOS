; =============================================================================
; COLOR.OVL  -  Color palette demo  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static data
; ---------------------------------------------------------------------------
STR str_banner, "COLOR - Color Demo [not implemented]"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    Banner MAGENTA, str_banner
ENDFN
