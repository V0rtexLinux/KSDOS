; =============================================================================
; CONTROL.OVL  -  Control Panel  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
; A directory of the system settings/utility overlays and what they do.
; (Deliberately does not chain-launch other overlays from here: KSDOS
; overlays all share one fixed load buffer, so loading a second overlay
; while this one is still the active caller would overwrite this overlay's
; own code out from under it. Run each command directly from the shell.)
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

STR str_title, "CONTROL PANEL - system settings and utilities"
STR str_hint,  "Run any of these directly from the KSDOS shell prompt:"
STR str_1, "COLOR     - view/pick text colour attributes"
STR str_2, "SYSINFO   - CPU, memory, video and disk report"
STR str_3, "CALC      - integer expression calculator"
STR str_4, "CLOCK     - live date/time from the RTC"
STR str_5, "TASKMGR   - memory and uptime monitor"
STR str_6, "WINFILE   - browse the root directory"
STR str_7, "NOTEPAD   - simple text file viewer/editor"
STR str_8, "PAINT     - Mode 13h drawing canvas"
STR str_footer, "Press any key to exit..."

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    ClearScreen
    Banner CYAN, str_title
    PrintLn str_hint
    NewLine
    PrintLn str_1
    PrintLn str_2
    PrintLn str_3
    PrintLn str_4
    PrintLn str_5
    PrintLn str_6
    PrintLn str_7
    PrintLn str_8
    NewLine
    Print str_footer
    GetKey
ENDFN
