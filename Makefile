# Remove a linha SHELL := sh.exe pois você não o tem instalado
ifeq ($(OS),Windows_NT)
    # Comando para criar pastas de forma segura no Windows
    MKDIR = if not exist "$(subst /,\,$(1))" mkdir "$(subst /,\,$(1))"
else
    MKDIR = mkdir -p $(1)
endif

BUILD_DIR ?= build
override BUILD_DIR := $(abspath $(BUILD_DIR))

export CROSS_TOOLCHAIN CC LD BUILD_DIR MKDIR

# SDK paths
PS1_SDK ?= $(abspath sdk/psyq)
DOOM_SDK ?= $(abspath sdk/gold4)
export PS1_SDK DOOM_SDK

.PHONY: build-bootloader build-games configure-sdk help

build-bootloader:
	$(call MKDIR, $(BUILD_DIR))
	$(MAKE) -C ./bootloader/boot
	$(MAKE) -C ./bootloader/core

# Build all games
build-games:
	@echo "Building PS1 game..."
	$(MAKE) -C ./games/psx psx-game
	@echo "Building DOOM game..."
	$(MAKE) -C ./games/doom doom-game

# Configure SDKs
configure-sdk:
	@echo "Configuring KSDOS SDKs..."
	@if exist "sdk\sdk-config.bat" (
		@call "sdk\sdk-config.bat"
	) else if exist "sdk\sdk-config.sh" (
		@bash "sdk\sdk-config.sh"
	) else (
		@echo "SDK configuration script not found."
	)

# Help target
help:
	@echo "KSDOS Build System"
	@echo "=================="
	@echo "Targets:"
	@echo "  build-bootloader - Build bootloader and kernel"
	@echo "  build-games      - Build all games (PS1 + DOOM)"
	@echo "  configure-sdk    - Configure SDK environment"
	@echo "  help             - Show this help"
	@echo ""
	@echo "Individual game targets:"
	@echo "  psx-game         - Build PS1 game (run in games/psx)"
	@echo "  doom-game        - Build DOOM game (run in games/doom)"
	@echo ""
	@echo "SDK Configuration:"
	@echo "  PS1_SDK  = $(PS1_SDK)"
	@echo "  DOOM_SDK = $(DOOM_SDK)"
