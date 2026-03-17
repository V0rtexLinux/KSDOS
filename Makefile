# Configurações de Ferramentas
CROSS_TOOLCHAIN ?= 
CC = $(CROSS_TOOLCHAIN)gcc
LD = $(CROSS_TOOLCHAIN)ld
OBJCOPY = $(CROSS_TOOLCHAIN)objcopy

# Diretórios
BUILD_DIR ?= $(abspath build)
BOOT_DIR = bootloader/boot
CORE_DIR = bootloader/core

# Nome do arquivo final
OS_IMAGE = $(BUILD_DIR)/ksdos.img

# Exporta para os sub-makefiles
export CROSS_TOOLCHAIN CC LD OBJCOPY BUILD_DIR

.PHONY: all clean dirs build-boot build-core image

all: image

dirs:
	@mkdir -p $(BUILD_DIR)

build-boot: dirs
	$(MAKE) -C $(BOOT_DIR)

build-core: dirs
	$(MAKE) -C $(CORE_DIR)

image: build-boot build-core
	@echo "--- Criando imagem KSDOS ---"
	# Cria disco vazio de 1.44MB
	dd if=/dev/zero of=$(OS_IMAGE) bs=512 count=2880
	# Insere o Bootloader no setor 0 (512 bytes)
	dd if=$(BUILD_DIR)/boot.bin of=$(OS_IMAGE) conv=notrunc
	# Insere o Core a partir do setor 1
	dd if=$(BUILD_DIR)/core.bin of=$(OS_IMAGE) seek=1 conv=notrunc
	@echo "Sucesso: $(OS_IMAGE)"

clean:
	rm -rf $(BUILD_DIR)
	$(MAKE) -C $(BOOT_DIR) clean
	$(MAKE) -C $(CORE_DIR) clean
	$(MAKE) -C ./bootloader/core clean
