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

# FLAGS CORRIGIDAS:
# -fno-pic e -fno-pie removem a dependência da GLOBAL_OFFSET_TABLE
# -march=i386 garante instruções compatíveis com processadores antigos
CFLAGS = -m32 -march=i386 -ffreestanding -fno-pic -fno-pie -fno-stack-protector -nostdlib -I$(CORE_DIR)
LDFLAGS = -m elf_i386 -T $(CORE_DIR)/linker.ld -no-pie

.PHONY: all clean image dirs

all: image

dirs:
	@mkdir -p $(BUILD_DIR)

# 1. Compila o Bootloader
$(BOOT_BIN): dirs
	$(AS) -f bin -I$(BOOT_DIR)/ $(BOOT_DIR)/boot.asm -o $(BOOT_BIN)

# 2. Compila o Core
$(CORE_BIN): dirs
	# Compila assembly (entry.s)
	$(CC) $(CFLAGS) -c $(CORE_DIR)/entry.s -o $(BUILD_DIR)/entry.o
	# Compila C (core.c)
	$(CC) $(CFLAGS) -c $(CORE_DIR)/core.c -o $(BUILD_DIR)/core.o
	# Linkagem final sem PIE
	$(LD) $(LDFLAGS) $(BUILD_DIR)/entry.o $(BUILD_DIR)/core.o -o $(BUILD_DIR)/core.elf
	$(OBJCOPY) -O binary $(BUILD_DIR)/core.elf $(CORE_BIN)

# 3. Gera a Imagem
image: $(BOOT_BIN) $(CORE_BIN)
	@echo "--- Criando ksdos.img ---"
	dd if=/dev/zero of=$(OS_IMAGE) bs=512 count=2880
	dd if=$(BOOT_BIN) of=$(OS_IMAGE) conv=notrunc
	dd if=$(CORE_BIN) of=$(OS_IMAGE) seek=1 conv=notrunc
	@echo "Build finalizado com sucesso!"

clean:
	rm -rf $(BUILD_DIR)
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
