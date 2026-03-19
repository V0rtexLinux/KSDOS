# =============================================================================
# KSDOS Build System
# Produces a 1.44MB FAT12 floppy image (disk.img) bootable in QEMU
# =============================================================================

NASM     := nasm
PERL     := perl
QEMU     := qemu-system-i386

BUILD    := build
BOOT_DIR := bootloader/boot
KERN_DIR := bootloader/kernel
TOOLS    := tools

BOOTSECT_SRC := $(BOOT_DIR)/bootsect.asm
KERNEL_SRC   := $(KERN_DIR)/ksdos.asm
MBR_SRC      := $(BOOT_DIR)/mbr.asm

BOOTSECT_BIN := $(BUILD)/bootsect.bin
KERNEL_BIN   := $(BUILD)/ksdos.bin
MBR_BIN      := $(BUILD)/mbr.bin
DISK_IMG     := $(BUILD)/disk.img

.PHONY: all image run run-sdl run-serial clean help

all: image

image: $(DISK_IMG)

$(BOOTSECT_BIN): $(BOOTSECT_SRC) | $(BUILD)
	@echo "[NASM] Assembling boot sector..."
	$(NASM) -f bin -i $(BOOT_DIR)/ -o $@ $<
	@echo "[OK]   bootsect.bin"

$(KERNEL_BIN): $(KERNEL_SRC) | $(BUILD)
	@echo "[NASM] Assembling kernel (KSDOS.SYS)..."
	$(NASM) -f bin -i $(KERN_DIR)/ -o $@ $<
	@echo "[OK]   ksdos.bin"

$(MBR_BIN): $(MBR_SRC) | $(BUILD)
	@echo "[NASM] Assembling MBR..."
	$(NASM) -f bin -i $(BOOT_DIR)/ -o $@ $<
	@echo "[OK]   mbr.bin"

$(DISK_IMG): $(BOOTSECT_BIN) $(KERNEL_BIN) | $(BUILD)
	@echo "[PERL] Building FAT12 disk image..."
	$(PERL) $(TOOLS)/mkimage.pl $(BOOTSECT_BIN) $(KERNEL_BIN) $(DISK_IMG)
	@echo "[OK]   disk.img ready"

$(BUILD):
	mkdir -p $(BUILD)

run: image
	@echo "[QEMU] Booting KSDOS v2.0..."
	mkdir -p /tmp/xdg-runtime
	XDG_RUNTIME_DIR=/tmp/xdg-runtime \
	$(QEMU) \
		-fda $(DISK_IMG) \
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

clean:
	rm -rf $(BUILD)

help:
	@echo "KSDOS Build System - 16-bit Real Mode OS"
	@echo "========================================="
	@echo "Targets:"
	@echo "  all / image   - Build disk.img (default)"
	@echo "  run           - Build and boot in QEMU (VNC)"
	@echo "  run-sdl       - Build and boot (SDL window)"
	@echo "  run-serial    - Boot headless (serial only)"
	@echo "  clean         - Remove build directory"
	@echo ""
	@echo "Output: $(DISK_IMG) (1.44MB FAT12 floppy)"
