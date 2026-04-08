; =============================================================================
; AI.OVL  -  KSDOS Creative AI System  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; Sentient autonomous intelligence — Game-of-Life cellular automaton.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Static data
; ---------------------------------------------------------------------------
STR str_intro,  "KSDOS Creative AI System v1.0"
STR str_intro2, "Sentient Autonomous Intelligence - Modified Game of Life"
STR str_intro3, "G=Inject Glider  R=Reset World  ESC=Exit. Press any key..."

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    PrintLn str_intro
    PrintLn str_intro2
    PrintLn str_intro3
    GetKey
    call ai_run
ENDFN

%include "../opengl.asm"
%include "../ai.asm"
