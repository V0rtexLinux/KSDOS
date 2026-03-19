# ============================================================
# KSDOS Core Kernel Makefile
# Builds an ELF32 Multiboot-compatible kernel image
# Reference: https://wiki.osdev.org/Bare_Bones
# ============================================================

CC  ?= gcc
AS  ?= as
LD  ?= ld

# If a cross-compiler prefix is set, use it
ifneq ($(CROSS_TOOLCHAIN),)
    CC  := $(CROSS_TOOLCHAIN)gcc
    AS  := $(CROSS_TOOLCHAIN)as
    LD  := $(CROSS_TOOLCHAIN)ld
endif

# ── C sources ────────────────────────────────────────────────
CORE_C_SOURCES := \
    core.c \
    ksdos-sdk.c \
    game-loader.c \
    opengl.c \
    gl-hardware.c \
    gl-context.c \
    gl-demos.c \
    msdos.c \
    filesystem.c \
    system.c \
    gdt.c \
    idt.c \
    pic.c

CORE_C_OBJECTS := $(patsubst %.c, $(BUILD_DIR)/core/%.o, $(CORE_C_SOURCES))

CORE_C_FLAGS := \
    -Wall \
    -Wextra \
    -ffreestanding \
    -fno-pic \
    -m32 \
    -O2 \
    -std=gnu99

# ── Assembly sources ──────────────────────────────────────────
CORE_ASM_SOURCES := entry.s isr.s
CORE_ASM_OBJECTS := $(patsubst %.s, $(BUILD_DIR)/core/%.o, $(CORE_ASM_SOURCES))

CORE_ASM_FLAGS := --32

# ── Linker flags ──────────────────────────────────────────────
CORE_LD_FLAGS := \
    -Tlinker.ld \
    -m elf_i386 \
    --nostdlib

# ── Targets ───────────────────────────────────────────────────
.PHONY: build

build: $(BUILD_DIR)/ksdos.elf

$(BUILD_DIR)/ksdos.elf: $(CORE_ASM_OBJECTS) $(CORE_C_OBJECTS)
	mkdir -p $(dir $@)
	$(LD) $(CORE_LD_FLAGS) $^ -o $@

$(BUILD_DIR)/core/%.o: %.s
	mkdir -p $(dir $@)
	$(AS) $(CORE_ASM_FLAGS) $< -o $@

$(BUILD_DIR)/core/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) $(CORE_C_FLAGS) -c $< -o $@
