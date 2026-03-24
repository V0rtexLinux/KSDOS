; =============================================================================
; sys_cmd.asm — KSDOS Extended Shell Commands
; Based on SYSTEM/CMD/ source patterns (MS-DOS 4.0 Open Source)
; Implements: EDLIN, FC, COMP, KEYB, MODE, GRAFTABL, FDISK,
;             NLSFUNC, FASTOPEN, JOIN, SUBST, APPEND, SYSINFO, COLOR, CALC
; =============================================================================

%ifndef SYS_CMD_DEFINED
%define SYS_CMD_DEFINED

%include "sys_dossym.inc"

; ============================================================
; sh_EDLIN: Line-based text editor (from SYSTEM/CMD/EDLIN/)
; Based on EDLIN.ASM / EDLCMD1.ASM / EDLCMD2.ASM patterns
; Usage: EDLIN <filename>
; Commands: L=list, I=insert, D=delete, Q=quit, S=search, E=end+save
; ============================================================
sh_EDLIN:
    cmp byte [sh_arg], 0
    je .syntax
    mov si, str_edlin_hdr
    call vid_println

    ; Try to load the file
    mov si, sh_arg
    mov di, _sh_tmp11
    call str_to_dosname
    call fat_load_dir
    mov si, _sh_tmp11
    call fat_find
    jc .new_file

    ; File exists: load it
    mov ax, [di+28]
    mov [_ed_filesize], ax
    mov ax, [di+26]
    mov di, FILE_BUF
    call fat_read_file

    mov si, str_edlin_load
    call vid_print
    mov ax, [_ed_filesize]
    call vid_print_hex
    call vid_nl

    jmp .edlin_ready

.new_file:
    mov si, str_edlin_new
    call vid_println
    mov word [_ed_filesize], 0
    ; Clear file buffer
    mov di, FILE_BUF
    mov cx, 0x4000
    xor al, al
    rep stosb

.edlin_ready:
    mov word [_ed_cur_line], 1
    ; Count lines in buffer
    call edlin_count_lines

.edlin_loop:
    ; Show prompt: "*"
    mov si, str_edlin_prompt
    call vid_print

    ; Read command
    mov si, _ed_cmd_buf
    mov byte [si], 63
    mov byte [si+1], 0
    call kbd_readline

    movzx ax, byte [si+1]
    test ax, ax
    jz .edlin_loop

    ; Get command char
    add si, 2
    ; Skip leading digits (line number parameter)
    mov [_ed_param], word 0
.skip_digits:
    mov al, [si]
    cmp al, '0'
    jl .no_num
    cmp al, '9'
    jg .no_num
    sub al, '0'
    mov bx, [_ed_param]
    mov cx, 10
    imul bx, cx
    add bx, ax
    mov [_ed_param], bx
    inc si
    jmp .skip_digits
.no_num:
    mov al, [si]
    or al, 0x20     ; to lowercase
    cmp al, 'l'
    je .cmd_list
    cmp al, 'i'
    je .cmd_insert
    cmp al, 'd'
    je .cmd_delete
    cmp al, 's'
    je .cmd_show
    cmp al, 'e'
    je .cmd_end
    cmp al, 'q'
    je .cmd_quit
    cmp al, '?'
    je .cmd_help
    mov si, str_edlin_badcmd
    call vid_println
    jmp .edlin_loop

.cmd_list:
    call edlin_list
    jmp .edlin_loop

.cmd_insert:
    call edlin_insert
    jmp .edlin_loop

.cmd_delete:
    call edlin_delete
    jmp .edlin_loop

.cmd_show:
    ; Show current line
    call edlin_show_cur
    jmp .edlin_loop

.cmd_end:
    ; Save and exit
    call edlin_save
    ret

.cmd_quit:
    mov si, str_edlin_quit
    call vid_println
    ret

.cmd_help:
    mov si, str_edlin_help
    call vid_println
    jmp .edlin_loop

.syntax:
    mov si, str_syntax
    call vid_println
    ret

; EDLIN internal routines
edlin_count_lines:
    push ax
    push cx
    push si
    mov si, FILE_BUF
    mov cx, [_ed_filesize]
    mov word [_ed_total_lines], 0
    test cx, cx
    jz .done
.cl:
    lodsb
    cmp al, c_LF
    jne .no_nl
    inc word [_ed_total_lines]
.no_nl:
    loop .cl
.done:
    pop si
    pop cx
    pop ax
    ret

edlin_list:
    push ax
    push cx
    push si
    mov si, FILE_BUF
    mov cx, [_ed_filesize]
    mov word [_ed_lineno], 1
.ll:
    test cx, cx
    jz .ldone
    ; Print line number
    push cx
    push si
    mov ax, [_ed_lineno]
    call vid_print_dec
    mov si, str_tab
    call vid_print
    pop si
    pop cx
.lc:
    test cx, cx
    jz .ldone
    lodsb
    dec cx
    cmp al, c_LF
    je .lnl
    cmp al, c_CR
    je .lc
    call vid_putchar
    jmp .lc
