# Ferramentas
AS = nasm
CC = gcc
LD = ld
OBJCOPY = objcopy

# Diretórios
BOOT_DIR = bootloader/boot
CORE_DIR = bootloader/core
BUILD_DIR = build

# Saídas
BOOT_BIN = $(BUILD_DIR)/boot.bin
CORE_BIN = $(BUILD_DIR)/core.bin
OS_IMAGE = $(BUILD_DIR)/ksdos.img

# Flags de Compilação (16-bit)
# -m32 é necessário para gerar código compatível com 16-bit/Real Mode no GCC moderno
CFLAGS = -m32 -ffreestanding -O0 -Wall -Wextra -fno-exceptions -fno-stack-protector -nostdlib -I$(CORE_DIR)
LDFLAGS = -m elf_i386 -T $(CORE_DIR)/linker.ld

.PHONY: all clean image dirs

all: image

dirs:
	@mkdir -p $(BUILD_DIR)

# 1. Compila o Bootloader
$(BOOT_BIN): dirs
	$(AS) -f bin -I$(BOOT_DIR)/ $(BOOT_DIR)/boot.asm -o $(BOOT_BIN)

# 2. Compila o Core (C + Assembly + Linker)
$(CORE_BIN): dirs
	# Compila os objetos
	$(AS) -f elf32 $(CORE_DIR)/entry.s -o $(BUILD_DIR)/entry.o
	$(CC) $(CFLAGS) -c $(CORE_DIR)/core.c -o $(BUILD_DIR)/core.o
	# Linka tudo usando o seu script linker.ld
	$(LD) $(LDFLAGS) $(BUILD_DIR)/entry.o $(BUILD_DIR)/core.o -o $(BUILD_DIR)/core.elf
	# Converte o ELF linkado em binário puro
	$(OBJCOPY) -O binary $(BUILD_DIR)/core.elf $(CORE_BIN)

# 3. Gera a Imagem Final
image: $(BOOT_BIN) $(CORE_BIN)
	@echo "--- Criando ksdos.img ---"
	dd if=/dev/zero of=$(OS_IMAGE) bs=512 count=2880
	dd if=$(BOOT_BIN) of=$(OS_IMAGE) conv=notrunc
	dd if=$(CORE_BIN) of=$(OS_IMAGE) seek=1 conv=notrunc
	@echo "Feito!"

clean:
	rm -rf $(BUILD_DIR)
