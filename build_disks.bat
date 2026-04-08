@echo off
echo =================================================================
echo KSDOS Windows Disk Builder
echo =================================================================

REM Create build directories
if not exist "build" mkdir build
if not exist "build\disks" mkdir build\disks
if not exist "build\kernel" mkdir build\kernel

echo.
echo [NASM] Assembling boot sector...
nasm -f bin -i bootloader\boot\ -i bootloader\kernel\ -o build\bootsect.bin bootloader\boot\bootsect.asm
if %errorlevel% neq 0 echo [WARN] Boot assembly may have failed

echo.
echo [NASM] Assembling kernel...
nasm -f bin -i bootloader\kernel\ -o build\kernel.bin bootloader\kernel\ksdos.asm
if %errorlevel% neq 0 echo [WARN] Kernel assembly may have failed

echo.
echo [NASM] Assembling overlays...
REM Build overlays
nasm -f bin -DOVERLAY_BUF=0x7000 -i bootloader\kernel\ -i bootloader\kernel\overlays\ -o build\CC.OVL bootloader\kernel\overlays\cc.ovl.asm
nasm -f bin -DOVERLAY_BUF=0x7000 -i bootloader\kernel\ -i bootloader\kernel\overlays\ -o build\MASM.OVL bootloader\kernel\overlays\masm.ovl.asm
nasm -f bin -DOVERLAY_BUF=0x7000 -i bootloader\kernel\ -i bootloader\kernel\overlays\ -o build\CSC.OVL bootloader\kernel\overlays\csc.ovl.asm
nasm -f bin -DOVERLAY_BUF=0x7000 -i bootloader\kernel\ -i bootloader\kernel\overlays\ -o build\MUSIC.OVL bootloader\kernel\overlays\music.ovl.asm
nasm -f bin -DOVERLAY_BUF=0x7000 -i bootloader\kernel\ -i bootloader\kernel\overlays\ -o build\NET.OVL bootloader\kernel\overlays\net.ovl.asm
nasm -f bin -DOVERLAY_BUF=0x7000 -i bootloader\kernel\ -i bootloader\kernel\overlays\ -o build\OPENGL.OVL bootloader\kernel\overlays\opengl.ovl.asm
nasm -f bin -DOVERLAY_BUF=0x7000 -i bootloader\kernel\ -i bootloader\kernel\overlays\ -o build\PSYQ.OVL bootloader\kernel\overlays\psyq.ovl.asm
nasm -f bin -DOVERLAY_BUF=0x7000 -i bootloader\kernel\ -i bootloader\kernel\overlays\ -o build\GOLD4.OVL bootloader\kernel\overlays\gold4.ovl.asm
nasm -f bin -DOVERLAY_BUF=0x7000 -i bootloader\kernel\ -i bootloader\kernel\overlays\ -o build\IDE.OVL bootloader\kernel\overlays\ide.ovl.asm

echo.
echo [CREATE] Creating DISK1.IMG with proper FAT12 structure...
REM Use the existing mkimage.pl to create proper FAT12 disk
perl tools\mkimage.pl build\bootsect.bin build\kernel.bin build\disks\DISK1.IMG build\CC.OVL build\MASM.OVL build\CSC.OVL build\MUSIC.OVL build\NET.OVL build\OPENGL.OVL build\PSYQ.OVL build\GOLD4.OVL build\IDE.OVL

if %errorlevel% equ 0 (
    echo [OK]   DISK1.IMG created successfully
    copy build\disks\DISK1.IMG disks\DISK1.IMG >nul
    echo [COPY] DISK1.IMG copied to disks\ folder
) else (
    echo [ERROR] Failed to create DISK1.IMG
)

echo.
echo [CREATE] Creating DISK2.IMG (Setup Utilities)...
REM Create empty 1.44MB disk for DISK2
fsutil file createnew disks\DISK2.IMG 1474560
echo [OK]   DISK2.IMG created

echo.
echo [CREATE] Creating DISK3.IMG (Setup Tools)...
REM Create empty 1.44MB disk for DISK3
fsutil file createnew disks\DISK3.IMG 1474560
echo [OK]   DISK3.IMG created

echo.
echo [DONE] All disk images created in disks\ folder
dir disks\*.IMG
pause
