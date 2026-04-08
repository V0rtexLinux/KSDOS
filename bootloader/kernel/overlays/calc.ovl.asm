; =============================================================================
; CALC.OVL  -  Calculator  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static data
; ---------------------------------------------------------------------------
STR str_banner, "CALC - Calculator [not implemented]"

; ---------------------------------------------------------------------------
; U0 ovl_entry()  -  overlay entry point (near-called by kernel)
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    Banner YELLOW, str_banner
ENDFN
