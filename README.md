# KSDOS - KernelSoft Disk Operating System

A bare-metal x86 OS running in QEMU with PS1 (PSYq) and DOOM (GOLD4) game dev environments.

## Project Overview

KSDOS is a bootable MS-DOS-like operating system written from scratch:
- **Bootloader** (boot.asm): Real-mode BIOS boot, loads 48 sectors (24576 bytes)
- **Kernel** (core.c): 32-bit protected-mode i386 C kernel, all-in-one
- **SDK stubs**: PSYq (PS1) and GOLD4 (DOOM) header-only SDKs
- **Game examples**: PSX shooter and DOOM-style FPS

## Architecture

```
bootloader/
  boot/boot.asm      BIOS bootloader (512 bytes, reads 48 sectors)
  core/
    entry.s          GDT + protected-mode entry, calls core_main()
    setup.asm        Optional early setup (256 bytes)
    linker.ld        Links kernel to 0x7F00 (flat binary)
    core.c           Complete kernel: VGA text + Bochs VBE + keyboard
sdk/
  psyq/include/libps.h    PS1 GPU/GTE/PAD/SPU/CD API stubs
  gold4/include/gold4.h   DOOM VGA Mode 13h + WAD + input + sound
games/
  psx/src/main.c    PS1 game example (rotating ship, enemies)
  psx/src/gfx.c     GPU primitives helper
  psx/psx.ld        PS1 linker script (0x80010000)
  doom/src/main.c   DOOM-era raycaster game (Mode 13h 320x200)
build/ksdos.img     Final bootable disk image (1.44MB floppy)
```

## Build System

```
make image       - Build KSDOS OS image (boot + kernel)
make psx-game    - Build PS1 game (needs PSn00bSDK installed)
make doom-game   - Build DOOM game (needs GNU gold linker)
make clean       - Remove build artifacts
```

## Kernel Features (core.c)

### Shell Commands
| Command | Description |
|---------|-------------|
| `help` | List all commands |
| `cls` | Clear shell |
| `ver` | Show version |
| `sysinfo` | Hardware info |
| `engine psx` | PSYq IDE screen |
| `engine doom` | GOLD4 IDE screen |
| `makegame psx` | Simulate PS1 build pipeline |
| `makegame doom` | Simulate DOOM build pipeline |
| `playgame psx` | Launch PSYq OpenGL demo |
| `playgame doom` | Launch DOOM raycaster demo |
| `gl` | Rotating RGB cube (default) |
| `gl psx` | PSYq PS1 spinning diamond demo |
| `gl doom` | DOOM raycaster demo |
| `exit` | Halt system |

### System Components
- **Login**: username=ksdos, password=ksdos
- **Boot sequence**: Animated multi-stage boot log
- **Command history**: UP/DOWN arrow keys cycle through 8 commands
- **Scrollable output area**: Rows 16-22 scroll automatically
- **Keyboard driver**: Full PS/2 with scan code mapping, LEDs, shift/caps/ctrl/alt

### OpenGL Software Renderer (Bochs VBE)
- **Mode**: 640×480 32bpp linear framebuffer at 0xE0000000
- **API**: VBE ports 0x01CE/0x01CF
- **Primitives**: pixel, line, filled triangle (flat-top/flat-bottom)
- **Font**: 5×7 bitmap font (96 ASCII glyphs)
- **3D math**: Fixed-point 16.16 sine/cosine tables, rotation, perspective projection

### OpenGL Demos
1. **Cube** (`gl`): Rotating RGB cube with 6 colored faces and edges
2. **PSX demo** (`gl psx`): Spinning diamond with sky gradient, shows PSYq info
3. **DOOM demo** (`gl doom`): Raycaster through 16×16 map, auto-rotating camera

## SDKs

### PSYq v4.7 (PSn00bSDK compatible)
- Location: `sdk/psyq/include/libps.h`
- Target: mipsel-none-elf-gcc 12.3.0 (cross-compile for MIPS R3000)
- Real SDK: PSn00bSDK v0.24 from GitHub releases
- Provides: GPU, GTE, PAD, SPU, CD-ROM types and macros

### GOLD4 v4.0 (GNU gold linker + djgpp)
- Location: `sdk/gold4/include/gold4.h`
- Target: i386-elf (DOS executables via djgpp or host gcc -m32)
- Tools: GNU gold linker, deutex (WAD builder)
- Provides: VGA Mode 13h, WAD format, BSP types, fixed-point math, keyboard, sound

## Memory Map

| Region | Size | Purpose |
|--------|------|---------|
| 0x0000-0x7BFF | 31 KB | IVT, BIOS data, stack |
| 0x7C00-0x7DFF | 512 B | Bootloader (boot.asm) |
| 0x7E00-0x7EFF | 256 B | Early setup (setup.asm) |
| 0x7F00-...    | 22 KB | Kernel (core.c) |
| 0xB8000       | 4 KB | VGA text framebuffer |
| 0xE0000000    | 1.2MB | Bochs VBE 640×480×32bpp |

## QEMU Command
```bash
mkdir -p /tmp/xdg-runtime && \
XDG_RUNTIME_DIR=/tmp/xdg-runtime DISPLAY=:0 \
qemu-system-i386 -drive format=raw,file=build/ksdos.img -vga std -display sdl
```

## Linker Notes
- `boot.asm` reads `mov al, 48` (48 sectors = 24576 bytes)
- Makefile uses `truncate -s 24576` to pad core.bin
- `after.bin` (linked) is ~22608 bytes, padded to 24576
- Makefile recipe lines MUST use real TAB characters (run `sed -i 's/^        /\t/g' Makefile` if they become spaces after editing)
