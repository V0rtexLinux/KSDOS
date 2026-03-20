# KSDOS - KernelSoft Disk Operating System

A from-scratch 16-bit real-mode x86 operating system mimicking MS-DOS, bootable from a 1.44MB FAT12 floppy disk image.

## Architecture

- **Bootloader** (`bootloader/bootsect.asm`): 512-byte MBR bootloader, loads kernel from FAT12
- **Kernel** (`bootloader/kernel/ksdos.asm`): Main kernel entry, includes all subsystems via `%include`
- **Shell** (`bootloader/kernel/shell.asm`): MS-DOS compatible command interpreter (~2500 lines)
- **FAT12 driver** (`bootloader/kernel/fat12.asm`): Read/write FAT12 filesystem
- **Video** (`bootloader/kernel/video.asm`): VGA text mode output
- **String utils** (`bootloader/kernel/string.asm`): String manipulation helpers
- **Compilers** (3 real compiler implementations):
  - `compiler_asm.asm` - Real single-pass x86 assembler (MASM/NASM compatible), full instruction set
  - `compiler_c.asm` - Real C/C++ subset compiler (tokenizer, codegen, if/while/for, puts/printf)
  - `compiler_csc.asm` - Real C# subset compiler (Console.WriteLine/Write, reuses C infrastructure)

## Build

```bash
make
```

Produces `build/disk.img` (1.44MB FAT12 floppy image, 1474560 bytes).

## Running

Boot with QEMU or any x86 emulator:
```bash
qemu-system-i386 -fda build/disk.img
```

## Memory Layout

- DS=0x1000 segment (64KB)
- Kernel: 0x0000 - ~0x9000 in segment
- FILE_BUF: 0xC000 (file I/O buffer)
- COMP_BUF: 0xD200 (compiler output buffer)
- CC_DATA_BUF: 0xE000 (C compiler string literal pool)
- COMP_SYM: 0xE200 (compiler symbol table)
- COMP_PATCH: 0xEA00 (forward reference patch table)

## Disk Layout

- Sector 0: Boot sector
- Sectors 1-18: FAT1 + FAT2
- Sectors 19-32: Root directory (volume label, KSDOS.SYS, SYSTEM32 dir)
- Sector 33+: KSDOS.SYS kernel (76 sectors)
- Sector 109: SYSTEM32\ directory cluster

## Shell Commands Implemented

DIR, TYPE, COPY, XCOPY, DEL, REN, MD/MKDIR, RD/RMDIR, CD/CHDIR, CLS, VER, DATE,
TIME, MEM, ECHO, SET, PATH, PROMPT, FORMAT, CHKDSK, EDIT, DEBUG, ATTRIB, LABEL,
FIND, MORE, SORT, TREE, DISKCOPY, BACKUP, RESTORE, SYS, HELP, EXIT/QUIT,
CC/GCC (C compiler), CPP/G++ (C++ compiler), MASM/NASM (assembler), CSC (C#)

## Compiler APIs

- `asm_run` - Assemble source in FILE_BUF, write .COM to disk
- `cc_run` - Compile C/C++ source in FILE_BUF, write .COM to disk
- `csc_run` - Compile C# source in FILE_BUF, write .COM to disk