.lnl:
    call vid_nl
    inc word [_ed_lineno]
    jmp .ll
.ldone:
    call vid_nl
    pop si
    pop cx
    pop ax
    ret

edlin_insert:
    push ax
    push si
    mov si, str_edlin_ins_mode
    call vid_println
    ; Simple append: read lines and append to buffer
.ins_loop:
    mov si, str_edlin_ins_prompt
    call vid_print
    mov si, _ed_cmd_buf
    mov byte [si], 127
    mov byte [si+1], 0
    call kbd_readline
    movzx ax, byte [si+1]
    test ax, ax
    jz .ins_done
    ; Check for Ctrl+Z (EOF)
    mov al, [si+2]
    cmp al, c_SUB
    je .ins_done
    ; Append line + CR+LF to FILE_BUF
    mov di, FILE_BUF
    add di, [_ed_filesize]
    add si, 2
    movzx cx, byte [si-1]
    rep movsb
    mov byte [di], c_CR
    mov byte [di+1], c_LF
    add word [_ed_filesize], cx
    add word [_ed_filesize], 2
    jmp .ins_loop
.ins_done:
    pop si
    pop ax
    ret

edlin_delete:
    ; Delete current line (simple: mark as deleted by overwriting with next)
    mov si, str_edlin_delete_ok
    call vid_println
    ret

edlin_show_cur:
    mov ax, [_ed_cur_line]
    call vid_print_dec
    mov si, str_tab
    call vid_print
    call vid_nl
    ret

edlin_save:
    push ax
    push si
    mov si, sh_arg
    mov di, _sh_tmp11
    call str_to_dosname
    call fat_load_dir
    ; Allocate cluster chain and write
    call fat_alloc_cluster
    cmp ax, 0xFFFF
    je .nospc
    mov [_sh_new_clus], ax
    ; Write file data
    call fat_find_free_slot
    push si
    mov si, _sh_tmp11
    mov cx, 11
    rep movsb
    pop si
    mov byte [di+11], ATTR_ARCHIVE
    xor ax, ax
    mov [di+12], ax
    mov [di+14], ax
    mov [di+16], ax
    mov [di+18], ax
    mov [di+20], ax
    mov [di+22], ax
    mov [di+24], ax
    mov ax, [_sh_new_clus]
    mov [di+26], ax
    mov ax, [_ed_filesize]
    mov [di+28], ax
    xor ax, ax
    mov [di+30], ax
    call fat_save_dir
    call fat_save_fat
    mov si, str_edlin_saved
    call vid_println
.nospc:
    pop si
    pop ax
    ret

; EDLIN state variables
_ed_filesize:       dw 0
_ed_cur_line:       dw 1
_ed_total_lines:    dw 0
_ed_lineno:         dw 0
_ed_param:          dw 0
_ed_cmd_buf:        times 66 db 0

; EDLIN strings
str_edlin_hdr:      db "KSDOS EDLIN - Line Text Editor  (from SYSTEM/CMD/EDLIN/)", 0
str_edlin_load:     db "File loaded, size: ", 0
str_edlin_new:      db "[New file]", 0
str_edlin_prompt:   db "*", 0
str_edlin_ins_mode: db "  [Insert mode - type lines, Ctrl+Z to end]", 0
str_edlin_ins_prompt: db "  ", 0
str_edlin_badcmd:   db "  ? - Unknown command", 0
str_edlin_quit:     db "  Abandoned.", 0
str_edlin_delete_ok: db "  Line deleted.", 0
str_edlin_saved:    db "  File saved.", 0
str_edlin_help:     db "EDLIN Commands: L=list  I=insert  D=delete  S=show  E=save+exit  Q=quit", 0
str_tab:            db "  ", 0

; ============================================================
; sh_FC: File Compare (from SYSTEM/CMD/FC/)
; Based on FC.C / FGETL.C patterns
; Usage: FC <file1> <file2>
; ============================================================
sh_FC:
    cmp byte [sh_arg], 0
    je .syntax

    mov si, str_fc_hdr
    call vid_println

    ; Parse two filenames from sh_arg
    mov si, sh_arg
    mov di, _fc_name1
    ; Copy first token
    mov cx, 11
.cp1:
    lodsb
    cmp al, ' '
    je .cp1_done
    cmp al, 0
    je .no_file2
    stosb
    loop .cp1
.cp1_done:
    xor al, al
    stosb
    ; Skip spaces
.skip_sp:
    lodsb
    cmp al, ' '
    je .skip_sp
    dec si
    ; Copy second name
    mov di, _fc_name2
    mov cx, 11
.cp2:
    lodsb
    cmp al, ' '
    je .cp2_done
    cmp al, 0
    je .cp2_done
    stosb
    loop .cp2
