# Corrigindo "KSDOS.SYS not found" no VirtualBox

O erro ocorre quando o kernel KSDOS.SYS não é incorporado corretamente no disco FAT12 durante a compilação.

## ⚠️ Problema

- O bootloader tenta carregar `KSDOS.SYS` do disco FAT12
- Se o arquivo não está no sistema de arquivos (apenas no espaço "cru"), o bootloader falha

## ✅ Solução - Passo a Passo

### 1. Verifique os Pré-requisitos

Você precisa ter instalado:
- **NASM** (assembler) - http://www.nasm.us/download.html
- **Perl** - ActivePerl ou Strawberry Perl para Windows

Teste no terminal:
```powershell
nasm -version
perl -v
```

### 2. Limpe Compilações Anteriores

Para evitar arquivos antigos conflitantes:
```powershell
cd c:\Users\Usuário\Documents\KSDOS
rmdir /s /q build
mkdir build
```

### 3. Compile o Boot Sector e Kernel

```powershell
# Boot sector (512 bytes)
nasm -f bin -i bootloader/boot/ -o build/bootsect.bin bootloader/boot/bootsect.asm

# Kernel
nasm -f bin -i bootloader/kernel/ -o build/kernel.bin bootloader/kernel/ksdos.asm

# Se houver erros, pare e corrija-os no assembly
```

### 4. Compile os Overlays (Programas do Sistema)

```powershell
$overlays = @("CC", "MASM", "CSC", "MUSIC", "NET", "OPENGL", "PSYQ", "GOLD4", "IDE")

foreach ($ovl in $overlays) {
    $file = "bootloader/kernel/overlays/$($ovl.ToLower()).ovl.asm"
    if (Test-Path $file) {
        $outfile = "build/$ovl.OVL"
        nasm -f bin -DOVERLAY_BUF=0x7000 -i bootloader/kernel/ -i bootloader/kernel/overlays/ -o $outfile $file
        Write-Host "[OK] Compiled $ovl"
    }
}
```

### 5. **CRÍTICO**: Crie a Imagem do Disco com mkimage.pl

Isto é a parte mais importante! O `mkimage.pl` cria a estrutura FAT12 correta:

```powershell
cd c:\Users\Usuário\Documents\KSDOS

# Crie apenas com os arquivos obrigatórios
perl tools/mkimage.pl `
    build/bootsect.bin `
    build/kernel.bin `
    build/disk.img

# Ou com overlays:
perl tools/mkimage.pl `
    build/bootsect.bin `
    build/kernel.bin `
    build/disk.img `
    build/CC.OVL `
    build/MASM.OVL `
    build/CSC.OVL `
    build/MUSIC.OVL `
    build/NET.OVL `
    build/OPENGL.OVL `
    build/PSYQ.OVL `
    build/GOLD4.OVL `
    build/IDE.OVL
```

### 6. Configure o VirtualBox

1. Criação de VM:
   - Tipo: **DOS**
   - Memória: **32 MB minimo**
   - Disco: **Sem** disco rígido (bootará do diskette)

2. Adicione a unidade de disquete:
   - Configurações → Armazenamento
   - Controlador: Disquete
   - Unidade: **Disquete 3.5"**
   - Inserir: Aponte para `build/disk.img`

3. Inicie a VM

### 7. Se Ainda Não Funcionar

**Teste com um script simples:**

```powershell
# PowerShell script: build-and-run.ps1
param(
    [switch]$Run
)

Write-Host "Building KSDOS..." -ForegroundColor Cyan

# Limpar build antigo
if (Test-Path "build") { Remove-Item -Recurse -Force build }
mkdir build | Out-Null

# Compilar
Write-Host "Assembling..." -ForegroundColor Yellow
nasm -f bin -i bootloader/boot/ -o build/bootsect.bin bootloader/boot/bootsect.asm
if ($LASTEXITCODE -ne 0) { Write-Error "Boot assembly failed"; exit 1 }

nasm -f bin -i bootloader/kernel/ -o build/kernel.bin bootloader/kernel/ksdos.asm
if ($LASTEXITCODE -ne 0) { Write-Error "Kernel assembly failed"; exit 1 }

# Criar disco
Write-Host "Creating FAT12 disk image..." -ForegroundColor Yellow
perl tools/mkimage.pl build/bootsect.bin build/kernel.bin build/disk.img

if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS! Image created at: build/disk.img" -ForegroundColor Green
} else {
    Write-Host "FAILED to create disk image" -ForegroundColor Red
    exit 1
}

if ($Run) {
    Write-Host "Opening VirtualBox..." -ForegroundColor Cyan
    & "C:\Program Files\Oracle\VirtualBox\VirtualBox.exe" ksdos &
}
```

**Execução:**
```powershell
# Apenas compilar
.\build-and-run.ps1

# Compilar e abrir VirtualBox
.\build-and-run.ps1 -Run
```

## 🔍 Verificação

Confirme que o `disk.img` foi criado corretamente:
```powershell
ls -la build/disk.img
# Deve ter 1,474,560 bytes (1.44 MB floppy)
```

## 📊 Estrutura FAT12 Correta

```
Setor 0:      Boot sector (bootsect.bin)
Setores 1-9:  FAT1 (File Allocation Table)
Setores 10-18: FAT2 (cópia de backup)
Setores 19-32: Root directory (14 setores)
Setor 33+:    KSDOS.SYS (kernel.bin como arquivo)
```

O `mkimage.pl` cria exatamente isto!

## ⚡ Resumo Rápido (TL;DR)

```powershell
cd c:\Users\Usuário\Documents\KSDOS
rmdir /s /q build
mkdir build

nasm -f bin -i bootloader/boot/ -o build/bootsect.bin bootloader/boot/bootsect.asm
nasm -f bin -i bootloader/kernel/ -o build/kernel.bin bootloader/kernel/ksdos.asm

perl tools/mkimage.pl build/bootsect.bin build/kernel.bin build/disk.img

# Agora associe build/disk.img ao disquete no VirtualBox e inicie!
```

Se continuar com erro, execute `perl tools/mkimage.pl` sem argumentos para ver o uso correto.
