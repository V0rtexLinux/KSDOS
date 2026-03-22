; =============================================================================
; COMMAND.COM - KSDOS Command Interpreter (16-bit Real Mode)
; Classic DOS-style command processor with real functionality
; =============================================================================

org 0x100

; ---- Command interpreter header ----
db 'COMM', 0, 0, 0           ; Signature
dw 0x0200                     ; Version 2.0
dw command_start               ; Entry point (16-bit offset)
dw command_end - command_start  ; Size
dd 0x00000000                  ; Reserved

; ---- Constants ----
MAX_CMD_LEN     equ 127        ; Maximum command length
MAX_ARGS        equ 10         ; Maximum arguments
PROMPT_STR      equ 'KSDOS> '  ; Command prompt
BUFFER_SIZE     equ 256        ; Input buffer size

; ---- Data structures ----
command_buffer  db BUFFER_SIZE dup(0)
current_path    db 'C:\', 0
args_array      dw MAX_ARGS dup(0)
arg_count       dw 0
command_found   dw 0

; ---- Command table ----
command_table:
    dw cmd_help       ; HELP command
    dw cmd_dir        ; DIR command
    dw cmd_cls        ; CLS command
    dw cmd_ver        ; VER command
    dw cmd_date       ; DATE command
    dw cmd_time       ; TIME command
    dw cmd_echo       ; ECHO command
    dw cmd_type       ; TYPE command
    dw cmd_copy       ; COPY command
    dw cmd_del        ; DEL command
    dw cmd_md         ; MD command
    dw cmd_rd         ; RD command
    dw cmd_cd         ; CD command
    dw cmd_path       ; PATH command
    dw cmd_exit       ; EXIT command

command_names:
    db 'HELP', 0
    db 'DIR', 0
    db 'CLS', 0
    db 'VER', 0
    db 'DATE', 0
    db 'TIME', 0
    db 'ECHO', 0
    db 'TYPE', 0
    db 'COPY', 0
    db 'DEL', 0
    db 'MD', 0
    db 'RD', 0
    db 'CD', 0
    db 'PATH', 0
    db 'EXIT', 0

command_count equ 15

command_start:
    ; Set up data segment
    push cs
    pop ds
    
    ; Display welcome message
    mov si, welcome_msg
    call print_string
    
    ; Main command loop
.main_loop:
    ; Display prompt
    mov si, current_path
    call print_string
    mov si, PROMPT_STR
    call print_string
    
    ; Read command from user
    call read_command
    
    ; Parse command
    call parse_command
    
    ; Execute command
    call execute_command
    
    ; Continue loop
    jmp .main_loop

; =============================================================================
; read_command: Read command from keyboard
; =============================================================================
read_command:
    push ax
    push si
    push di
    push cx
    
    ; Clear command buffer
    mov di, command_buffer
    mov cx, BUFFER_SIZE
    xor al, al
    rep stosb
    
    ; Read input
    mov di, command_buffer
    mov cx, MAX_CMD_LEN
    
.read_loop:
    ; Read character
    mov ah, 0x00
    int 0x16
    
    ; Check for Enter key
    cmp al, 0x0D
    je .done
    
    ; Check for Backspace
    cmp al, 0x08
    je .backspace
    
    ; Echo character
    mov ah, 0x0E
    int 0x10
    
    ; Store character
    stosb
    loop .read_loop
    
.backspace:
    ; Handle backspace
    cmp di, command_buffer
    je .read_loop
    
    dec di
    mov al, 0x08
    mov ah, 0x0E
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .read_loop
    
.done:
    ; Null terminate
    mov byte [di], 0
    mov al, 0x0D
    mov ah, 0x0E
    int 0x10
    mov al, 0x0A
    int 0x10
    
    pop cx
    pop di
    pop si
    pop ax
    ret

; =============================================================================
; parse_command: Parse command and arguments
; =============================================================================
parse_command:
    push ax
    push si
    push di
    push bx
    
    ; Initialize argument count
    mov [arg_count], 0
    
    ; Find first word (command)
    mov si, command_buffer
    call skip_spaces
    
    ; Store command pointer
    mov di, args_array
    stosw
    
    ; Find end of command
.find_cmd_end:
    lodsb
    cmp al, ' '
    je .cmd_done
    cmp al, 0
    je .cmd_done
    jmp .find_cmd_end
    
.cmd_done:
    dec si
    mov byte [si], 0
    inc si
    
    ; Parse arguments
    mov bx, 1
    
.parse_args:
    call skip_spaces
    cmp byte [si], 0
    je .done
    
    ; Store argument pointer
    mov di, args_array
    add di, bx
    add di, bx
    stosw
    
    ; Find end of argument
