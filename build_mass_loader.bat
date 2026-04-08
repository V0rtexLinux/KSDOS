@echo off
echo Building KSDOS with mass loader support...

REM Build the mass loader first
echo Assembling mass_loader.asm...
nasm -f bin -o mass_loader.bin bootloader\kernel\mass_loader.asm

REM Build the kernel with mass loader support
echo Assembling KERNEL.asm...
nasm -f bin -o kernel.bin bootloader\kernel\KERNEL.asm

REM Build the boot sector with mass loading
echo Assembling BOOT.ASM...
nasm -f bin -o boot.bin bootloader\boot\BOOT.ASM

echo Creating bootable disk...
create-bootable.bat

echo Build complete!
echo The system now supports:
echo - Mass loading of all project files during boot
echo - Overlay system with memory-based file access
echo - Recursive directory scanning
echo - Automatic file type detection
pause
