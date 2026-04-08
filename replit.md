# KSDOS - 16-bit Real-Mode x86 Operating System

## Overview
KSDOS is a 16-bit real-mode x86 operating system written in NASM assembly. It boots from a FAT12 floppy image and runs inside QEMU. The project includes a custom kernel, shell, overlay-based module system, and embedded MS-DOS 4.0 source files as historical reference.

## Tech Stack
- **Language**: HolyC16 (custom HolyC-inspired macro language for NASM 16-bit real mode)
- **Assembler**: NASM (backend that assembles HolyC16 macro expansions)
- **Scripting**: Perl (for FAT12 disk image builder `tools/mkimage.pl`)
- **Emulator**: QEMU (`qemu-system-i386`) with VNC display
- **Build**: GNU Make

## HolyC16 Language
`bootloader/kernel/holyc16.mac` defines the HolyC16 macro language — a HolyC-inspired syntax layer that compiles to clean 16-bit NASM assembly.

### Type System
| HolyC16 | Size | Description |
|---------|------|-------------|
| `U0`    | —    | void (function return type) |
| `U8`    | 1B   | unsigned byte |
| `I8`    | 1B   | signed byte |
| `U16`   | 2B   | unsigned word |
| `I16`   | 2B   | signed word |
| `Bool`  | 1B   | boolean (0 or 1) |
| `Ptr`   | 2B   | near pointer |
| `STR`   | var  | null-terminated string |
| `STRBUF`| var  | zero-filled byte buffer |

### Functions
```nasm
FN U0, my_function
    PrintLn str_hello
ENDFN               ; near ret

FN U0, overlay_entry
    ...
ENDFNF              ; far retf (for overlays far-called by kernel)
```

### Control Flow
```nasm
; IF / ELSE / ENDIF
cmp ax, 5
IF e                ; execute body if equal
    PrintLn str_yes
ELSE
    PrintLn str_no
ENDIF

; High-level IF variants (include the cmp)
IF_EQ  ax, 5        ; if ax == 5
IF_NE  bx, 0        ; if bx != 0
IF_ZERO  al         ; if al == 0
IF_NZERO al         ; if al != 0

; WHILE / ENDWHILE / BREAK_IF
WHILE_NE cx, 0      ; while cx != 0
    dec cx
ENDWHILE

; Counted loop (uses x86 LOOP instruction)
LOOP_CX 10
    call do_thing
ENDLOOP
```

### Output / Input Macros
```nasm
Print    str_hello       ; print string (no newline)
PrintLn  str_hello       ; print string + newline
PrintChar 'A'            ; print one character
NewLine                  ; newline only
SetColor CYAN            ; set text colour
Banner   YELLOW, str_hi  ; coloured heading + reset colour
GetKey                   ; wait for keypress → AL/AH
ReadLine buf, 127        ; read line into buffer
```

### Colors
`BLACK BLUE GREEN CYAN RED MAGENTA BROWN LTGRAY DKGRAY LTBLUE LTGREEN LTCYAN LTRED LTMAGENTA YELLOW WHITE`

## Project Structure
- `bootloader/boot/` — MBR, boot sector, VGA BIOS
- `bootloader/kernel/` — Core kernel (ksdos.asm + included modules)
- `bootloader/kernel/overlays/` — Overlay binaries (.OVL) loaded on demand
- `bootloader/kernel/SYSTEM/` — MS-DOS 4.0 source (MASM format, reference only)
- `tools/mkimage.pl` — Perl script that assembles the FAT12 floppy image
- `raspberry/` — Raspberry Pi deployment scripts
- `build/` — Build output (disk.img, .bin, .OVL files)

## Build & Run
```bash
make image   # Build disk.img
make run     # Build and run in QEMU (VNC on display :0)
make deploy  # Package for Raspberry Pi deployment
```

## Replit Setup
- Workflow: "Start application" → runs `make image && make run`
- Output type: VNC (view the OS in the VNC panel)
- Packages: nasm, qemu, gcc-unwrapped, binutils, gnumake, p7zip, perl

## Migration Notes (Replit import)
Several pre-existing source bugs were fixed to enable compilation:
1. MS-DOS 4.0 SYSTEM/ files use MASM syntax — excluded from NASM build (reference only)
2. `opengl.asm` palette/gfx functions guarded via `%define GFX_PALETTE_DEFINED` in video.asm
3. `gfx_line_mem` moved to video.asm
4. Invalid 16-bit addresses in ai.asm and gold4.asm fixed
5. Duplicate labels resolved (str_no_space, str_ai_title, cur_dir_cluster)
6. Missing overlay stubs created: MATRIX, SYSINFO, CALC, COLOR
7. Boot sector trimmed to fit 512 bytes
8. Perl script typo fixed (mkimage.pl line 245: $src_root → $src_path)

## Raspberry Pi Deployment
Run `make deploy` to generate `build/ksdos-watch.tar.gz`. Transfer to Pi:
```bash
scp build/ksdos-watch.tar.gz pi@<ip>:~/
ssh pi@<ip> 'tar xzf ksdos-watch.tar.gz && sudo bash ksdos-watch/setup.sh'
```
