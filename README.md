# KSDOS / Entry HUB OS - Dev Kit

Repositório de desenvolvimento de sistema operacional x86, contendo dois projetos distintos.

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

```bash
make build-bootloader       # compila boot.bin + core.bin
make -B build-bootloader    # força recompilação completa
```

Output: `build/boot.bin` + `build/core.bin`  
Para testar: `qemu-system-i386 -drive format=raw,file=build/boot.bin`

## Toolchain
- NASM (bootloader ASM)
- GCC `-m32 -ffreestanding` (kernel C)
- GNU ld `-m elf_i386`
