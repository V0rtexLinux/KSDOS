# =============================================================================
# KSDOS-GUI Build System
# Separate GUI version with Norton Commander-style interface
# and full MS-DOS directory structure (DOS, IO.SYS, COMMAND.COM, etc.)
# =============================================================================

NASM     := nasm
PERL     := perl
QEMU     := qemu-system-i386

BUILD    := build
BOOT_DIR := bootloader/boot
KERN_DIR := bootloader/kernel
ORIG_DIR := ../bootloader/kernel

BOOTSECT_SRC := $(BOOT_DIR)/bootsect.asm
KERNEL_SRC   := $(KERN_DIR)/ksdos.asm

BOOTSECT_BIN := $(BUILD)/bootsect.bin
KERNEL_BIN   := $(BUILD)/ksdos.bin
DISK_IMG     := $(BUILD)/disk.img

.PHONY: all image run clean help

all: image

image: $(DISK_IMG)

$(BOOTSECT_BIN): $(BOOTSECT_SRC) | $(BUILD)
	@echo "[NASM] Assembling boot sector..."
	$(NASM) -f bin -i $(BOOT_DIR)/ -i $(ORIG_DIR)/../boot/ -o $@ $<
	@echo "[OK]   bootsect.bin"

$(KERNEL_BIN): $(KERNEL_SRC) | $(BUILD)
	@echo "[NASM] Assembling GUI kernel..."
	$(NASM) -f bin -i $(KERN_DIR)/ -i $(ORIG_DIR)/ -o $@ $<
	@echo "[OK]   ksdos.bin"

$(DISK_IMG): $(BOOTSECT_BIN) $(KERNEL_BIN) | $(BUILD)
	@echo "[PERL] Building FAT12 disk image with MS-DOS directory structure..."
	$(PERL) tools/mkimage.pl $(BOOTSECT_BIN) $(KERNEL_BIN) $(DISK_IMG)
	@echo "[OK]   disk.img ready"

$(BUILD):
	mkdir -p $(BUILD)

run: image
	@echo "[QEMU] Booting KSDOS v2.0 GUI..."
	mkdir -p /tmp/xdg-runtime
	XDG_RUNTIME_DIR=/tmp/xdg-runtime \
	$(QEMU) \
		-drive format=raw,file=$(DISK_IMG),if=floppy \
		-boot a \
		-m 4 \
		-vga std \
		-display vnc=:0 \
		-no-reboot \
		-name "KSDOS v2.0 GUI"

clean:
	rm -rf $(BUILD)

help:
	@echo "KSDOS-GUI Build System"
	@echo "======================"
	@echo "Targets:"
	@echo "  all / image  - Build disk.img with GUI (default)"
	@echo "  run          - Build and boot in QEMU (VNC display)"
	@echo "  clean        - Remove build directory"
	@echo ""
	@echo "Output: $(DISK_IMG)"
	@echo ""
	@echo "MS-DOS Directory Structure on disk:"
	@echo "  A:\\           - Root: IO.SYS, KSDOS.SYS, COMMAND.COM,"
	@echo "                          CONFIG.SYS, AUTOEXEC.BAT"
	@echo "  A:\\DOS\\       - DOS utilities: FORMAT, CHKDSK, etc."
