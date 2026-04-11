# =============================================================================
# KSDOS Build System
# Produces a 1.44MB FAT12 floppy image (disk.img) bootable in QEMU
# =============================================================================

NASM     := nasm
PERL     := perl
QEMU     := qemu-system-i386

# Overlay load address — must match OVERLAY_BUF in ovl_api.asm
OVL_ORG  := 0x7000

BUILD    := build
BOOT_DIR := bootloader/boot
KERN_DIR := bootloader/kernel
OVL_DIR  := bootloader/kernel/overlays
TOOLS    := tools

BOOTSECT_SRC := $(BOOT_DIR)/bootsect.asm
KERNEL_SRC   := $(KERN_DIR)/ksdos.asm
MBR_SRC      := $(BOOT_DIR)/mbr.asm

BOOTSECT_BIN := $(BUILD)/bootsect.bin
KERNEL_BIN   := $(BUILD)/ksdos.bin
MBR_BIN      := $(BUILD)/mbr.bin
DISK_IMG     := $(BUILD)/disk.img

# ---------------------------------------------------------------------------
# Overlay binaries (assembled separately, embedded as .OVL files on disk)
# ---------------------------------------------------------------------------
OVL_NAMES := CC MASM CSC MUSIC NET OPENGL PSYQ GOLD4 IDE AI MATRIX SYSINFO CALC COLOR JAVA PY PERL PHP VB DELPHI JS RING0HW \
             PONG SNAKE TETRIS BRKOUT INVADE ASTRO MAZE TANKS RACE CHESS MINE DUNG FROG LINES SIMON CONN4 WORM GOLF SHOOT ROGUE
OVL_BINS  := $(patsubst %,$(BUILD)/%.OVL,$(OVL_NAMES))

# Disk images (3-disk installer)
DISK1_IMG := $(BUILD)/disk1.img
DISK2_IMG := $(BUILD)/disk2.img
DISK3_IMG := $(BUILD)/disk3.img

RASPBERRY := raspberry
DEPLOY_DIR := $(BUILD)/ksdos-watch
DEPLOY_TAR := $(BUILD)/ksdos-watch.tar.gz

.PHONY: all image run run-sdl run-serial deploy clean help disks disk1 disk2 disk3

all: image

image: $(DISK_IMG)

$(BOOTSECT_BIN): $(BOOTSECT_SRC) | $(BUILD)
        @echo "[NASM] Assembling boot sector..."
        $(NASM) -f bin -i $(BOOT_DIR)/ -o $@ $<
        @echo "[OK]   bootsect.bin"

$(KERNEL_BIN): $(KERNEL_SRC) | $(BUILD)
        @echo "[NASM] Assembling kernel (KSDOS.SYS)..."
        $(NASM) -f bin -DBUILDING_KERNEL -i $(KERN_DIR)/ -o $@ $<
        @echo "[OK]   ksdos.bin"

$(MBR_BIN): $(MBR_SRC) | $(BUILD)
        @echo "[NASM] Assembling MBR..."
        $(NASM) -f bin -i $(BOOT_DIR)/ -o $@ $<
        @echo "[OK]   mbr.bin"

# Rule: assemble each overlay (sources live in OVL_DIR, include kernel dir too)
OVL_FLAGS := -f bin -DOVERLAY_BUF=$(OVL_ORG) -i $(KERN_DIR)/ -i $(OVL_DIR)/

$(BUILD)/CC.OVL:     $(OVL_DIR)/cc.ovl.asm     $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay CC..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   CC.OVL"

$(BUILD)/MASM.OVL:   $(OVL_DIR)/masm.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay MASM..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   MASM.OVL"

$(BUILD)/CSC.OVL:    $(OVL_DIR)/csc.ovl.asm     $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay CSC..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   CSC.OVL"

$(BUILD)/MUSIC.OVL:  $(OVL_DIR)/music.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay MUSIC..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   MUSIC.OVL"

$(BUILD)/NET.OVL:    $(OVL_DIR)/net.ovl.asm     $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay NET..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   NET.OVL"

$(BUILD)/OPENGL.OVL: $(OVL_DIR)/opengl.ovl.asm  $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay OPENGL..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   OPENGL.OVL"

$(BUILD)/PSYQ.OVL:   $(OVL_DIR)/psyq.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay PSYQ..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   PSYQ.OVL"

$(BUILD)/GOLD4.OVL:  $(OVL_DIR)/gold4.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay GOLD4..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   GOLD4.OVL"

