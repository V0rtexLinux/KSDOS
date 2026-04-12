# Troubleshooting - KSDOS "not found" Errors

## Sintomas

| Erro | Causa | Solução |
|------|-------|---------|
| `KSDOS.SYS not found` | Kernelnão no FAT12 | Use `mkimage.pl` ✓ |
| `Error loading KSDOS kernel` | Kernel > 64KB | Dividir em overlays |
| `FAT chain corrupted` | Tamanho errado | Verificar `kernel.bin` |
| `Blank screen` | Bootloader inicia, kernel falha | Testar com diskette mínimo |

---

## Problema 1: mkimage.pl não encontrado ou falha

### Solução A: Verificar Perl
```powershell
# Confirme que Perl está instalado
perl -v | Select-Object -First 5

# Se não funcionar, reinstale:
# https://strawberryperl.com (Windows recomendado)
```

### Solução B: Executar mkimage.pl manualmente
```powershell
cd c:\Users\Usuário\Documents\KSDOS

# Teste se funciona
perl tools/mkimage.pl

# Deve exibir uso:
# Usage: perl mkimage.pl <bootsect.bin> <kernel.bin> <output.img> [overlay.OVL ...]
```

### Solução C: Usar caminho completo do Perl
```powershell
# Se o associado padrão não funciona
"C:\Strawberry\perl\bin\perl.exe" tools/mkimage.pl `
    build/bootsect.bin `
    build/kernel.bin `
    build/disk.img
```

---

## Problema 2: Kernel Assembly fail (NASM erro)

### Erro típico: "undefined symbol"
```
Fatal: undefined symbol `xyz'
```

### Solução:
1. **Verifique inclusão de arquivos:**
   ```powershell
   # Certifique-se que bootloader/kernel/ tem os .inc necessários
   dir bootloader/kernel/*.inc
   ```

2. **Limpe cache de NASM:**
   ```powershell
   Remove-Item -Recurse build/
   mkdir build
   ```

3. **Aumente buffer:**
   ```powershell
   # Compilar com mais detalhes
   nasm -f bin -i bootloader/kernel/ -o build/kernel.bin `
       -l build/kernel.lst bootloader/kernel/ksdos.asm
   
   # Checar kernel.lst para erros
   ```

---

## Problema 3: Disco criado mas "não bootável"

### Verificar VirtualBox setup:

**VM Settings → System:**
- Chipset: PIIX3
- Pointing Device: PS/2 Mouse
- Enable IO APIC: **OFF**

**VM Settings → Storage:**
- Controlador: Floppy (não IDE!)
- Dispositivo: Disquete 3.5"
- Imagem: `build/disk.img`

**VM Settings → Boot:**
- Enable EFI: **OFF**
- Boot order: **Floppy Drive** primeiro

### Verificar integridade do disco:

```powershell
# Tamanho exato para floppy 1.44MB
$size = (Get-Item build/disk.img).Length
if ($size -eq 1474560) {
    Write-Host "✓ Tamanho OK (1474560 bytes)"
} else {
    Write-Host "✗ Tamanho errado: $size bytes"
}