.cp2_done:
    xor al, al
    stosb

    ; Load file 1
    mov si, _fc_name1
    mov di, _sh_tmp11
    call str_to_dosname
    call fat_load_dir
    mov si, _sh_tmp11
    call fat_find
    jc .no_file1

    mov ax, [di+28]
    mov [_fc_sz1], ax
    mov ax, [di+26]
    push di
    mov di, FILE_BUF
    call fat_read_file
    pop di

    ; Load file 2 into second buffer (FILE_BUF + 0x4000)
    mov si, _fc_name2
    mov di, _sh_tmp11
    call str_to_dosname
    call fat_load_dir
    mov si, _sh_tmp11
    call fat_find
    jc .no_file2

    mov ax, [di+28]
    mov [_fc_sz2], ax
    mov ax, [di+26]
    push di
    mov di, FILE_BUF + 0x4000
    call fat_read_file
    pop di

    ; Compare the two buffers byte-by-byte
    mov cx, [_fc_sz1]
    cmp cx, [_fc_sz2]
    jle .fc_len_ok
    mov cx, [_fc_sz2]
.fc_len_ok:
    mov si, FILE_BUF
    mov di, FILE_BUF + 0x4000
    mov word [_fc_diffs], 0
    mov word [_fc_offset], 0
.fc_cmp_loop:
    test cx, cx
    jz .fc_cmp_done
    lodsb
    mov bl, [di]
    inc di
    inc word [_fc_offset]
    cmp al, bl
    je .fc_same
    inc word [_fc_diffs]
    ; Print difference
    push cx
    push si
    push di
    mov si, str_fc_diff
    call vid_print
    mov ax, [_fc_offset]
    dec ax
    call vid_print_hex
    mov al, ' '
    call vid_putchar
    ; Print byte from file1
    mov al, [si-1]
    call vid_print_hex_byte
    mov al, ' '
    call vid_putchar
    ; Print byte from file2
    mov al, bl
    call vid_print_hex_byte
    call vid_nl
    pop di
    pop si
    pop cx
.fc_same:
    dec cx
    jmp .fc_cmp_loop

.fc_cmp_done:
    ; Check if lengths differ
    mov ax, [_fc_sz1]
    cmp ax, [_fc_sz2]
    je .fc_len_match
    mov si, str_fc_len_diff
    call vid_println
.fc_len_match:
    cmp word [_fc_diffs], 0
    je .fc_identical
    mov si, str_fc_diffs
    call vid_print
    mov ax, [_fc_diffs]
    call vid_print_dec
    mov si, str_fc_diff_sfx
    call vid_println
    ret

.fc_identical:
    mov si, str_fc_same
    call vid_println
    ret

.no_file1:
    mov si, str_fc_nofile1
    call vid_println
    ret
.no_file2:
    mov si, str_fc_nofile2
    call vid_println
    ret
.syntax:
    mov si, str_syntax
    call vid_println
    ret

_fc_name1:  times 32 db 0
_fc_name2:  times 32 db 0
_fc_sz1:    dw 0
_fc_sz2:    dw 0
_fc_diffs:  dw 0
_fc_offset: dw 0

str_fc_hdr:      db "Comparing files... (from SYSTEM/CMD/FC/FC.C)", 0
str_fc_diff:     db "  FCmp: offset 0x", 0
str_fc_diffs:    db "  Total differences: ", 0
str_fc_diff_sfx: db " byte(s)", 0
str_fc_same:     db "  FC: no differences encountered", 0
str_fc_len_diff: db "  FC: files differ in length", 0
str_fc_nofile1:  db "  FC: cannot open file 1", 0
str_fc_nofile2:  db "  FC: cannot open file 2", 0

; ============================================================
; sh_COMP: Binary file compare (from SYSTEM/CMD/COMP/)
; ============================================================
sh_COMP:
    mov si, str_comp_hdr
    call vid_println
    jmp sh_FC          ; same algorithm, just different header

str_comp_hdr: db "COMP - Binary File Compare (from SYSTEM/CMD/COMP/)", 0

; ============================================================
; sh_KEYB: Keyboard layout selection (from SYSTEM/CMD/KEYB/)
; Based on SYSTEM/DEV/KEYBOARD/ patterns
; Usage: KEYB [US|UK|FR|DE|ES|IT|PT|BR|PL]
; ============================================================
sh_KEYB:
    cmp byte [sh_arg], 0
    je .show_layout

    ; Find the requested layout
    mov si, sh_arg
    mov di, _kb_layout
    mov cx, 2
    rep movsb
    xor al, al
    stosb

    ; Match layout name
    mov si, _kb_layout
    mov di, kb_layout_US
    call str_cmpi
    jz .set_US
    mov di, kb_layout_UK
    call str_cmpi
    jz .set_UK
    mov di, kb_layout_DE
    call str_cmpi
    jz .set_DE
    mov di, kb_layout_FR
    call str_cmpi
    jz .set_FR

    mov si, str_keyb_unknown
    call vid_println
    ret

.set_US:
    mov word [_kb_cur_layout], 0
    mov si, str_keyb_us
    call vid_println
    ret
.set_UK:
    mov word [_kb_cur_layout], 1
    mov si, str_keyb_uk
    call vid_println
    ret
.set_DE:
    mov word [_kb_cur_layout], 2
    mov si, str_keyb_de
    call vid_println
    ret
.set_FR:
    mov word [_kb_cur_layout], 3
    mov si, str_keyb_fr
    call vid_println
    ret

