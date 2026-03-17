# Ferramentas
AS      = nasm
CC      = gcc
LD      = ld
ASM     = as

# Diretórios
BOOT_DIR  = bootloader/boot
CORE_DIR  = bootloader/core
BUILD_DIR = build
CORE_BUILD_DIR = $(BUILD_DIR)/core

# Saídas
BOOT_BIN  = $(BUILD_DIR)/boot.bin
CORE_BIN  = $(BUILD_DIR)/core.bin
OS_IMAGE  = $(BUILD_DIR)/ksdos.img

# Flags de Compilação
# -m32 e -march=i386 para compatibilidade total x86
CFLAGS  = -m32 -march=i386 -ffreestanding -fno-pic -fno-pie -fno-stack-protector -nostdlib -Wall -Wextra -I$(CORE_DIR)
ASFLAGS = --32
LDFLAGS = -m elf_i386 -T $(CORE_DIR)/linker.ld -no-pie

# Mapeamento de Objetos
CORE_ASM_SOURCES := $(CORE_DIR)/entry.s
CORE_ASM_OBJECTS := $(patsubst $(CORE_DIR)/%.s, $(CORE_BUILD_DIR)/%.o, $(CORE_ASM_SOURCES))

CORE_C_SOURCES   := $(CORE_DIR)/core.c
CORE_C_OBJECTS   := $(patsubst $(CORE_DIR)/%.c, $(CORE_BUILD_DIR)/%.o, $(CORE_C_SOURCES))

.PHONY: all clean image

all: image

# 1. Compila o Bootloader (Setor 0)
$(BOOT_BIN): $(BOOT_DIR)/boot.asm
	@mkdir -p $(BUILD_DIR)
	$(AS) -f bin -I$(BOOT_DIR)/ $< -o $@

# 2. Compila o Setup/Early (se o arquivo existir)
$(CORE_BUILD_DIR)/early.bin: $(CORE_DIR)/setup.asm
	@mkdir -p $(CORE_BUILD_DIR)
	$(AS) -f bin $< -o $@

# 3. Compilação dos arquivos de código (.s e .c)
$(CORE_BUILD_DIR)/%.o: $(CORE_DIR)/%.s
	@mkdir -p $(CORE_BUILD_DIR)
	$(ASM) $(ASFLAGS) $< -o $@

$(CORE_BUILD_DIR)/%.o: $(CORE_DIR)/%.c
	@mkdir -p $(CORE_BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# 4. Linkagem do Core
# IMPORTANTE: Como seu linker.ld tem OUTPUT_FORMAT("binary"), 
# o LD já gera o binário final. O objcopy não é necessário aqui.
$(CORE_BIN): $(CORE_ASM_OBJECTS) $(CORE_C_OBJECTS)
	@mkdir -p $(BUILD_DIR)
	$(LD) $(LDFLAGS) $^ -o $(CORE_BUILD_DIR)/after.bin
	
	# Verifica se existe early.bin para concatenar, senão usa apenas o after.bin
	@if [ -f $(CORE_BUILD_DIR)/early.bin ]; then \
		cat $(CORE_BUILD_DIR)/early.bin $(CORE_BUILD_DIR)/after.bin > $@; \
	else \
		cp $(CORE_BUILD_DIR)/after.bin $@; \
	fi
	# Trunca para exatos 10 setores (5120 bytes)
	truncate -s 5120 $@

# 5. Gera a Imagem de Disco Final
image: $(BOOT_BIN) $(CORE_BIN)
	@echo "--- Criando $(OS_IMAGE) ---"
	dd if=/dev/zero of=$(OS_IMAGE) bs=512 count=2880
	dd if=$(BOOT_BIN) of=$(OS_IMAGE) conv=notrunc
	dd if=$(CORE_BIN) of=$(OS_IMAGE) seek=1 conv=notrunc
	@echo "Build finalizado com sucesso!"

clean:
	rm -rf $(BUILD_DIR)