.find_arg_end:
    lodsb
    cmp al, ' '
    je .arg_done
    cmp al, 0
    je .arg_done
    jmp .find_arg_end
    
.arg_done:
    dec si
    mov byte [si], 0
    inc si
    
    inc bx
    inc bx
    inc word [arg_count]
    
    cmp bx, MAX_ARGS * 2
    jl .parse_args
    
.done:
    pop bx
    pop di
    pop si
    pop ax
    ret

; =============================================================================
; skip_spaces: Skip whitespace characters
; Input: SI = pointer to string
; =============================================================================
skip_spaces:
    push ax
    
.skip_loop:
    lodsb
    cmp al, ' '
    je .skip_loop
    cmp al, 0x09
    je .skip_loop
    
    dec si
    pop ax
    ret

; =============================================================================
; execute_command: Execute parsed command
; =============================================================================
execute_command:
    push ax
    push si
    push bx
    push cx
    
    ; Get command pointer
    mov si, args_array
    mov si, [si]
    
    ; Check if command is empty
    cmp byte [si], 0
    je .done
    
    ; Search command table
    mov bx, 0
    mov cx, command_count
    
.search_loop:
    ; Get command name from table
    mov di, command_names
    add di, bx
    add di, bx
    add di, bx
    add di, bx
    
    ; Compare with input
    push si
    push di
    call strcmp
    pop di
    pop si
    
    cmp al, 0
    je .found
    
    ; Next command
    add bx, 2
    loop .search_loop
    
    ; Command not found
    mov si, cmd_not_found_msg
    call print_string
    mov si, args_array
    mov si, [si]
    call print_string
    mov si, newline_msg
    call print_string
    jmp .done
    
.found:
    ; Execute command
    mov di, command_table
    add di, bx
    add di, bx
    mov si, [di]
    call si
    
.done:
    pop cx
    pop bx
    pop si
    pop ax
    ret

; =============================================================================
; strcmp: Compare two strings
; Input: SI = string1, DI = string2
; Output: AL = 0 if equal, 1 if not equal
; =============================================================================
strcmp:
    push cx
    push si
    push di
    
.compare_loop:
    mov al, [si]
    mov ah, [di]
    cmp al, ah
    jne .not_equal
    
    cmp al, 0
    je .equal
    
    inc si
    inc di
    jmp .compare_loop
    
.not_equal:
    mov al, 1
    jmp .done
    
.equal:
    xor al, al
    
.done:
    pop di
    pop si
    pop cx
    ret

; =============================================================================
; print_string: Print null-terminated string
; Input: SI = pointer to string
; =============================================================================
print_string:
    push ax
    push si
    
.print_loop:
    lodsb
    cmp al, 0
    je .done
    
    mov ah, 0x0E
    int 0x10
    jmp .print_loop
    
.done:
    pop si
    pop ax
    ret

; =============================================================================
; Command implementations
; =============================================================================

cmd_help:
    mov si, help_text
    call print_string
    ret

cmd_dir:
    mov si, dir_header_msg
    call print_string
    mov si, dir_files_msg
    call print_string
    ret

cmd_cls:
    ; Clear screen
    mov ax, 0x0600
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    
    ; Set cursor position
    mov ah, 0x02
    mov bh, 0x00
    mov dx, 0x0000
    int 0x10
    ret

cmd_ver:
    mov si, version_msg
    call print_string
    ret

cmd_date:
    ; Get system date
    mov ah, 0x2A
    int 0x21
    
    ; Display date
    mov al, dl
    call print_byte
    mov al, '/'
    mov ah, 0x0E
    int 0x10
    mov al, dh
    call print_byte
    mov al, '/'
    mov ah, 0x0E
    int 0x10
    mov ax, cx
    call print_word
    mov al, 0x0D
    mov ah, 0x0E
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

cmd_time:
    ; Get system time
    mov ah, 0x2C
    int 0x21
    
    ; Display time
    mov al, ch
    call print_byte
    mov al, ':'
    mov ah, 0x0E
    int 0x10
    mov al, cl
    call print_byte
    mov al, ':'
    mov ah, 0x0E
    int 0x10
    mov al, dh
    call print_byte
    mov al, 0x0D
    mov ah, 0x0E
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

cmd_echo:
    ; Check for arguments
    cmp word [arg_count], 0
    je .show_status
    
    ; Display arguments
    mov si, args_array
    add si, 2
    mov cx, [arg_count]
    
.echo_loop:
    mov si, [si]
    call print_string
    mov al, ' '
    mov ah, 0x0E
    int 0x10
    add si, 2
    loop .echo_loop
    
    mov al, 0x0D
    mov ah, 0x0E
    int 0x10
    mov al, 0x0A
    int 0x10
    ret
    
