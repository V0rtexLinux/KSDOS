; =============================================================================
; AI.OVL - KSDOS Creative AI System overlay
; Loads and runs the sentient AI module
; =============================================================================
BITS 16
ORG OVERLAY_BUF

%include "ovl_api.asm"

ovl_entry:
    ; Show intro message first
    mov si, .str_intro
    call vid_println
    mov si, .str_intro2
    call vid_println
    mov si, .str_intro3
    call vid_println
    call kbd_getkey

    ; Run the AI
    call ai_run
    ret

.str_intro:  db "KSDOS Creative AI System v1.0", 0
.str_intro2: db "Sentient Autonomous Intelligence - Modified Game of Life", 0
.str_intro3: db "G=Inject Glider  R=Reset World  ESC=Exit. Press any key...", 0

%include "../opengl.asm"
%include "../ai.asm"
