; =============================================================================
; PSYQ.OVL  -  PSYq PlayStation-style ship engine  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    call psyq_ship_demo
ENDFN

%include "../opengl.asm"
%include "../psyq.asm"