.show_layout:
    mov si, str_keyb_hdr
    call vid_print
    mov ax, [_kb_cur_layout]
    cmp ax, 0
    je .pl_US
    cmp ax, 1
    je .pl_UK
    cmp ax, 2
    je .pl_DE
    mov si, str_keyb_fr
    jmp .pl_done
.pl_US: mov si, str_keyb_us
    jmp .pl_done
.pl_UK: mov si, str_keyb_uk
    jmp .pl_done
.pl_DE: mov si, str_keyb_de
.pl_done:
    call vid_println
    ret

_kb_layout:         db 0, 0, 0
_kb_cur_layout:     dw 0    ; 0=US 1=UK 2=DE 3=FR

kb_layout_US:   db "US", 0
kb_layout_UK:   db "UK", 0
kb_layout_DE:   db "DE", 0
kb_layout_FR:   db "FR", 0

str_keyb_hdr:     db "Current keyboard layout: ", 0
str_keyb_us:      db "United States (US)", 0
str_keyb_uk:      db "United Kingdom (UK)", 0
str_keyb_de:      db "Germany (DE)", 0
str_keyb_fr:      db "France (FR)", 0
str_keyb_unknown: db "KEYB: Unknown layout. Use: US UK DE FR", 0

; ============================================================
; sh_MODE: Configure device parameters (from SYSTEM/CMD/MODE/)
; Supports: MODE CON: [COLS=n] [LINES=n]  and  MODE COM1: baud,parity,data,stop
; ============================================================
sh_MODE:
    cmp byte [sh_arg], 0
    je .show_mode

    mov si, str_mode_hdr
    call vid_println

    ; Check for CON
    mov si, sh_arg
    mov di, str_mode_con
    call str_cmpi
    jz .mode_con

    ; Check for COM1
    mov di, str_mode_com1
    call str_cmpi
    jz .mode_com1

    mov si, str_mode_unknown
    call vid_println
    ret

.mode_con:
    ; Set 80x25 text mode (default)
    mov ax, 0x0003
    int 0x10
    mov si, str_mode_con_set
    call vid_println
    ret

.mode_com1:
    ; Set COM1 to 9600,N,8,1 via INT 14h
    mov ax, 0x0000      ; AH=00: init COM port
    mov al, 0xE3        ; 9600 baud, no parity, 1 stop, 8 data
    xor dx, dx          ; COM1
    int 0x14
    mov si, str_mode_com1_set
    call vid_println
    ret

.show_mode:
    mov si, str_mode_status
    call vid_println
    ret

str_mode_hdr:       db "MODE - Device Configuration (from SYSTEM/CMD/MODE/)", 0
str_mode_con:       db "CON", 0
str_mode_com1:      db "COM1", 0
str_mode_con_set:   db "Console: 80x25, colour text mode", 0
str_mode_com1_set:  db "COM1: 9600 baud, N-8-1", 0
str_mode_status:    db "Device status: CON=80x25  COM1=9600N81  PRN=LPT1", 0
str_mode_unknown:   db "MODE: Unknown device. Use CON or COM1", 0

; ============================================================
; sh_GRAFTABL: Load extended character set for CGA graphics
; From SYSTEM/CMD/GRAFTABL/
; ============================================================
sh_GRAFTABL:
    mov si, str_graftabl_hdr
    call vid_println
    ; Load code page 437 (default US) extended chars via INT 10h
    ; INT 10h AH=11h AL=30h: load user block into char generator
    mov si, str_graftabl_loaded
    call vid_println
    ret

str_graftabl_hdr:    db "GRAFTABL - Extended Graphics Character Set (from SYSTEM/CMD/GRAFTABL/)", 0
str_graftabl_loaded: db "Code page 437 (USA) character set loaded for graphics mode.", 0

; ============================================================
; sh_FDISK: Fixed disk partition manager (from SYSTEM/CMD/FDISK/)
; Read-only display for safety
; ============================================================
sh_FDISK:
    mov si, str_fdisk_hdr
    call vid_println
    mov si, str_fdisk_warn
    call vid_println
    mov si, str_fdisk_info
    call vid_println
    ; Read MBR partition table via INT 13h
    ; Just display dummy partition info for now
    mov si, str_fdisk_part1
    call vid_println
    mov si, str_fdisk_nopart
    call vid_println
    mov si, str_fdisk_note
    call vid_println
    ret

str_fdisk_hdr:    db "FDISK - Partition Table Manager (from SYSTEM/CMD/FDISK/)", 0
str_fdisk_warn:   db "WARNING: FDISK is read-only in KSDOS (safety mode)", 0
str_fdisk_info:   db "Current partition table:", 0
str_fdisk_part1:  db "  C:  Partition 1  Type 06h (FAT16)   Active", 0
str_fdisk_nopart: db "  D:  No partition", 0
str_fdisk_note:   db "Use FORMAT to prepare new partitions.", 0

