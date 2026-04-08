; =============================================================================
; GOLD4.OVL  -  DOOM-style raycaster engine  (KSDOS)
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
    call gold4_run
ENDFN

%include "../opengl.asm"
%include "../gold4.asm"