# Verificar assinatura boot
$bytes = [System.IO.File]::ReadAllBytes("build/disk.img")
$sig = [System.BitConverter]::ToUInt16($bytes, 510)
if ($sig -eq 0xAA55) {
    Write-Host "✓ Assinatura boot correta (0xAA55)"
} else {
    Write-Host "✗ Assinatura inválida: 0x$($sig.ToString('X4'))"
}
```

---

## Problema 4: Bootloader OK, mas Kernel não carrega (tela preta)

### Causa: Kernel corrompido ou muito grande

1. **Cheque tamanho do kernel:**
   ```powershell
   $size = (Get-Item build/kernel.bin).Length
   $kb = [Math]::Round($size / 1024, 2)
   Write-Host "Kernel size: $kb KB"
   ```

2. **Limite FAT12 é 640KB**, mas kernel típico ≈ 100-200KB

3. **Se > 200KB:**
   - Compile apenas kernel mínimo
   - Mova overlays para discos adicionais
   - Verifique se há código morto para remover

---

## Problema 5: VirtualBox "Read-only disk" ou "Permission denied"

### Solução:
```powershell
# Remova flag read-only
$diskPath = "build/disk.img"
$attr = Get-Item $diskPath | Select -ExpandProperty Attributes
Remove-Item -Path $diskPath
Copy-Item -Path (Get-Item $diskPath).FullName -Destination $diskPath
```

---

## Problema 6: "FAT filesystem not recognized"

### Verificação do mkimage.pl:

Os setores são mapeados assim:
```
Setor 0:       Boot sector
Setores 1-9:   FAT1 (copy 1 da tabela de alocação)
Setores 10-18: FAT2 (copy 2)
Setores 19-32: Root directory
Setor 33+:     Dados (KSDOS.SYS em cluster 2)
```

Se algum passo falhar em `mkimage.pl`, veja:
```powershell
# Executar com debug
perl -d tools/mkimage.pl build/bootsect.bin build/kernel.bin build/disk.img
```

---

## Problema 7: Preciso compilar overlays também

Overlays são programas do sistema (CC, Python, etc). Se quiser incluir:

```powershell
# Criar todos os overlays
$overlays = @(
    "CC", "MASM", "CSC", "MUSIC", "NET", "OPENGL", 
    "PSYQ", "GOLD4", "IDE", "AI"
)

foreach ($ovl in $overlays) {
    $src = "bootloader/kernel/overlays/$($ovl.ToLower()).ovl.asm"
    $out = "build/$ovl.OVL"
    
    if (Test-Path $src) {
        Write-Host "Compiling $ovl..."
        nasm -f bin -DOVERLAY_BUF=0x7000 `
            -i bootloader/kernel/ `
            -i bootloader/kernel/overlays/ `
            -o $out $src
    }
}

# Então incluir no mkimage.pl:
$ovl_args = Get-ChildItem build/*.OVL | ForEach { $_.FullName }
perl tools/mkimage.pl build/bootsect.bin build/kernel.bin build/disk.img @ovl_args
```

---

## Debug: Logs detalhados

### Ver o que mkimage.pl faz:

```powershell
# Capture todo output
$output = &(perl tools/mkimage.pl build/bootsect.bin build/kernel.bin build/disk.img) 2>&1
$output | Out-File mkimage.log
notepad mkimage.log
```

### Analisar boot sector:
```powershell
# Hexdump dos primeiros 512 bytes
$bytes = [System.IO.File]::ReadAllBytes("build/disk.img")
[System.BitConverter]::ToString($bytes[0..63]) -split "-" | 
    ForEach { if ($_ -ne "") { $_.Insert(2, " ") } } | 
    Out-String
```

---

## Última Resort: Usar LiveUSB Linux

Se continuar não funcionando:

```bash
# Em Linux (WSL ou máquina real)
cd /mnt/c/Users/Usuário/Documents/KSDOS

# Build com dd (mais simples)
dd if=/dev/zero of=build/disk.img bs=512 count=2880
dd if=build/bootsect.bin of=build/disk.img bs=512 count=1 conv=notrunc
dd if=build/kernel.bin of=build/disk.img bs=512 seek=2 conv=notrunc
```

---

## Verificação Final

Se tudo estiver correto:

```powershell
# Checklist
Write-Host "Pre-launch checks:"
Write-Host "☐ build/disk.img existe e tem 1474560 bytes"
Write-Host "☐ Bootloader assinatura = 0xAA55"
Write-Host "☐ VirtualBox VM Floppy controller > build/disk.img"
Write-Host "☐ Boot order: Floppy primeiro"
Write-Host "☐ EFI desabilitado"
Write-Host "☐ Kernel assembly sem erros"
```