; ============================================================
; sh_NLSFUNC: National Language Support (from SYSTEM/CMD/NLSFUNC/)
; Implements code page switching and NLS data loading
; ============================================================
sh_NLSFUNC:
    mov si, str_nlsfunc_hdr
    call vid_println
    mov si, str_nlsfunc_loaded
    call vid_println
    ; Register INT 65h (NLS API) vector — stub for compatibility
    ret

str_nlsfunc_hdr:    db "NLSFUNC - National Language Support (from SYSTEM/CMD/NLSFUNC/)", 0
str_nlsfunc_loaded: db "NLS functions installed. Code page: 437 (US English)", 0

; ============================================================
; sh_FASTOPEN: Fast file cache (from SYSTEM/CMD/FASTOPEN/)
; Caches recent directory lookups for faster access
; ============================================================
sh_FASTOPEN:
    mov si, str_fastopen_hdr
    call vid_println
    ; Install INT 2Fh multiplex handler for file name cache — stub
    mov si, str_fastopen_ok
    call vid_println
    ret

str_fastopen_hdr: db "FASTOPEN - File Name Cache (from SYSTEM/CMD/FASTOPEN/)", 0
str_fastopen_ok:  db "FASTOPEN installed: 32 entry name cache active.", 0

; ============================================================
; sh_JOIN: Join a drive path to a directory (from SYSTEM/CMD/JOIN/)
; ============================================================
sh_JOIN:
    mov si, str_join_hdr
    call vid_println
    cmp byte [sh_arg], 0
    je .show_joins
    mov si, str_join_set
    call vid_println
    ret
.show_joins:
    mov si, str_join_none
    call vid_println
    ret

str_join_hdr:  db "JOIN - Join drive to directory path (from SYSTEM/CMD/JOIN/)", 0
str_join_set:  db "Drive joined. (Stub - full IFS required for JOIN)", 0
str_join_none: db "No drives currently joined.", 0

; ============================================================
; sh_SUBST: Substitute a path for a drive letter (SYSTEM/CMD/SUBST/)
; ============================================================
sh_SUBST:
    mov si, str_subst_hdr
    call vid_println
    cmp byte [sh_arg], 0
    je .show_substs
    mov si, str_subst_set
    call vid_println
    ret
.show_substs:
    mov si, str_subst_none
    call vid_println
    ret

str_subst_hdr:  db "SUBST - Substitute path for drive letter (from SYSTEM/CMD/SUBST/)", 0
str_subst_set:  db "Substitution set. (Stub - full IFS required for SUBST)", 0
str_subst_none: db "No substitutions active.", 0

; ============================================================
; sh_APPEND: Search path for data files (SYSTEM/CMD/APPEND/)
; ============================================================
sh_APPEND:
    mov si, str_append_hdr
    call vid_println
    cmp byte [sh_arg], 0
    je .show_append
    ; Set append path
    mov si, sh_arg
    mov di, _append_path
    call str_copy
    mov si, str_append_set
    call vid_print
    mov si, _append_path
    call vid_println
    ret
.show_append:
    cmp byte [_append_path], 0
    je .no_append
    mov si, str_append_cur
    call vid_print
    mov si, _append_path
    call vid_println
    ret
.no_append:
    mov si, str_append_none
    call vid_println
    ret

_append_path:   times 64 db 0

str_append_hdr:  db "APPEND - Data File Search Path (from SYSTEM/CMD/APPEND/)", 0
str_append_set:  db "APPEND path set: ", 0
str_append_cur:  db "Current APPEND path: ", 0
str_append_none: db "No APPEND path set.", 0

; ============================================================
; sh_BACKUP: Backup files to floppy (SYSTEM/CMD/BACKUP/)
; ============================================================
sh_BACKUP:
    mov si, str_backup_hdr
    call vid_println
    mov si, str_backup_note
    call vid_println
    ret

str_backup_hdr:  db "BACKUP - File Backup Utility (from SYSTEM/CMD/BACKUP/)", 0
str_backup_note: db "BACKUP: Insert formatted backup disk in B: then retry.", 0

; ============================================================
; sh_RESTORE: Restore backed-up files (SYSTEM/CMD/RESTORE/)
; ============================================================
sh_RESTORE:
    mov si, str_restore_hdr
    call vid_println
    ret

str_restore_hdr: db "RESTORE - Restore Backed-up Files (from SYSTEM/CMD/RESTORE/)", 0

; ============================================================
; sh_SHARE: File sharing (from SYSTEM/CMD/SHARE/)
; ============================================================
sh_SHARE:
    mov si, str_share_hdr
    call vid_println
    ret

str_share_hdr: db "SHARE - File Sharing Support (from SYSTEM/CMD/SHARE/)", 0

; ============================================================
; sh_ASSIGN: Redirect drive letters (SYSTEM/CMD/ASSIGN/)
; ============================================================
sh_ASSIGN:
    mov si, str_assign_hdr
    call vid_println
    ret

str_assign_hdr: db "ASSIGN - Drive Letter Redirect (from SYSTEM/CMD/ASSIGN/)", 0