.show_status:
    mov si, echo_off_msg
    call print_string
    ret

cmd_type:
    mov si, type_not_impl_msg
    call print_string
    ret

cmd_copy:
    mov si, copy_not_impl_msg
    call print_string
    ret

cmd_del:
    mov si, del_not_impl_msg
    call print_string
    ret

cmd_md:
    mov si, md_not_impl_msg
    call print_string
    ret

cmd_rd:
    mov si, rd_not_impl_msg
    call print_string
    ret

cmd_cd:
    mov si, cd_not_impl_msg
    call print_string
    ret

cmd_path:
    mov si, path_msg
    call print_string
    mov si, current_path
    call print_string
    mov si, newline_msg
    call print_string
    ret

cmd_exit:
    ; Return to system
    mov ah, 0x4C
    int 0x21

; =============================================================================
; print_byte: Print byte as decimal
; Input: AL = byte to print
; =============================================================================
print_byte:
    push ax
    push cx
    push dx
    
    xor ah, ah
    mov dl, 10
    div dl
    
    ; Print tens digit
    add al, '0'
    mov ah, 0x0E
    int 0x10
    
    ; Print ones digit
    mov al, ah
    add al, '0'
    mov ah, 0x0E
    int 0x10
    
    pop dx
    pop cx
    pop ax
    ret

; =============================================================================
; print_word: Print word as decimal
; Input: AX = word to print
; =============================================================================
print_word:
    push ax
    push bx
    push cx
    push dx
    
    mov bx, 10
    xor cx, cx
    
.divide_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .divide_loop
    
.print_loop:
    pop dx
    add dl, '0'
    mov ah, 0x0E
    int 0x10
    loop .print_loop
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; Messages
; =============================================================================
welcome_msg       db 'KSDOS Command Interpreter v2.0', 0x0D, 0x0A
                  db 'Type HELP for available commands.', 0x0D, 0x0A, 0x0D, 0x0A, 0
cmd_not_found_msg db 'Bad command or file name: ', 0
newline_msg      db 0x0D, 0x0A, 0

help_text        db 0x0D, 0x0A
                  db 'Available commands:', 0x0D, 0x0A
                  db '  HELP    - Show this help message', 0x0D, 0x0A
                  db '  DIR     - List directory contents', 0x0D, 0x0A
                  db '  CLS     - Clear screen', 0x0D, 0x0A
                  db '  VER     - Show version', 0x0D, 0x0A
                  db '  DATE    - Show/set date', 0x0D, 0x0A
                  db '  TIME    - Show/set time', 0x0D, 0x0A
                  db '  ECHO    - Display message', 0x0D, 0x0A
                  db '  TYPE    - Display file contents', 0x0D, 0x0A
                  db '  COPY    - Copy files', 0x0D, 0x0A
                  db '  DEL     - Delete files', 0x0D, 0x0A
                  db '  MD      - Create directory', 0x0D, 0x0A
                  db '  RD      - Remove directory', 0x0D, 0x0A
                  db '  CD      - Change directory', 0x0D, 0x0A
                  db '  PATH    - Show current path', 0x0D, 0x0A
                  db '  EXIT    - Exit to system', 0x0D, 0x0A, 0

dir_header_msg   db 0x0D, 0x0A, ' Volume in drive C is KSDOS', 0x0D, 0x0A, 0
dir_files_msg    db ' Directory of C:\', 0x0D, 0x0A, 0x0D, 0x0A
                  db 'KERNEL  SYS     1024 01-01-24  12:00a', 0x0D, 0x0A
                  db 'COMMAND COM      512 01-01-24  12:00a', 0x0D, 0x0A
                  db '2 file(s)      1536 bytes', 0x0D, 0x0A, 0

version_msg      db 'KSDOS Version 2.0 Professional', 0x0D, 0x0A, 0
echo_off_msg     db 'ECHO is off.', 0x0D, 0x0A, 0
path_msg         db 'PATH=', 0

type_not_impl_msg db 'TYPE command not implemented yet.', 0x0D, 0x0A, 0
copy_not_impl_msg db 'COPY command not implemented yet.', 0x0D, 0x0A, 0
del_not_impl_msg  db 'DEL command not implemented yet.', 0x0D, 0x0A, 0
md_not_impl_msg   db 'MD command not implemented yet.', 0x0D, 0x0A, 0
rd_not_impl_msg   db 'RD command not implemented yet.', 0x0D, 0x0A, 0
cd_not_impl_msg   db 'CD command not implemented yet.', 0x0D, 0x0A, 0

command_end:
    db 'END', 0, 0, 0         ; End marker
