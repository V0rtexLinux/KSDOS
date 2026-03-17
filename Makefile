# Ferramentas
AS = nasm
BUILD_DIR = build

# Diretórios de Origem
BOOT_SRC_DIR = bootloader/boot
CORE_SRC_DIR = bootloader/core

# Arquivos de Saída
BOOT_BIN = $(BUILD_DIR)/boot.bin
CORE_BIN = $(BUILD_DIR)/core.bin
OS_IMAGE = $(BUILD_DIR)/ksdos.img

# Flags do NASM (Inclui as pastas para busca de arquivos .asm)
ASFLAGS = -f bin -i$(BOOT_SRC_DIR)/ -i$(CORE_SRC_DIR)/

.PHONY: all clean image dirs

all: image

dirs:
	@mkdir -p $(BUILD_DIR)

# Compila o Bootloader usando as flags de include
$(BOOT_BIN): dirs
	$(AS) $(ASFLAGS) $(BOOT_SRC_DIR)/boot.asm -o $(BOOT_BIN)

# Compila o Core
$(CORE_BIN): dirs
	$(AS) $(ASFLAGS) $(CORE_SRC_DIR)/core.asm -o $(CORE_BIN)

image: $(BOOT_BIN) $(CORE_BIN)
	@echo "--- Gerando ksdos.img ---"
	dd if=/dev/zero of=$(OS_IMAGE) bs=512 count=2880
	dd if=$(BOOT_BIN) of=$(OS_IMAGE) conv=notrunc
	dd if=$(CORE_BIN) of=$(OS_IMAGE) seek=1 conv=notrunc
	@echo "Build concluído: $(OS_IMAGE)"

clean:
	rm -rf $(BUILD_DIR)
