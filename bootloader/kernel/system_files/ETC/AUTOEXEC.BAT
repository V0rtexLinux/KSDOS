; =============================================================================
; AUTOEXEC.BAT - KSDOS Startup Commands
; Commands executed during system startup
; =============================================================================

@ECHO OFF
PATH C:\;C:\BIN;C:\SYSTEM32;C:\PROGRAM FILES
SET TEMP=C:\TEMP
SET TMP=C:\TEMP
SET COMSPEC=C:\BIN\CMD.EXE

; KSDOS Environment Variables
SET OS=KSDOS
SET OSVER=2.0
SET WINDIR=C:\WINDOWS
SET SYSTEMROOT=C:\WINDOWS

; Display startup message
ECHO Welcome to KSDOS v2.0 Professional
ECHO System ready for user interaction
ECHO.

; Load additional drivers if needed
REM LOADHIGH C:\DRIVERS\MOUSE.SYS
REM LOADHIGH C:\DRIVERS\NETWORK.SYS

; Start the shell
C:\BIN\CMD.EXE
