@echo off
echo =================================================================
echo KSDOS - Check Boot Sector
echo =================================================================

echo Checking first sector of DISK1.IMG...
echo.

REM Check if disk has bootloader (first 512 bytes)
powershell -Command "& {$bytes = [System.IO.File]::ReadAllBytes('disks\DISK1.IMG'); $first512 = [System.Text.Encoding]::ASCII.GetString($bytes[0..511]); Write-Host 'First 512 bytes (ASCII):'; Write-Host $first512}"

echo.
echo Checking for boot signature (0x55AA at end)...
powershell -Command "& {$bytes = [System.IO.File]::ReadAllBytes('disks\DISK1.IMG'); $boot_sig = '{0:X2}{1:X2}' -f $bytes[510], $bytes[511]; Write-Host 'Boot signature: 0x' + $boot_sig; if ($boot_sig -eq '55AA') { Write-Host 'Boot signature OK!' } else { Write-Host 'Boot signature MISSING!' } }"

echo.
echo Checking if DISK1.IMG was created by mkimage.pl...
echo If boot signature is missing, the disk needs proper bootloader.
echo.
pause
