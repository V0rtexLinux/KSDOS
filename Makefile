# ============================================================
# KSDOS - Top-level Makefile
# ============================================================

ifeq ($(OS),Windows_NT)
    MKDIR = if not exist "$(subst /,\,$(1))" mkdir "$(subst /,\,$(1))"
else
    MKDIR = mkdir -p $(1)
endif

BUILD_DIR ?= build
override BUILD_DIR := $(abspath $(BUILD_DIR))

export CROSS_TOOLCHAIN CC LD BUILD_DIR MKDIR

# SDK paths
PS1_SDK  ?= $(abspath sdk/psyq)
DOOM_SDK ?= $(abspath sdk/gold4)
export PS1_SDK DOOM_SDK

.PHONY: image build-bootloader build-games configure-sdk clean help

# ── Primary target: ELF kernel + bootable image ───────────────
image: build-bootloader
	@echo "[KSDOS] Kernel ELF: $(BUILD_DIR)/ksdos.elf"
	@echo "[KSDOS] To run:  make run"

# Verify the Multiboot header is present (requires grub-file if available)
verify:
	@if command -v grub-file >/dev/null 2>&1; then \
	    grub-file --is-x86-multiboot $(BUILD_DIR)/ksdos.elf && \
	    echo "Multiboot header: OK" || echo "Multiboot header: NOT FOUND"; \
	else \
	    echo "grub-file not available — skipping verification"; \
	fi

# Launch in QEMU using the -kernel flag (native Multiboot support)
run: image
	mkdir -p /tmp/xdg-runtime
	XDG_RUNTIME_DIR=/tmp/xdg-runtime DISPLAY=:0 \
	qemu-system-i386 \
	    -kernel $(BUILD_DIR)/ksdos.elf \
	    -vga std \
	    -display sdl \
	    -m 256

# ── Sub-targets ───────────────────────────────────────────────
build-bootloader:
	$(call MKDIR, $(BUILD_DIR))
	$(MAKE) -C ./bootloader/core

build-games:
	@echo "Building PS1 game..."
	$(MAKE) -C ./games/psx psx-game
	@echo "Building DOOM game..."
	$(MAKE) -C ./games/doom doom-game

configure-sdk:
	@if [ -f "sdk/sdk-config.sh" ]; then \
	    bash "sdk/sdk-config.sh"; \
	else \
	    echo "SDK configuration script not found."; \
	fi

clean:
	rm -rf $(BUILD_DIR)

help:
	@echo "KSDOS Build System"
	@echo "=================="
	@echo "Targets:"
	@echo "  image            - Build ELF kernel (Multiboot-compatible)"
	@echo "  run              - Build and launch in QEMU"
	@echo "  verify           - Check Multiboot header (needs grub-file)"
	@echo "  build-bootloader - Build kernel only"
	@echo "  build-games      - Build PS1 + DOOM games"
	@echo "  configure-sdk    - Configure SDK environment"
	@echo "  clean            - Remove build artifacts"
	@echo ""
	@echo "SDK paths:"
	@echo "  PS1_SDK  = $(PS1_SDK)"
	@echo "  DOOM_SDK = $(DOOM_SDK)"
