# KSDOS Bootable System

Sistema completo com SDK real e boot menu para desenvolvimento de jogos PS1 e DOOM.

## 🚀 Sistema Implementado

### 1. Meio Bootável
- **Floppy Image** (`ksdos.img`) - 1.44MB bootável
- **CD-ROM ISO** (`ks-dos.iso`) - Bootável via BIOS
- **Hard Disk Image** (`ksdos-hd.img`) - 20MB para desenvolvimento

### 2. SDK Real Integrado
- **PSYq SDK** (PS1) - mipsel-none-elf-gcc 12.3.0
- **GOLD4 SDK** (DOOM) - djgpp + GNU gold linker
- **Detecção automática** de SDKs em `sdk/`
- **Build system** integrado com Makefiles

### 3. Boot Menu Interativo
```
KSDOS Game Loader - Boot Menu
=====================================
1. KSDOS Shell                    Enter KSDOS command shell
2. PS1 Demo                       PlayStation 1 graphics demo
3. DOOM Demo                      DOOM-era raycaster demo  
4. 3D Cube                        OpenGL 3D rotating cube
5. PS1 IDE                        PSYq Engine development IDE
6. DOOM IDE                       GOLD4 Engine development IDE

Press 1-6 to select, or wait for automatic boot
Auto-boot in: 50 seconds
ESC = Boot to KSDOS Shell
```

### 4. Comandos SDK no Shell
```bash
C:\> sdk init          # Inicializa sistema SDK
C:\> sdk build         # Compila projeto atual
C:\> sdk run           # Executa jogo compilado
C:\> sdk status        # Mostra status dos SDKs

C:\> makegame psx      # Build simulado PS1
C:\> makegame doom     # Build simulado DOOM
C:\> playgame psx      # Executa demo PS1
C:\> playgame doom     # Executa demo DOOM
```

## 📁 Estrutura de Arquivos

```
KSDOS/
├── bootloader/
│   ├── boot/boot.asm          # Stage 1 MBR
│   └── core/
│       ├── core.c             # Kernel principal + SDK
│       ├── ksdos-sdk.h        # Header SDK system
│       ├── ksdos-sdk.c        # Implementação SDK real
│       ├── game-loader.c      # Boot menu system
│       ├── entry.s            # Entry point 32-bit
│       └── setup.asm          # Mode setup
├── sdk/
│   ├── psyq/                  # PS1 SDK (PSn00bSDK)
│   ├── gold4/                 # DOOM SDK (GNU gold + djgpp)
│   ├── sdk-config.bat         # Configuração Windows
│   ├── sdk-config.sh          # Configuração Linux/Mac
│   └── detect-sdk.mk          # Detecção automática
├── games/
│   ├── psx/                   # Template jogos PS1
│   ├── doom/                  # Template jogos DOOM
│   └── common.mk              # Build compartilhado
├── create-bootable.bat        # Criação meio bootável (Windows)
├── create-bootable.sh         # Criação meio bootável (Linux/Mac)
└── test-boot.bat              # Teste do sistema
```

## 🔧 Como Usar

### 1. Configurar SDKs
```bash
# Windows
sdk\sdk-config.bat

# Linux/Mac  
sdk/sdk-config.sh
```

### 2. Criar Meio Bootável
```bash
# Windows
create-bootable.bat

# Linux/Mac
./create-bootable.sh
```

### 3. Testar em QEMU
```bash
# Boot via floppy
qemu-system-i386 -drive format=raw,file=ksdos.img -boot a

# Boot via CD-ROM
qemu-system-i386 -cdrom ks-dos.iso -boot d

# Boot via hard disk
qemu-system-i386 -drive format=raw,file=ksdos-hd.img -boot c
```

### 4. Desenvolver Jogos
```bash
# Configurar ambiente
make configure-sdk

# Compilar todos os jogos
make build-games

# Compilar jogo específico
cd games/psx && make psx-game
cd games/doom && make doom-game
```

## 🎮 Recursos do Sistema

### Boot Menu
- **Seleção interativa** de jogos/demos
- **Auto-boot** com countdown de 50 segundos
- **ESC** para boot direto ao shell
- **Detecção automática** de jogos disponíveis

### SDK Integration
- **Real SDK detection** em tempo de boot
- **Build pipeline** simulado com output real
- **Project management** para jogos PS1/DOOM
- **Status monitoring** dos SDKs

### Game Development
- **Templates prontos** para PS1 e DOOM
- **IDE screens** com documentação
- **OpenGL demos** integradas
- **Command history** no shell

## 🛠️ Comandos Disponíveis

### Shell Commands
- `help` - Lista todos os comandos
- `cls` - Limpa tela
- `ver` - Versão do sistema
- `sysinfo` - Informações do hardware
- `exit` - Desliga sistema

### SDK Commands  
- `sdk init` - Inicializa SDKs
- `sdk build` - Compila projeto
- `sdk run` - Executa jogo
- `sdk status` - Status SDKs

### Game Commands
- `makegame psx|doom` - Build simulado
- `playgame psx|doom` - Executa demos
- `engine psx|doom` - IDE screens
- `gl psx|doom|cube` - OpenGL demos

## 📋 Requisitos

### Build Tools
- **NASM** - Assembly bootloader
- **GCC** - Compilação kernel (i386)
- **GNU ld** - Linker
- **make** - Build system

### Runtime
- **QEMU** - Emulação/teste
- **DOSBox-X** - Alternativa
- **Hardware real** - i386+ compatível

## 🚀 Boot Sequence

1. **MBR Load** - Stage 1 bootloader
2. **Core Load** - Kernel 32-bit protected mode  
3. **SDK Detection** - Auto-detect PSYq/GOLD4
4. **Boot Menu** - Seleção interativa
5. **Game Launch** - Executa seleção
6. **Shell Entry** - KSDOS command prompt

## 🎯 Features Técnicas

### Kernel Features
- **32-bit protected mode** 
- **VGA text mode 80x25**
- **Bochs VBE 640x480x32** framebuffer
- **Software OpenGL 1.5** renderer
- **Real-time keyboard** input
- **Command history** system

### SDK Features  
- **Real toolchain integration**
- **Project templates**
- **Build simulation**
- **Error handling**
- **Status reporting**

### Game Features
- **PS1 GPU simulation**
- **DOOM raycaster**
- **3D graphics demos**
- **Sound system ready**
- **Controller input**

---

**KSDOS Game Dev Edition** - Sistema completo para desenvolvimento de jogos retro com SDKs reais e boot menu interativo!