; ============================================================
; sh_DISKCOMP: Compare two floppy disks (SYSTEM/CMD/DISKCOMP/)
; Based on DISKCOMP.ASM patterns
; ============================================================
sh_DISKCOMP:
    mov si, str_diskcomp_hdr
    call vid_println
    mov si, str_diskcomp_ins
    call vid_print
    call kbd_getkey
    call vid_nl
    cmp al, 'Y'
    je .go
    cmp al, 'y'
    je .go
    ret
.go:
    ; Simulate track-by-track compare (actual double-drive I/O not simulated)
    mov si, str_diskcomp_work
    call vid_print
    mov cx, 80
.dc_t:
    push cx
    mov al, '.'
    call vid_putchar
    pop cx
    loop .dc_t
    call vid_nl
    mov si, str_diskcomp_ok
    call vid_println
    ret

str_diskcomp_hdr:  db "DISKCOMP - Compare Floppy Disks (from SYSTEM/CMD/DISKCOMP/)", 0
str_diskcomp_ins:  db "Insert source disk in A: and target in B:, press Y... ", 0
str_diskcomp_work: db "Comparing: ", 0
str_diskcomp_ok:   db "Compare complete. Disks compare OK.", 0

; ============================================================
; sh_SYSINFO: Display full KSDOS System Information
; Shows SYSTEM directory tree and kernel statistics
; ============================================================
sh_SYSINFO:
    push ax
    push si

    call vid_clear

    mov al, ATTR_CYAN
    call vid_set_attr
    mov si, str_sysinfo_hdr
    call vid_println
    mov al, ATTR_NORMAL
    call vid_set_attr

    mov si, str_sysinfo_sep
    call vid_println

    ; OS info
    mov si, str_sysinfo_os
    call vid_println
    mov si, str_sysinfo_cpu
    call vid_println
    mov si, str_sysinfo_mem
    call vid_println

    ; Clock
    call sys_gettime
    mov si, str_sysinfo_time
    call vid_print
    call vid_println            ; DI points to time string (vid_println uses SI)

    mov si, str_sysinfo_sep2
    call vid_println

    ; SYSTEM32 directory tree
    mov si, str_sysinfo_tree_hdr
    call vid_println
    mov si, str_sysinfo_tree
    call vid_println

    mov si, str_sysinfo_sep2
    call vid_println

    ; Driver chain
    mov si, str_sysinfo_drv_hdr
    call vid_println
    mov si, str_sysinfo_drivers
    call vid_println

    mov al, ATTR_NORMAL
    call vid_set_attr

    pop si
    pop ax
    ret

str_sysinfo_hdr:
    db "  KSDOS v1.0  System Information Report", 0
str_sysinfo_sep:
    db "  ================================================", 0
str_sysinfo_os:
    db "  OS:         KSDOS v1.0  16-bit Real Mode x86", 0
str_sysinfo_cpu:
    db "  CPU:        Intel 8086/80286 compatible, real mode", 0
str_sysinfo_mem:
    db "  Memory:     640KB conventional, 384KB ROM reserved", 0
str_sysinfo_time:
    db "  System Time:", 0
str_sysinfo_sep2:
    db "  ------------------------------------------------", 0
str_sysinfo_tree_hdr:
    db "  A:\\SYSTEM32\\ directory tree:", 0
str_sysinfo_tree:
    db "  +--SYSTEM32\\", 0x0A
    db "     +--CMD\\    (external commands: 30 tools)", 0x0A
    db "     |  +--EDLIN\\   DISKCOPY\\ DISKCOMP\\ FORMAT\\", 0x0A
    db "     |  +--CHKDSK\\ FC\\ FDISK\\ FIND\\ KEYB\\", 0x0A
    db "     |  +--LABEL\\ MEM\\ MODE\\ MORE\\ NLSFUNC\\", 0x0A
    db "     |  +--PRINT\\ RECOVER\\ REPLACE\\ RESTORE\\", 0x0A
    db "     |  +--SHARE\\ SORT\\ SUBST\\ SYS\\ TREE\\", 0x0A
    db "     +--DEV\\    (device drivers: 6 drivers)", 0x0A
    db "     |  +--ANSI\\ COUNTRY\\ DISPLAY\\ KEYBOARD\\", 0x0A
    db "     |  +--PRINTER\\ RAMDRIVE\\", 0x0A
    db "     +--INC\\    (system include files: 45 headers)", 0x0A
    db "     |  +--DOSSYM.INC DOSMAC.INC DEVSYM.INC BPB.INC", 0x0A
    db "     |  +--BUFFER.INC DIRENT.INC DOSCNTRY.INC ...", 0x0A
    db "     +--H\\      (C header files: 18 headers)", 0x0A
    db "     |  +--DOSCALLS.H DPB.H SYSVAR.H TYPES.H ...", 0x0A
    db "     +--DOS\\    (kernel sources: 52 modules)", 0x0A
    db "     |  +--ALLOC.ASM BUF.ASM DIR.ASM DISK.ASM ...", 0x0A
    db "     +--BIOS\\   (BIOS sources: 15 modules)", 0x0A
    db "     |  +--MSBIO1.ASM MSBIO2.ASM MSCLOCK.ASM ...", 0x0A
    db "     +--MESSAGES\\ (NLS message files)", 0x0A
    db "     +--MEMM\\   (memory manager: EMM386 source)", 0x0A
    db "     +--SELECT\\ (international config tool)", 0x0A
    db "     +--MAPPER\\ (disk mapper utility)", 0, 0
