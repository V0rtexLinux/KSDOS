# Configurações de Compilação
AS = nasm
CC = gcc
LD = ld
OBJCOPY = objcopy

# Diretórios de Origem
BOOT_SRC = bootloader/boot
CORE_SRC = bootloader/core
BUILD_DIR = build

# Arquivos de Saída
BOOT_BIN = $(BUILD_DIR)/boot.bin
CORE_BIN = $(BUILD_DIR)/core.bin
OS_IMAGE = $(BUILD_DIR)/ksdos.img

.PHONY: all clean image dirs

# Alvo principal
all: image

# 1. Cria o diretório de build
dirs:
	@mkdir -p $(BUILD_DIR)

# 2. Compila o Bootloader (ajuste o nome do .asm se necessário)
$(BOOT_BIN): dirs
	$(AS) -f bin $(BOOT_SRC)/boot.asm -o $(BOOT_BIN)

# 3. Compila o Core (Kernel)
$(CORE_BIN): dirs
	$(AS) -f bin $(CORE_SRC)/core.asm -o $(CORE_BIN)

# 4. Gera a Imagem Final de 1.44MB
image: $(BOOT_BIN) $(CORE_BIN)
	@echo "--- Gerando ksdos.img ---"
	# Cria arquivo vazio (floppy 1.44MB)
	dd if=/dev/zero of=$(OS_IMAGE) bs=512 count=2880
	# Grava bootloader no setor 0
	dd if=$(BOOT_BIN) of=$(OS_IMAGE) conv=notrunc
	# Grava core a partir do setor 1
	dd if=$(CORE_BIN) of=$(OS_IMAGE) seek=1 conv=notrunc
	@echo "Build concluído: $(OS_IMAGE)"

clean:
	rm -rf $(BUILD_DIR)
