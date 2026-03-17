CROSS_TOOLCHAIN ?=
CC = $(CROSS_TOOLCHAIN)gcc
LD = $(CROSS_TOOLCHAIN)ld
OBJCOPY = $(CROSS_TOOLCHAIN)objcopy

BUILD_DIR ?= build
override BUILD_DIR := $(abspath $(BUILD_DIR))

# Nome da imagem final
OS_IMAGE = $(BUILD_DIR)/meu_os.img

export CROSS_TOOLCHAIN CC LD OBJCOPY BUILD_DIR

.PHONY: all clean build-bootloader build-image

# Alvo padrão: cria a imagem completa
all: build-image

build-image: build-bootloader
	@echo "--- Gerando Imagem do Sistema ---"
	# Cria arquivo vazio de 1.44MB (floppy)
	dd if=/dev/zero of=$(OS_IMAGE) bs=512 count=2880
	# Escreve o bootloader no Setor 1 (MBR)
	dd if=$(BUILD_DIR)/boot.bin of=$(OS_IMAGE) conv=notrunc
	# Escreve o core a partir do Setor 2
	dd if=$(BUILD_DIR)/core.bin of=$(OS_IMAGE) seek=1 conv=notrunc
	@echo "Pronto: $(OS_IMAGE)"

build-bootloader:
	@mkdir -p $(BUILD_DIR)
	$(MAKE) -C ./bootloader/boot
	$(MAKE) -C ./bootloader/core

clean:
	rm -rf $(BUILD_DIR)
	$(MAKE) -C ./bootloader/boot clean
	$(MAKE) -C ./bootloader/core clean
