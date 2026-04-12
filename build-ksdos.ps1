#!/usr/bin/env pwsh
<#
.SYNOPSIS
    KSDOS Build & Run Script for Windows
.DESCRIPTION
    Automatically builds KSDOS kernel and creates bootable FAT12 disk image
    Validates each step and provides clear error messages
.PARAMETER Clean
    Remove build directory before compiling
.PARAMETER Run
    Launch VirtualBox with the compiled disk image
.PARAMETER LaunchVM
    Name of VirtualBox VM to launch
.EXAMPLE
    .\build-ksdos.ps1 -Clean -Run -LaunchVM "KSDOS"
#>
param(
    [switch]$Clean,
    [switch]$Run,
    [string]$LaunchVM = "KSDOS"
)

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'

# Colors
$Success = @{ ForegroundColor = "Green"; BackgroundColor = "Black" }
$Error_  = @{ ForegroundColor = "Red";   BackgroundColor = "Black" }
$Warn    = @{ ForegroundColor = "Yellow"; BackgroundColor = "Black" }
$Info    = @{ ForegroundColor = "Cyan";  BackgroundColor = "Black" }

function Write-Success { Write-Host @Success @args }
function Write-Error_  { Write-Host @Error_ @args }
function Write-Warn    { Write-Host @Warn @args }
function Write-Info    { Write-Host @Info @args }

# ============================================================================
# Step 1: Verify prerequisites
# ============================================================================
Write-Info "`n[1/6] Checking prerequisites..."

try {
    $nasm_version = nasm -version 2>&1 | Select-Object -First 1
    Write-Success "  ✓ NASM found: $nasm_version"
} catch {
    Write-Error_ "  ✗ NASM not found. Please install from http://www.nasm.us/download.html"
    exit 1
}

try {
    $perl_version = perl -v 2>&1 | Select-String "version" | Select-Object -First 1
    Write-Success "  ✓ Perl found"
} catch {
    Write-Error_ "  ✗ Perl not found. Please install Strawberry Perl or ActivePerl"
    exit 1
}

# ============================================================================
# Step 2: Clean build directory (optional)
# ============================================================================
Write-Info "`n[2/6] Preparing build directory..."

if ($Clean -or -not (Test-Path "build")) {
    if (Test-Path "build") {
        Write-Warn "  Removing old build directory..."
        Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
    }
    mkdir build | Out-Null
    Write-Success "  ✓ Build directory ready"
} else {
    Write-Warn "  Using existing build directory (use -Clean to rebuild from scratch)"
}

# ============================================================================
# Step 3: Assemble boot sector
# ============================================================================
Write-Info "`n[3/6] Assembling boot sector..."

try {
    nasm -f bin -i bootloader/boot/ -o build/bootsect.bin bootloader/boot/bootsect.asm 2>$null
    
    if (Test-Path "build/bootsect.bin") {
        $size = (Get-Item "build/bootsect.bin").Length
        if ($size -eq 512) {
            Write-Success "  ✓ Boot sector: $size bytes"
        } else {
            Write-Error_ "  ✗ Boot sector has wrong size: $size bytes (expected 512)"
            exit 1
        }
    } else {
        Write-Error_ "  ✗ Boot sector assembly failed"
        exit 1
    }
} catch {
    Write-Error_ "  ✗ Error assembling boot sector: $_"
    exit 1
}

# ============================================================================
# Step 4: Assemble kernel
# ============================================================================
Write-Info "`n[4/6] Assembling kernel (KSDOS.SYS)..."

try {
    nasm -f bin -i bootloader/kernel/ -o build/kernel.bin bootloader/kernel/ksdos.asm 2>$null
    
    if (Test-Path "build/kernel.bin") {
        $size = (Get-Item "build/kernel.bin").Length
        $sectors = [Math]::Ceiling($size / 512)
        Write-Success "  ✓ Kernel: $size bytes ($sectors sectors)"
    } else {
        Write-Error_ "  ✗ Kernel assembly failed"
        exit 1
    }
} catch {
    Write-Error_ "  ✗ Error assembling kernel: $_"
    exit 1
}

# ============================================================================
# Step 5: Create FAT12 disk image
# ============================================================================
Write-Info "`n[5/6] Creating FAT12 disk image..."

try {
    & perl tools/mkimage.pl build/bootsect.bin build/kernel.bin build/disk.img 2>&1 | ForEach-Object {
        if ($_ -match "ERROR|failed") {
            Write-Error_ "  ! $_"
        } elseif ($_ -match "^(Boot|Kernel|usage)") {
            Write-Info "     $_"
        }
    }
    
    if (Test-Path "build/disk.img") {
        $size = (Get-Item "build/disk.img").Length
        if ($size -eq 1474560) {
            Write-Success "  ✓ Disk image created: $size bytes (1.44 MB floppy)"
        } else {
            Write-Error_ "  ✗ Disk image has wrong size: $size bytes (expected 1,474,560)"
            exit 1
        }
    } else {
        Write-Error_ "  ✗ Failed to create disk image"
        exit 1
    }
} catch {
    Write-Error_ "  ✗ Error creating disk image: $_"
    exit 1
}

# ============================================================================
# Step 6: Success & Optional VirtualBox launch
# ============================================================================
Write-Success "`n[6/6] Build complete!`n"
Write-Info "  Image location: $(Resolve-Path build/disk.img)"

if ($Run) {
    Write-Info "`nLaunching VirtualBox..."
    
    # Try to find VirtualBox
    $vbox_paths = @(
        "C:\Program Files\Oracle\VirtualBox\VirtualBox.exe",
        "C:\Program Files (x86)\Oracle\VirtualBox\VirtualBox.exe"
    )
    
    $vbox_exe = $null
    foreach ($path in $vbox_paths) {
        if (Test-Path $path) {
            $vbox_exe = $path
            break
        }
    }
    
    if ($null -eq $vbox_exe) {
        Write-Warn "  ! VirtualBox not found in standard locations"
        Write-Warn "  ! Please manually open: $(Resolve-Path build/disk.img)"
        Write-Info "`n  Steps:"`
        Write-Info "  1. Open VirtualBox"
        Write-Info "  2. Go to VM -> Settings -> Storage"
        Write-Info "  3. Add Floppy Controller with disk: $(Resolve-Path build/disk.img)"
        Write-Info "  4. Start the VM"
    } else {
        Write-Info "  Starting VirtualBox with VM: $LaunchVM"
        Start-Process $vbox_exe -ArgumentList $LaunchVM -NoNewWindow
    }
} else {
    Write-Info "`nNext steps:"
    Write-Info "  1. In VirtualBox: Settings → Storage"
    Write-Info "  2. Add Floppy Controller"
    Write-Info "  3. Attach: $(Resolve-Path build/disk.img)"
    Write-Info "  4. Start the VM"
    Write-Info "`nOr run with -Run flag to auto-launch"
}

Write-Success "`n✓ Success! Your KSDOS disk image is ready.`n"
