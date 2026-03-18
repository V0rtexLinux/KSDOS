# KSDOS / Kernel HUB OS - Dev Kit

Repositório de desenvolvimento de sistema operacional x86, contendo dois projetos distintos e sistema de SDK para jogos.

## Estrutura do Projeto

### 1. Bootloader + Kernel KSDOS (`/bootloader`)
Kernel bare-metal para x86 com interface estilo MS-DOS.

- **`bootloader/boot/`** — Stage 1 (MBR): NASM, 16-bit real mode, carrega o core do disco
- **`bootloader/core/`** — Stage 2: configura GDT, A20, entra em protected mode 32-bit e exibe interface
  - `setup.asm` — configura modo de vídeo texto 80x25 (modo 03h), GDT, A20, salta para 32-bit
  - `entry.s` — configura a stack e chama `core_main()`
  - `core.c` — interface MS-DOS estilo KSDOS (VGA text mode 0xB8000)
  - `linker.ld` — layout de memória: setup em 0x7E00, código C em 0x7F00

### 2. Entry HUB Workspace - Cosmos C# (`/COSMOS (C#)`)
Sistema operacional gráfico completo escrito em C# usando o framework Cosmos.

- Versões `1.0.0` e `1.0.1` — GUI com janelas arrastáveis, barra de tarefas, mouse, teclado
- Aplicativos: Notebook (funcional), Date & Time, Calculator, Paint, System Management

### 3. Exemplos (`/examples`)
Scripts NASM educativos para aprender interrupções BIOS e VGA em 16-bit real mode.

### 4. Sistema de SDK (`/sdk`)
Sistema completo para desenvolvimento de jogos PS1 e DOOM usando SDKs locais.

- **`sdk/psyq/`** — PS1 SDK (PSn00bSDK equivalent)
- **`sdk/gold4/`** — DOOM SDK (GNU gold + djgpp)
- **`sdk/sdk-config.bat`** — Script de configuração Windows
- **`sdk/sdk-config.sh`** — Script de configuração Linux/Mac
- **`sdk/detect-sdk.mk`** — Sistema de detecção automática

### 5. Jogos (`/games`)
Templates e exemplos para desenvolvimento de jogos.

- **`games/psx/`** — Template para jogos PS1
- **`games/doom/`** — Template para jogos DOOM/VGA
- **`games/common.mk`** — Configuração compartilhada

## Interface KSDOS (core.c)

A interface estilo MS-DOS exibe:
1. **Sequência de boot** — mensagens rolando ("Starting KSDOS...", drivers, etc.)
2. **Shell KSDOS** — tela final com:
   - Header: `KSDOS Version 1.0`
   - Copyright
   - Banner: `*** WELCOME BACK TO KSDOS ***`
   - Informações do sistema
   - Prompt `C:\>` com cursor hardware piscando

### Tecnologia de Display
- Modo VGA texto 80x25 (modo 03h) — idêntico ao MS-DOS
- Memória de vídeo em `0xB8000`
- Cursor hardware via portas I/O `0x3D4` / `0x3D5`

## Build

### Sistema Operacional
```bash
make build-bootloader       # compila boot.bin + core.bin
make -B build-bootloader    # força recompilação completa
```

### Sistema de SDK
```bash
make configure-sdk          # configura ambiente SDKs
make build-games           # compila todos os jogos
```

### Jogos Individuais
```bash
# PS1 Game
cd games/psx
make psx-game

# DOOM Game  
cd games/doom
make doom-game
```

Output: `build/boot.bin` + `build/core.bin`  
Para testar: `qemu-system-i386 -drive format=raw,file=build/boot.bin`

## Sistema de SDK para Jogos

O KSDOS inclui um sistema completo para desenvolvimento de jogos usando SDKs locais:

### Configuração Automática
- **Windows**: Execute `sdk\sdk-config.bat`
- **Linux/Mac**: Execute `sdk/sdk-config.sh`

### SDKs Disponíveis
- **PS1 SDK** (`sdk/psyq/`) - Desenvolvimento PlayStation 1
- **DOOM SDK** (`sdk/gold4/`) - Desenvolvimento DOOM/VGA

### Detecção Automática
O sistema detecta automaticamente os SDKs e configura variáveis de ambiente:
- `PS1_SDK`, `DOOM_SDK` - Paths dos SDKs
- `PS1_INC`, `DOOM_INC` - Diretórios de includes
- `PS1_LIB`, `DOOM_LIB` - Diretórios de bibliotecas

### Templates de Jogos
Use os templates em `games/` para novos projetos:
```makefile
PROJECT_NAME = meu-jogo
PLATFORM = PS1  # ou DOOM
include ../common.mk
```

Para mais detalhes, veja `sdk/README.md`.

## Toolchain
- NASM (bootloader ASM)
- GCC `-m32 -ffreestanding` (kernel C)
- GNU ld `-m elf_i386`
