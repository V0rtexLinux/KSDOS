# KSDOS Mass Loader System

## Overview

The KSDOS Mass Loader System extends the existing overlay functionality to load ALL files and directories from the project into memory during boot time. This provides instant access to any file without disk I/O overhead.

## Features

### 1. Mass File Loading
- **Recursive Directory Scanning**: Automatically scans all directories and subdirectories
- **File Type Detection**: Identifies regular files, directories, and overlay files (.OVL)
- **Memory Management**: Efficiently loads files into memory with proper alignment
- **File Table**: Maintains a comprehensive table of all loaded files

### 2. Enhanced Overlay System
- **Memory-First Access**: Checks if overlay is already loaded in memory before disk access
- **Fallback Support**: Falls back to disk loading if file not found in memory
- **Transparent Integration**: Works with existing overlay API without changes

### 3. Boot Integration
- **Boot-Time Loading**: Loads all project files during the boot process
- **Progress Indication**: Shows loading status during boot
- **Error Handling**: Graceful handling of loading errors

## Memory Layout

```
0x1000:0000 - Kernel code
0x6000 - Shared data area
0x7000 - Overlay buffer (original)
0x8000 - File table (256 entries × 32 bytes = 8KB)
0x9000 - Mass load buffer (16KB)
0xC000 - FAT buffer
0xD200 - Directory buffer
0xF000 - File buffer
```

## File Table Structure

Each entry in the file table (32 bytes):
```
Offset  Size    Description
0x00    11      8.3 filename
0x0B    2       Starting cluster
0x0D    4       File size
0x11    1       File type (0x01=file, 0x02=dir, 0x03=overlay)
0x12    14      Reserved / Load address
```

## API Functions

### mass_scan_project
Scans all directories and builds the file table.
```asm
call mass_scan_project    ; CX = number of files found
```

### mass_load_all_files
Loads all files from the file table into memory.
```asm
mov cx, file_count
call mass_load_all_files
```

### mass_find_overlay
Finds an overlay in the loaded file table.
```asm
mov si, filename_ptr      ; 11-byte filename
call mass_find_overlay    ; DI = load address, CF=set if not found
```

## Usage Examples

### Loading a Specific Overlay
```asm
mov si, overlay_name      ; "NET     OVL"
call ovl_load_run         ; Automatically checks memory first
```

### Accessing Loaded Files
```asm
; Find a file in the mass-loaded table
mov si, filename_ptr
call mass_find_overlay
jc .not_found
; DI now contains the memory address of the file
```

## Configuration

### Constants in mass_loader.asm
```asm
MAX_FILES       equ 256     ; Maximum files to track
FILE_TABLE_SIZE equ 8192    ; Size of file table
FILE_TABLE      equ 0x8000  ; Location of file table
MASS_LOAD_BUF   equ 0x9000  ; Buffer for mass loading
```

## Building

Use the provided build script:
```batch
build_mass_loader.bat
```

Or build manually:
```batch
nasm -f bin -o mass_loader.bin bootloader\kernel\mass_loader.asm
nasm -f bin -o kernel.bin bootloader\kernel\KERNEL.asm
nasm -f bin -o boot.bin bootloader\boot\BOOT.ASM
```

## Integration Notes

1. **Boot Sector**: Modified to call mass loading functions after kernel load
2. **Kernel**: Includes mass_loader.asm and updates ovl_load_run
3. **Overlay System**: Enhanced to check memory before disk access
4. **Compatibility**: Maintains backward compatibility with existing overlays

## Performance Benefits

- **Instant Access**: Files loaded in memory are accessed instantly
- **Reduced I/O**: Minimal disk access after boot
- **Better Responsiveness**: Faster overlay loading and execution
- **Efficient Memory Use**: Proper alignment and compact file table

## Limitations

1. **Memory Constraints**: Limited by available memory (currently ~24KB for files)
2. **File Size**: Very large files may not fit in the load buffer
3. **Static Loading**: Files are loaded once at boot, not dynamically updated

## Future Enhancements

- Dynamic file loading/unloading
- Memory-mapped file access
- File compression support
- Larger memory buffers
- Cache management
