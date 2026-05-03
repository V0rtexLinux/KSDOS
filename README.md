# KSDOS v2.0

A 16-bit real-mode x86 operating system written in NASM assembly, inspired by MS-DOS. Runs in QEMU and deploys to Raspberry Pi with a TFT touchscreen.

---

## Features

- **FAT12 filesystem** — full read/write support, root directory, subdirectories, cluster chains
- **42 overlay modules** — compilers, games, tools, and drivers loaded on demand from disk
- **SYSTEM32 directory tree** — embedded MS-DOS 4.0 reference sources (INC, H, DOS, BIOS, CMD, DEV, MEMM)
- **Enhanced VGA boot screen** — full-color direct VGA text buffer rendering with animated progress bar
- **Full disk installer** — copies all 2880 sectors to SSD/HD via BIOS EDD (LBA) with CHS fallback
- **3-disk installer set** — MS-DOS-style installation flow across three floppy images
- **Raspberry Pi deployment** — auto-starts via systemd, TFT SPI framebuffer, uinput virtual keyboard

---

## Architecture

```
bootloader/
  boot/
    bootsect.asm      FAT12 boot sector (512 bytes) — loads KSDOS.SYS into 0x1000:0000
    mbr.asm           Master Boot Record
  kernel/
    ksdos.asm         Kernel entry point + jump table + module includes
    splash.asm        VGA boot screen (direct 0xB800 writes, animated progress bar)
    fat12.asm         FAT12 filesystem driver
    disk.asm          BIOS disk I/O (EDD + CHS fallback)
    install.asm       Full-disk installer (copies all 2880 sectors to SSD/HD)
    shell.asm         Command shell
    video.asm         VGA text + Mode 13h graphics driver
    ovl_api.asm       Overlay loader API
    mass_loader.asm   Mass overlay pre-loader
    overlays/         42 overlay .OVL modules (see below)
    SYSTEM/           MS-DOS 4.0 reference source tree
tools/
  mkimage.pl          FAT12 disk image builder (Perl)
raspberry/
  setup.sh            One-time Pi setup
  launch.sh           QEMU launch script
  vkbd.c              Touch virtual keyboard (C, uinput)
  ksdos-watch.service systemd unit
```

---

## Overlays

All overlays are loaded on demand by the kernel overlay API and executed at `0x7000`.

| Category | Overlays |
|---|---|
| Compilers | CC, MASM, CSC, JAVA, PY, PERL, PHP, VB, DELPHI, JS, HOLYC |
| Dev Tools | IDE, PSYQ, GOLD4, AI |
| System | NET, OPENGL, MUSIC, RING0HW, MATRIX, SYSINFO, CALC, COLOR |
| Games | PONG, SNAKE, TETRIS, BRKOUT, INVADE, ASTRO, MAZE, TANKS, RACE, CHESS, MINE, DUNG, FROG, LINES, SIMON, CONN4, WORM, GOLF, SHOOT, ROGUE |

---

## Boot Screen

The boot screen (`splash.asm`) writes directly to the VGA text buffer at `0xB800:0000` — no ANSI.SYS dependency. Features:

- Full blue background with centered ASCII art logo
- Bright white / cyan / yellow color scheme
- Animated progress bar using CP437 block characters (`█` fill, `░` empty)
- Per-stage status messages (FAT init → root dir → disk subsystem → drivers → ready)
- Bottom status bar updates when the shell starts

---

## Installation (SSD / HD)

The `install_to_hd` routine in `install.asm` copies the **complete 2880-sector disk image** (1.44 MB) to the internal hard disk or SSD (BIOS drive `0x80`).

- Uses **INT 13h AH=43h EDD** (LBA) as primary method — works on all modern BIOS/UEFI-CSM
- Falls back to **CHS** (63 SPT / 255 heads) if EDD is unavailable
- `install_to_ssd` is an alias — SSDs appear identically to HDDs under BIOS
- Previous versions only copied 1 sector (the MBR), causing **"KSDOS.SYS not found"** on reboot — this is now fixed

---

## Build

Requirements: `nasm`, `perl`, `qemu-system-i386`, `make`

```bash
make              # build build/disk.img (full system)
make disks        # build all 3 installer disk images
make run          # boot in QEMU (VNC on :0)
make run-sdl      # boot in QEMU (SDL window)
make run-serial   # boot in QEMU (serial/headless)
make run-disk1    # boot installer Disk 1 in QEMU
make deploy       # package for Raspberry Pi → build/ksdos-watch.tar.gz
make clean        # remove build/
```

### 3-Disk Installer

```
disk1.img   Disk 1 — initial setup, Ring0 hardware overlay
disk2.img   Disk 2 — system files
disk3.img   Disk 3 — full KSDOS system (copy of disk.img)
```

---

## Raspberry Pi Deployment

```bash
make deploy
scp build/ksdos-watch.tar.gz pi@<IP>:~/
ssh pi@<IP> "tar xzf ksdos-watch.tar.gz && sudo bash ksdos-watch/setup.sh && sudo reboot"
```

`setup.sh` installs QEMU, configures the TFT SPI framebuffer overlay, compiles `vkbd`, and installs the systemd service.

### Virtual Keyboard (`vkbd.c`)

- Renders a QWERTY layout on the bottom ~36% of the TFT framebuffer
- Reads touch events from Linux evdev (`/dev/input/event*`, auto-detected)
- Injects keypresses into QEMU via **uinput** (no QMP socket — no attack surface)
- Build: `gcc -O2 -o vkbd vkbd.c -lpthread`

| File | Purpose |
|---|---|
| `setup.sh` | One-time Pi setup: QEMU, TFT overlay, vkbd compile, service install |
| `launch.sh` | QEMU + virtual keyboard launch script |
| `vkbd.c` | Touch virtual keyboard (C, uinput) |
| `ksdos-watch.service` | systemd unit for auto-start on boot |

---

## Key Files

| File | Description |
|---|---|
| `bootloader/boot/bootsect.asm` | FAT12 boot sector — finds and loads KSDOS.SYS |
| `bootloader/kernel/ksdos.asm` | Kernel entry point, jump table, module includes |
| `bootloader/kernel/splash.asm` | VGA boot screen with direct buffer writes |
| `bootloader/kernel/install.asm` | Full-disk SSD/HD installer (2880 sectors) |
| `bootloader/kernel/fat12.asm` | FAT12 read/write filesystem driver |
| `bootloader/kernel/ovl_api.asm` | Overlay loader and mass-loader API |
| `bootloader/kernel/opengl.asm` | Software graphics primitives (Mode 13h) |
| `bootloader/kernel/shell.asm` | Interactive command shell |
| `tools/mkimage.pl` | FAT12 disk image builder with SYSTEM32 tree embedding |
| `raspberry/vkbd.c` | Touch virtual keyboard for Pi TFT screen |