$(BUILD)/IDE.OVL:    $(OVL_DIR)/ide.ovl.asm     $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay IDE..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   IDE.OVL"

$(BUILD)/AI.OVL:     $(OVL_DIR)/ai.ovl.asm      $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay AI..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   AI.OVL"

$(BUILD)/MATRIX.OVL:  $(OVL_DIR)/matrix.ovl.asm  $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay MATRIX..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   MATRIX.OVL"

$(BUILD)/SYSINFO.OVL: $(OVL_DIR)/sysinfo.ovl.asm $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay SYSINFO..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   SYSINFO.OVL"

$(BUILD)/CALC.OVL:   $(OVL_DIR)/calc.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay CALC..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   CALC.OVL"

$(BUILD)/COLOR.OVL:  $(OVL_DIR)/color.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay COLOR..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   COLOR.OVL"

$(BUILD)/JAVA.OVL:   $(OVL_DIR)/java.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay JAVA..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   JAVA.OVL"

$(BUILD)/PY.OVL:     $(OVL_DIR)/python.ovl.asm  $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay PY..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   PY.OVL"

$(BUILD)/PERL.OVL:   $(OVL_DIR)/perl.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay PERL..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   PERL.OVL"

$(BUILD)/PHP.OVL:    $(OVL_DIR)/php.ovl.asm     $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay PHP..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   PHP.OVL"

$(BUILD)/VB.OVL:     $(OVL_DIR)/vb.ovl.asm      $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay VB..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   VB.OVL"

$(BUILD)/DELPHI.OVL: $(OVL_DIR)/delphi.ovl.asm  $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay DELPHI..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   DELPHI.OVL"

$(BUILD)/JS.OVL:     $(OVL_DIR)/js.ovl.asm      $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay JS..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   JS.OVL"

$(BUILD)/RING0HW.OVL: $(OVL_DIR)/ring0hw.ovl.asm $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling overlay RING0HW (Ring0 Hardware + BIOS)..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   RING0HW.OVL"

$(BUILD)/PONG.OVL:   $(OVL_DIR)/pong.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game PONG..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   PONG.OVL"

$(BUILD)/SNAKE.OVL:  $(OVL_DIR)/snake.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game SNAKE..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   SNAKE.OVL"

$(BUILD)/TETRIS.OVL: $(OVL_DIR)/tetris.ovl.asm  $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game TETRIS..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   TETRIS.OVL"

$(BUILD)/BRKOUT.OVL: $(OVL_DIR)/brkout.ovl.asm  $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game BRKOUT..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   BRKOUT.OVL"

$(BUILD)/INVADE.OVL: $(OVL_DIR)/invade.ovl.asm  $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game INVADE..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   INVADE.OVL"

$(BUILD)/ASTRO.OVL:  $(OVL_DIR)/astro.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game ASTRO..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   ASTRO.OVL"

$(BUILD)/MAZE.OVL:   $(OVL_DIR)/maze.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game MAZE..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   MAZE.OVL"

$(BUILD)/TANKS.OVL:  $(OVL_DIR)/tanks.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game TANKS..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   TANKS.OVL"

$(BUILD)/RACE.OVL:   $(OVL_DIR)/race.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game RACE..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   RACE.OVL"

$(BUILD)/CHESS.OVL:  $(OVL_DIR)/chess.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game CHESS..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   CHESS.OVL"

$(BUILD)/MINE.OVL:   $(OVL_DIR)/mine.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game MINE..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   MINE.OVL"

$(BUILD)/DUNG.OVL:   $(OVL_DIR)/dung.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game DUNG..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   DUNG.OVL"

$(BUILD)/FROG.OVL:   $(OVL_DIR)/frog.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game FROG..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   FROG.OVL"

$(BUILD)/LINES.OVL:  $(OVL_DIR)/lines.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game LINES..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   LINES.OVL"

$(BUILD)/SIMON.OVL:  $(OVL_DIR)/simon.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game SIMON..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   SIMON.OVL"

$(BUILD)/CONN4.OVL:  $(OVL_DIR)/conn4.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game CONN4..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   CONN4.OVL"

$(BUILD)/WORM.OVL:   $(OVL_DIR)/worm.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game WORM..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   WORM.OVL"

$(BUILD)/GOLF.OVL:   $(OVL_DIR)/golf.ovl.asm    $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game GOLF..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   GOLF.OVL"