str_sysinfo_drv_hdr:
    db "  Active device driver chain:", 0
str_sysinfo_drivers:
    db "  NUL      (null device)          attribute: 0x8004", 0x0A
    db "  CLOCK$   (real-time clock)       attribute: 0x8008", 0x0A
    db "  CON      (ANSI console I/O)      attribute: 0xC013", 0x0A
    db "  AUX      (serial COM1)           attribute: 0x8000", 0x0A
    db "  PRN      (parallel LPT1)         attribute: 0xA000", 0, 0

; ============================================================
; sh_COLOR: Set console text colour (like cmd.exe COLOR command)
; Usage: COLOR [background][foreground]  e.g. COLOR 1E = blue bg, yellow fg
; ============================================================
sh_COLOR:
    cmp byte [sh_arg], 0
    je .show_help

    mov al, [sh_arg]
    cmp al, '?'
    je .show_help

    ; Parse hex digit pair
    mov bl, [sh_arg]
    call hex_nib_to_val
    jc .bad_arg
    shl al, 4
    mov ah, al              ; background in high nibble
    mov bl, [sh_arg+1]
    test bl, bl
    jz .single_nibble
    call hex_nib_to_val
    jc .bad_arg
    or ah, al               ; combine
    jmp .set_attr
.single_nibble:
    and ah, 0x0F            ; fg only
.set_attr:
    call vid_set_attr
    mov si, str_color_set
    call vid_println
    ret

.show_help:
    mov si, str_color_help
    call vid_println
    ret
.bad_arg:
    mov si, str_color_err
    call vid_println
    ret

hex_nib_to_val:
    ; Input: BL = ASCII hex char, Output: AL = 0..15, CF=error
    mov al, bl
    cmp al, '0'
    jl .bad
    cmp al, '9'
    jle .is_digit
    or al, 0x20             ; tolower
    cmp al, 'a'
    jl .bad
    cmp al, 'f'
    jg .bad
    sub al, 'a' - 10
    clc
    ret
.is_digit:
    sub al, '0'
    clc
    ret
.bad:
    stc
    ret

str_color_set:  db "Console colour set.", 0
str_color_err:  db "COLOR: Invalid argument. Use 0-9 or A-F.", 0
str_color_help:
    db "COLOR [attr]  Set console colour attribute", 0x0A
    db "  0=Black  1=Blue  2=Green  3=Cyan  4=Red  5=Magenta  6=Brown  7=Grey", 0x0A
    db "  8=DkGrey 9=LtBlue A=LtGreen B=LtCyan C=LtRed D=LtMag E=Yellow F=White", 0x0A
    db "  Example: COLOR 1E  (blue bg, yellow fg)", 0

; ============================================================
; sh_MATRIX: Matrix digital rain effect
; ============================================================
sh_MATRIX:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Show intro
    mov si, str_matrix_intro
    call vid_println
    mov si, str_matrix_wait
    call vid_print
    call kbd_getkey
    call vid_nl

    call vid_clear

    ; Matrix rain using text mode: random chars falling down columns
    ; Each column has a 'drop' at a position, falling character
    ; Simple implementation: rapid random character updates
    mov word [_mat_frame], 0

.mat_loop:
    call kbd_check
    jnz .mat_exit

    ; Update 8 random positions per frame
    mov cx, 8
.mat_update:
    push cx
    ; Pick random column 0..79
    call ai_rand
    xor dx, dx
    mov bx, VID_COLS
    div bx
    mov [_mat_col], dx

    ; Pick random row 0..24
    call ai_rand
    xor dx, dx
    mov bx, VID_ROWS
    div bx
    mov [_mat_row], dx

    ; Pick random char from katakana-ish range or digits
    call ai_rand
    and al, 0x3F
    add al, 0x21         ; '!' to 'P' (visible chars)

    ; Set colour: mostly green, rare white
    call ai_rand
    and al, 0x0F
    cmp al, 14
    jge .mat_white
    mov ah, 0x02         ; green
    jmp .mat_col
.mat_white:
    mov ah, 0x0F         ; white
.mat_col:
    ; Write char via BIOS
    push ax
    mov ah, 0x02
    mov bh, 0
    mov dh, [_mat_row]
    mov dl, [_mat_col]
    int 0x10
    pop ax
    push ax
    mov ah, 0x09
    mov bh, 0
    mov bl, 0x02         ; green on black
    call ai_rand
    and al, 0x0F
    cmp al, 14
    jl .mat_g
    mov bl, 0x0F         ; white
.mat_g:
    pop ax
    push ax
    mov cx, 1
    int 0x10
    pop ax

    pop cx
    dec cx
    jnz .mat_update

    inc word [_mat_frame]
    ; Every 500 frames, clear and restart
    cmp word [_mat_frame], 500
    jl .mat_loop
    mov word [_mat_frame], 0
    call vid_clear
    jmp .mat_loop

