@echo off
echo Testing KSDOS compilation...
cd /d "c:\Users\Usuário\Documents\KSDOS\KSDOS\bootloader\kernel"
nasm -f bin -o test.bin ksdos.asm
if %errorlevel% equ 0 (
    echo Compilation SUCCESSFUL!
    del test.bin
) else (
    echo Compilation FAILED!
)
pause