$(BUILD)/SHOOT.OVL:  $(OVL_DIR)/shoot.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game SHOOT..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   SHOOT.OVL"

$(BUILD)/ROGUE.OVL:  $(OVL_DIR)/rogue.ovl.asm   $(KERN_DIR)/ovl_api.asm | $(BUILD)
        @echo "[NASM] Assembling game ROGUE..."
        $(NASM) $(OVL_FLAGS) -o $@ $<
        @echo "[OK]   ROGUE.OVL"

$(DISK_IMG): $(BOOTSECT_BIN) $(KERNEL_BIN) $(OVL_BINS) | $(BUILD)
        @echo "[PERL] Building FAT12 disk image..."
        $(PERL) $(TOOLS)/mkimage.pl $(BOOTSECT_BIN) $(KERNEL_BIN) $(DISK_IMG) $(OVL_BINS)
        @echo "[OK]   disk.img ready"

$(BUILD):
        mkdir -p $(BUILD)

# ---------------------------------------------------------------------------
# 3-disk installer set
# disk1.img = Disco 1 (setup inicial: SETUP1.OVL + kernel)
# disk2.img = Disco 2 (setup secundário: SETUP2.OVL + kernel)
# disk3.img = Disco 3 (sistema completo, igual a disk.img)
# ---------------------------------------------------------------------------
disks: disk1 disk2 disk3

disk1: $(DISK1_IMG)
disk2: $(DISK2_IMG)
disk3: $(DISK3_IMG)

$(DISK1_IMG): $(BOOTSECT_BIN) $(KERNEL_BIN) $(BUILD)/RING0HW.OVL | $(BUILD)
        @echo "[PERL] Building Installer Disk 1 (ring0 hardware)..."
        $(PERL) $(TOOLS)/mkimage.pl $(BOOTSECT_BIN) $(KERNEL_BIN) $(DISK1_IMG) \
                $(BUILD)/RING0HW.OVL
        @echo "[OK]   disk1.img (Disco 1 - Ring0 Hardware Overlay)"

$(DISK2_IMG): $(BOOTSECT_BIN) $(KERNEL_BIN) $(BUILD)/RING0HW.OVL | $(BUILD)
        @echo "[PERL] Building Installer Disk 2 (ring0 hardware)..."
        $(PERL) $(TOOLS)/mkimage.pl $(BOOTSECT_BIN) $(KERNEL_BIN) $(DISK2_IMG) \
                $(BUILD)/RING0HW.OVL
        @echo "[OK]   disk2.img (Disco 2 - Ring0 Hardware Overlay)"

$(DISK3_IMG): $(DISK_IMG) | $(BUILD)
        @echo "[PKG]  Building Disk 3 (sistema completo)..."
        cp $(DISK_IMG) $(DISK3_IMG)
        @echo "[OK]   disk3.img (Disco 3 - KSDOS Sistema Operacional)"

run: image
        @echo "[QEMU] Booting KSDOS v2.0..."
        mkdir -p /tmp/xdg-runtime
        XDG_RUNTIME_DIR=/tmp/xdg-runtime \
        $(QEMU) \
                -drive format=raw,file=$(DISK_IMG),if=floppy \
                -boot a \
                -m 4 \
                -vga std \
                -display vnc=:0 \
                -no-reboot \
                -name "KSDOS v2.0"

run-sdl: image
        $(QEMU) -fda $(DISK_IMG) -boot a -m 4 -vga std -display sdl -no-reboot

run-serial: image
        $(QEMU) -fda $(DISK_IMG) -boot a -m 4 -nographic -no-reboot

run-disk1: $(DISK1_IMG)
        @echo "[QEMU] Booting KSDOS Installer - Disco 1..."
        mkdir -p /tmp/xdg-runtime
        XDG_RUNTIME_DIR=/tmp/xdg-runtime \
        $(QEMU) -fda $(DISK1_IMG) -boot a -m 4 -vga std -display vnc=:0 -no-reboot -name "KSDOS Setup - Disco 1"

run-disk2: $(DISK2_IMG)
        @echo "[QEMU] Booting KSDOS Installer - Disco 2..."
        mkdir -p /tmp/xdg-runtime
        XDG_RUNTIME_DIR=/tmp/xdg-runtime \
        $(QEMU) -fda $(DISK2_IMG) -boot a -m 4 -vga std -display vnc=:0 -no-reboot -name "KSDOS Setup - Disco 2"

