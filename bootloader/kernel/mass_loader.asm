; =============================================================================
; mass_loader.asm - Mass file loader for KSDOS project
; Loads all files and directories from the project into memory with overlay support
; =============================================================================

BITS 16

; ---------------------------------------------------------------------------
; Configuration
; ---------------------------------------------------------------------------
MAX_FILES       equ 256                 ; Maximum files to track
FILE_TABLE_SIZE equ MAX_FILES * 32       ; Each entry: filename(11) + start_cluster(2) + size(4) + type(1) + reserved(14)
FILE_TABLE      equ 0x8000               ; Location of file table
MASS_LOAD_BUF   equ 0x9000               ; Buffer for mass loading (16KB)

; File types
TYPE_FILE       equ 0x01
TYPE_DIR        equ 0x02
TYPE_OVERLAY    equ 0x03

; ---------------------------------------------------------------------------
; File table entry structure
; ---------------------------------------------------------------------------
struc file_entry
    .filename:   resb 11    ; 8.3 format
    .cluster:    resw 1     ; Starting cluster
    .size:       resd 1     ; File size in bytes
    .type:       resb 1     ; File type
    .reserved:   resb 14    ; Future use
endstruc

; ---------------------------------------------------------------------------
; mass_scan_project: Scan all directories and build file table
; Input: None
; Output: CX = number of files found
; ---------------------------------------------------------------------------
mass_scan_project:
    push ax
    push bx
    push dx
    push si
    push di
    push es
    push ds
    
    ; Initialize file table
    mov ax, cs
    mov es, ax
    mov di, FILE_TABLE
    xor cx, cx              ; File counter
    
    ; Start from root directory
    mov word [cur_dir_cluster], 0
    
    ; Scan root directory first
    call mass_scan_directory
    
    ; Now scan subdirectories recursively
    mov si, FILE_TABLE
    mov bx, cx              ; BX = total files found
    
.scan_dirs:
    test bx, bx
    jz .done
    
    dec bx
    mov di, si
    add di, file_entry.type
    mov al, [di]
    cmp al, TYPE_DIR
    jne .next_file
    
    ; This is a directory, scan it
    mov di, si
    add di, file_entry.cluster
    mov ax, [di]
    mov word [cur_dir_cluster], ax
    call mass_scan_directory
    
.next_file:
    add si, file_entry_size
    jmp .scan_dirs
    
.done:
    mov cx, ax              ; Return file count
    pop ds
    pop es
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; mass_scan_directory: Scan current directory and add entries to file table
; Input: [cur_dir_cluster] = directory cluster
; Output: AX = number of new files added
; ---------------------------------------------------------------------------
mass_scan_directory:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov ax, cs
    mov es, ax
    mov di, FILE_TABLE
    add di, [file_count]    ; Point to next free entry
    xor ax, ax              ; New files counter
    
    ; Load directory into DIR_BUF
    mov word [cur_dir_cluster], 0
    call fat_load_dir
    jc .done
    
    ; Scan directory entries
    mov si, DIR_BUF
    mov cx, 224             ; Max entries per sector
    
.scan_entry:
    mov al, [si]            ; First byte = 0xE5 or 0x00
    test al, al
    jz .done                ; End of directory
    
    cmp al, 0xE5
    je .skip_entry          ; Deleted entry
    
    ; Check if it's a directory or file
    mov al, [si+11]         ; Attributes
    test al, 0x10           ; Directory bit
    jnz .is_directory
    
    ; It's a file - check if it's an overlay
    mov di, si
    add di, 8               ; Check extension
    mov al, [di]
    cmp al, 'O'
    jne .regular_file
    mov al, [di+1]
    cmp al, 'V'
    jne .regular_file
    mov al, [di+2]
    cmp al, 'L'
    jne .regular_file
    
    ; It's an overlay file
    mov byte [es:di+file_entry.type], TYPE_OVERLAY
    jmp .add_entry
    
.is_directory:
    mov byte [es:di+file_entry.type], TYPE_DIR
    jmp .add_entry
    
.regular_file:
    mov byte [es:di+file_entry.type], TYPE_FILE
    
.add_entry:
    ; Copy filename (8.3 format)
    push si
    push di
    mov cx, 11
    rep movsb
    pop di
    pop si
    
    ; Copy cluster and size
    mov ax, [si+26]         ; Starting cluster
    mov [es:di+file_entry.cluster], ax
    
    mov ax, [si+28]         ; File size
    mov [es:di+file_entry.size], ax
    mov ax, [si+30]
    mov [es:di+file_entry.size+2], ax
    
    add di, file_entry_size
    inc ax                  ; Increment file counter
    
.skip_entry:
    add si, 32              ; Next directory entry
    loop .scan_entry
    
.done:
    add [file_count], ax
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; mass_load_all_files: Load all files from file table into memory
; Input: CX = number of files to load
; Output: None
; ---------------------------------------------------------------------------
mass_load_all_files:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov ax, cs
    mov es, ax
    mov si, FILE_TABLE
    mov di, MASS_LOAD_BUF
    xor bx, bx              ; Loaded files counter
    
.load_loop:
    test cx, cx
    jz .done
    
    dec cx
    
    ; Check file type
    mov al, [si+file_entry.type]
    cmp al, TYPE_DIR
    je .skip_file          ; Skip directories
    
    ; Load file into memory
    mov ax, [si+file_entry.cluster]
    push di                 ; Save load address
    call fat_read_file
    pop di                  ; Restore load address
    
    ; Update file entry with load address
    mov [si+file_entry.reserved], di
    
    ; Calculate next load address (align to 512 bytes)
    mov dx, [si+file_entry.size]
    mov ax, [si+file_entry.size+2]
    add ax, dx
    adc ax, 0
    add ax, 511
    and ax, 0xFE00
    add di, ax
    
    inc bx
    
.skip_file:
    add si, file_entry_size
    jmp .load_loop
    
.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; mass_find_overlay: Find an overlay in the loaded file table
; Input: SI = pointer to 11-byte filename
; Output: DI = load address or 0 if not found, CF set if not found
; ---------------------------------------------------------------------------
mass_find_overlay:
    push ax
    push bx
    push cx
    push si
    push di
    push es
    
    mov ax, cs
    mov es, ax
    mov di, FILE_TABLE
    mov cx, [file_count]
    
.search_loop:
    test cx, cx
    jz .not_found
    
    dec cx
    
    ; Compare filename
    push si
    push di
    mov bx, 11
.filename_compare:
    mov al, [si]
    cmp al, [di]
    jne .next_entry
    inc si
    inc di
    dec bx
    jnz .filename_compare
    
    ; Found matching filename
    pop di
    pop si
    mov di, [di+file_entry.reserved]  ; Get load address
    test di, di
    jz .not_found
    clc
    jmp .done
    
.next_entry:
    pop di
    pop si
    add di, file_entry_size
    jmp .search_loop
    
.not_found:
    stc
    
.done:
    pop es
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------------------------------------------------
; Data section
; ---------------------------------------------------------------------------
file_count: dw 0
