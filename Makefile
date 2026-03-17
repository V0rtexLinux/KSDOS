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

# Flags (Adicionado -m32 e -march=i386 para compatibilidade)
CFLAGS = -m32 -ffreestanding -fno-stack-protector -nostdlib -I$(CORE_DIR)
LDFLAGS = -m elf_i386 -T $(CORE_DIR)/linker.ld

.PHONY: all clean image dirs

all: image

dirs:
	@mkdir -p $(BUILD_DIR)

# 1. Compila o Bootloader (Sintaxe Intel - NASM)
$(BOOT_BIN): dirs
	$(AS) -f bin -I$(BOOT_DIR)/ $(BOOT_DIR)/boot.asm -o $(BOOT_BIN)

# 2. Compila o Core (Sintaxe AT&T e C - GCC)
$(CORE_BIN): dirs
	# Compila o assembly entry.s usando o GCC (as)
	$(CC) $(CFLAGS) -c $(CORE_DIR)/entry.s -o $(BUILD_DIR)/entry.o
	# Compila o core.c
	$(CC) $(CFLAGS) -c $(CORE_DIR)/core.c -o $(BUILD_DIR)/core.o
	# Linka e gera o binário final
	$(LD) $(LDFLAGS) $(BUILD_DIR)/entry.o $(BUILD_DIR)/core.o -o $(BUILD_DIR)/core.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/core.elf $(CORE_BIN)

# 3. Gera a Imagem Final
image: $(BOOT_BIN) $(CORE_BIN)
	@echo "--- Criando ksdos.img ---"
	dd if=/dev/zero of=$(OS_IMAGE) bs=512 count=2880
	dd if=$(BOOT_BIN) of=$(OS_IMAGE) conv=notrunc
	dd if=$(CORE_BIN) of=$(OS_IMAGE) seek=1 conv=notrunc
	@echo "Build finalizado!"

clean:
	rm -rf $(BUILD_DIR)