run-disk3: $(DISK3_IMG)
        @echo "[QEMU] Booting KSDOS - Disco 3 (Sistema)..."
        mkdir -p /tmp/xdg-runtime
        XDG_RUNTIME_DIR=/tmp/xdg-runtime \
        $(QEMU) -fda $(DISK3_IMG) -boot a -m 4 -vga std -display vnc=:0 -no-reboot -name "KSDOS v2.0 - Sistema"

# ---------------------------------------------------------------------------
# deploy: package disk.img + Raspberry Pi scripts into ksdos-watch.tar.gz
# ---------------------------------------------------------------------------
deploy: image disks
        @echo "[PKG]  Building Raspberry Pi deployment package (3 discos)..."
        rm -rf $(DEPLOY_DIR)
        mkdir -p $(DEPLOY_DIR)
        cp $(DISK_IMG)  $(DEPLOY_DIR)/disk.img
        cp $(DISK1_IMG) $(DEPLOY_DIR)/disk1.img
        cp $(DISK2_IMG) $(DEPLOY_DIR)/disk2.img
        cp $(DISK3_IMG) $(DEPLOY_DIR)/disk3.img
        cp $(RASPBERRY)/setup.sh $(DEPLOY_DIR)/setup.sh
        cp $(RASPBERRY)/launch.sh $(DEPLOY_DIR)/launch.sh
        cp $(RASPBERRY)/ksdos-watch.service $(DEPLOY_DIR)/ksdos-watch.service
        chmod +x $(DEPLOY_DIR)/setup.sh $(DEPLOY_DIR)/launch.sh
        tar -czf $(DEPLOY_TAR) -C $(BUILD) ksdos-watch
        @echo "[OK]   $(DEPLOY_TAR)"
        @echo ""
        @echo "Transfer to your Raspberry Pi:"
        @echo "  scp $(DEPLOY_TAR) pi@<pi-ip>:~/"
        @echo "  ssh pi@<pi-ip> 'tar xzf ksdos-watch.tar.gz && sudo bash ksdos-watch/setup.sh'"
        @echo ""
        @echo "3-disk installer:"
        @echo "  disk1.img  ->  Disco 1 (setup inicial)"
        @echo "  disk2.img  ->  Disco 2 (arquivos do sistema)"
        @echo "  disk3.img  ->  Disco 3 (KSDOS sistema operacional)"

clean:
        rm -rf $(BUILD)
help:
        @echo "KSDOS Build System - 16-bit Real Mode OS"
        @echo "========================================="
        @echo ""
        @echo "Targets:"
        @echo "  all / image   - Build disk.img completo (default)"
        @echo "  disks         - Gera os 3 discos do instalador"
        @echo "  disk1         - Build disk1.img (Disco 1 - setup inicial)"
        @echo "  disk2         - Build disk2.img (Disco 2 - arquivos do sistema)"
        @echo "  disk3         - Build disk3.img (Disco 3 - sistema operacional)"
        @echo "  run           - Boot KSDOS em QEMU (VNC)"
        @echo "  run-disk1     - Boot Disco 1 (instalador) em QEMU"
        @echo "  run-disk2     - Boot Disco 2 (arquivos) em QEMU"
        @echo "  run-disk3     - Boot Disco 3 (sistema) em QEMU"
        @echo "  run-sdl       - Boot KSDOS (janela SDL)"
        @echo "  run-serial    - Boot KSDOS sem display"
        @echo "  deploy        - Pacote Raspberry Pi (inclui 3 discos)"
        @echo "  clean         - Remove diretório de build"
        @echo ""
        @echo "Fluxo de instalação (3 discos estilo MS-DOS):"
        @echo "  1. Boot com disk1.img -> Setup inicial, componentes, formatação"
        @echo "  2. Troca para disk2.img -> Cópia de arquivos, configuração"
        @echo "  3. Troca para disk3.img -> KSDOS em uso normal"
        @echo ""
        @echo "Output: $(DISK_IMG) (1.44MB FAT12 floppy)"
        @echo "Overlays: $(OVL_NAMES)"
        @echo ""
        @echo "Raspberry Pi deploy:"
        @echo "  make deploy"
        @echo "  scp $(DEPLOY_TAR) pi@<ip>:~/"
        @echo "  ssh pi@<ip> 'tar xzf ksdos-watch.tar.gz && sudo bash ksdos-watch/setup.sh'"