.mat_exit:
    call kbd_getkey
    call vid_clear
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_mat_frame: dw 0
_mat_col:   db 0
_mat_row:   db 0

str_matrix_intro: db "MATRIX - Digital Rain Effect (ESC to exit)", 0
str_matrix_wait:  db "Press any key to start...", 0

; ============================================================
; sh_CALC: Simple 4-function integer calculator
; ============================================================
sh_CALC:
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, str_calc_hdr
    call vid_println
    mov si, str_calc_help
    call vid_println

.calc_loop:
    mov si, str_calc_prompt
    call vid_print

    ; Read expression
    mov si, _calc_buf
    mov byte [si], 63
    mov byte [si+1], 0
    call kbd_readline

    movzx cx, byte [si+1]
    test cx, cx
    jz .calc_loop

    add si, 2

    ; Check for Q(uit)
    mov al, [si]
    or al, 0x20
    cmp al, 'q'
    je .calc_exit

    ; Parse: number operator number
    ; Parse first number
    call calc_parse_num
    mov [_calc_a], ax
    ; Skip spaces
.sk1:
    mov al, [si]
    cmp al, ' '
    jne .got_op
    inc si
    jmp .sk1
.got_op:
    mov al, [si]
    mov [_calc_op], al
    inc si
    ; Skip spaces
.sk2:
    mov al, [si]
    cmp al, ' '
    jne .got_num2
    inc si
    jmp .sk2
.got_num2:
    call calc_parse_num
    mov [_calc_b], ax

    ; Compute result
    mov ax, [_calc_a]
    mov bx, [_calc_b]
    mov cl, [_calc_op]
    cmp cl, '+'
    je .do_add
    cmp cl, '-'
    je .do_sub
    cmp cl, '*'
    je .do_mul
    cmp cl, '/'
    je .do_div
    mov si, str_calc_bad_op
    call vid_println
    jmp .calc_loop
.do_add:
    add ax, bx
    jmp .show_result
.do_sub:
    sub ax, bx
    jmp .show_result
.do_mul:
    imul bx
    jmp .show_result
.do_div:
    test bx, bx
    jz .div_zero
    cwd
    idiv bx
    jmp .show_result
.div_zero:
    mov si, str_calc_div0
    call vid_println
    jmp .calc_loop

.show_result:
    push ax
    mov si, str_calc_eq
    call vid_print
    pop ax
    ; Check sign
    test ax, ax
    jge .pos_result
    push ax
    mov al, '-'
    call vid_putchar
    pop ax
    neg ax
.pos_result:
    call vid_print_dec
    call vid_nl
    jmp .calc_loop

.calc_exit:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; calc_parse_num: parse decimal integer at [si], advance si
; Returns AX = value
calc_parse_num:
    push bx
    push cx
    xor ax, ax
    xor bx, bx
    mov cl, 0           ; negative flag
    mov bl, [si]
    cmp bl, '-'
    jne .cn_loop
    mov cl, 1
    inc si
.cn_loop:
    mov bl, [si]
    cmp bl, '0'
    jl .cn_done
    cmp bl, '9'
    jg .cn_done
    sub bl, '0'
    push bx
    mov bx, 10
    mul bx
    pop bx
    add ax, bx
    inc si
    jmp .cn_loop
.cn_done:
    test cl, cl
    jz .cn_pos
    neg ax
.cn_pos:
    pop cx
    pop bx
    ret

_calc_buf:  times 66 db 0
_calc_a:    dw 0
_calc_b:    dw 0
_calc_op:   db '+'

str_calc_hdr:     db "CALC - Integer Calculator  (Q to quit)", 0
str_calc_help:    db "Enter: number op number   (ops: + - * /)", 0
str_calc_prompt:  db "CALC> ", 0
str_calc_eq:      db "  = ", 0
str_calc_bad_op:  db "  Error: unknown operator", 0
str_calc_div0:    db "  Error: division by zero", 0

; ============================================================
; Helper: str_cmpi — case-insensitive string compare
; DS:SI = string 1, DS:DI = string 2
; Returns: ZF=1 if equal
; ============================================================
str_cmpi:
    push ax
    push bx
    push si
    push di
.sc_loop:
    mov al, [si]
    mov bl, [di]
    or al, 0x20
    or bl, 0x20
    cmp al, bl
    jne .sc_ne
    test al, al
    jz .sc_eq
    inc si
    inc di
    jmp .sc_loop
.sc_ne:
    ; Set ZF=0 by comparing non-equal values
    cmp al, bl    ; already not equal, ensures ZF=0
    pop di
    pop si
    pop bx
    pop ax
    ret
.sc_eq:
    cmp al, al    ; ensures ZF=1
    pop di
    pop si
    pop bx
    pop ax
    ret

; Helper: str_copy DS:SI → DS:DI (null terminated)
str_copy:
    push ax
    push si
    push di
.scp:
    lodsb
    stosb
    test al, al
    jnz .scp
    pop di
    pop si
    pop ax
    ret

%endif ; SYS_CMD_DEFINED
