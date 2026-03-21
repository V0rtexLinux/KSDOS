; =============================================================================
; gui.asm  -  KSDOS GUI File Manager  (Norton Commander style)
; 16-bit real mode, VGA text mode 80x25, direct VGA memory writes (ES=0xB800)
;
;  Row  0     Title bar         (bright white on blue)
;  Row  1     Path / CWD bar    (yellow on blue)
;  Row  2     ╔═ panel top ═╗
;  Row  3     ║ col headers  ║
;  Row  4     ╠═ separator  ═╣
;  Rows 5-20  ║ file entries  ║   (16 visible at a time)
;  Row 21     ╚═ panel bot  ═╝
;  Row 22     Status bar        (yellow on black)
;  Row 23     CMD: input line   (white on black)
;  Row 24     Function key bar
; =============================================================================

; ── Colour attributes (high nibble=bg, low nibble=fg) ──────────────────────
GUI_TITLE_ATTR  equ 0x1F    ; bright white on blue
GUI_PATH_ATTR   equ 0x1E    ; yellow on blue
GUI_BORDER_ATTR equ 0x1B    ; bright cyan on blue
GUI_HDR_ATTR    equ 0x1E    ; yellow on blue  (column headers)
GUI_NORM_ATTR   equ 0x17    ; light grey on blue   (regular file)
GUI_DIR_ATTR    equ 0x1A    ; bright green on blue  (directory)
GUI_SYS_ATTR    equ 0x1D    ; bright magenta on blue (hidden / system)
GUI_SEL_ATTR    equ 0x70    ; black on light grey   (selected entry)
GUI_STATUS_ATTR equ 0x0E    ; yellow on black
GUI_CMD_ATTR    equ 0x07    ; light grey on black
GUI_CMDP_ATTR   equ 0x0A    ; bright green on black  (CMD: prompt text)
GUI_FK_NUM      equ 0x70    ; black on white   (function-key numbers)
GUI_FK_NAME     equ 0x07    ; light grey on black  (function-key labels)

; ── Panel geometry ──────────────────────────────────────────────────────────
GUI_LIST_FIRST  equ 5       ; first file row
GUI_LIST_LAST   equ 20      ; last  file row
GUI_LIST_ROWS   equ 16      ; rows 5-20 = 16 slots

; ── GUI state ───────────────────────────────────────────────────────────────
gui_scroll:      dw 0       ; index of first visible entry
gui_sel:         dw 0       ; index of selected entry
gui_dir_count:   dw 0       ; total displayable entries

; Pointer table: offset-within-DS for each displayable DIR entry (max 256)
gui_entry_ptrs:  times 256 dw 0

; Decimal scratch (12 bytes, digits written LS-first)
gui_dec_buf:     times 12 db 0

; CMD bar state
gui_cmd_buf:     times 64 db 0
gui_cmd_len:     dw 0

; Temp date word storage for gui_draw_files
gui_date_tmp:    dw 0

; ── String constants ────────────────────────────────────────────────────────
gui_s_title:  db "   KSDOS v2.0  --  GUI File Manager  --  (c) KSDOS Project 2024   ", 0
gui_s_pathpfx:db "  Dir: ", 0
gui_s_hdr:    db " Sel T  Name              Size      Date       Attr ", 0
gui_s_hint:   db "  Arrows=Navigate  Enter=Open  F7=MkDir  F8=Del  F10=Shell  ESC=Clear", 0
gui_s_files:  db " files", 0
gui_s_cmdp:   db "CMD: ", 0
gui_s_dirtag: db "  <DIR> ", 0  ; 8 chars
gui_s_shell:  db "Entering text shell (type EXIT to return).", 0x0A, 0
gui_s_back:   db "  Press any key to return to GUI...", 0
gui_s_delask: db "  Delete file? (Y/N) ", 0
gui_s_mkdpmt: db "  New directory name: ", 0
gui_s_nimpl:  db "  Not implemented in GUI. Use CMD bar or F10.", 0

; Function-key bar: sequence of [attr_byte, text_chars, 0x00], ended by 0x00
gui_fk_data:
    db GUI_FK_NUM,  "1",  0, GUI_FK_NAME, "Help   ", 0
    db GUI_FK_NUM,  "3",  0, GUI_FK_NAME, "View   ", 0
    db GUI_FK_NUM,  "7",  0, GUI_FK_NAME, "MkDir  ", 0
    db GUI_FK_NUM,  "8",  0, GUI_FK_NAME, "Del    ", 0
    db GUI_FK_NUM,  "10", 0, GUI_FK_NAME, "Shell  ", 0
    db 0            ; terminator

; ==========================================================================
; ENTRY POINT: gui_run  (call this instead of shell_run)
; ==========================================================================
gui_run:
    call gui_load_entries

.redraw:
    call gui_draw_all

.keyloop:
    call kbd_getkey         ; AL=ASCII, AH=scancode

    ; ESC = clear CMD buffer
    cmp al, 0x1B
    jne .not_esc
    mov word [gui_cmd_len], 0
    mov byte [gui_cmd_buf], 0
    call gui_draw_cmdline
    jmp .keyloop
.not_esc:

    ; Backspace
    cmp al, 0x08
    jne .not_bs
    call gui_cmd_backspace
    call gui_draw_cmdline
    jmp .keyloop
.not_bs:

    ; Enter
    cmp al, 0x0D
    jne .not_enter
    cmp word [gui_cmd_len], 0
    je .open_entry
    call gui_exec_cmd
    jmp .redraw
.open_entry:
    call gui_open_selected
    jmp .redraw
.not_enter:

    ; Special key prefix (arrows, F-keys)
    test al, al
    jz .special
    cmp al, 0xE0
    je .special2

    ; Printable → CMD buffer
    cmp al, 0x20
    jb .keyloop
    cmp al, 0x7E
    ja .keyloop
    call gui_cmd_append     ; AL = char to append
    call gui_draw_cmdline
    jmp .keyloop

.special:
    ; F-keys
    cmp ah, 0x3B  ; F1 = help
    je .f1
    cmp ah, 0x3D  ; F3 = view
    je .f3
    cmp ah, 0x41  ; F7 = mkdir
    je .f7
    cmp ah, 0x42  ; F8 = delete
    je .f8
    cmp ah, 0x44  ; F10 = shell
    je .f10
    ; Navigation
    cmp ah, 0x48  ; UP arrow
    je .up
    cmp ah, 0x50  ; DOWN arrow
    je .down
    cmp ah, 0x47  ; HOME
    je .home
    cmp ah, 0x4F  ; END
    je .end_key
    jmp .keyloop

.special2:
    call kbd_getkey
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    jmp .keyloop

.up:
    call gui_sel_up
    call gui_draw_files
    call gui_draw_status
    jmp .keyloop

.down:
    call gui_sel_down
    call gui_draw_files
    call gui_draw_status
    jmp .keyloop

.home:
    mov word [gui_sel], 0
    mov word [gui_scroll], 0
    call gui_draw_files
    call gui_draw_status
    jmp .keyloop

.end_key:
    mov ax, [gui_dir_count]
    test ax, ax
    jz .keyloop
    dec ax
    mov [gui_sel], ax
    call gui_ensure_visible
    call gui_draw_files
    call gui_draw_status
    jmp .keyloop

.f1:
    call vid_clear
    call sh_HELP
    mov si, gui_s_back
    call vid_println
    call kbd_getkey
    call gui_load_entries
    jmp .redraw

.f3:
    call gui_view_selected
    jmp .redraw

.f7:
    call gui_do_mkdir
    jmp .redraw

.f8:
    call gui_do_delete
    jmp .redraw

.f10:
    call vid_clear
    mov si, gui_s_shell
    call vid_println
    call shell_run          ; hand off to text shell
    call gui_load_entries   ; if shell_run ever returns
    jmp .redraw

; ── CMD helpers ────────────────────────────────────────────────────────────
gui_cmd_append:
    push bx
    mov bx, [gui_cmd_len]
    cmp bx, 62
    jae .full
    mov [gui_cmd_buf + bx], al
    inc bx
    mov [gui_cmd_len], bx
    mov byte [gui_cmd_buf + bx], 0
.full:
    pop bx
    ret

gui_cmd_backspace:
    push bx
    mov bx, [gui_cmd_len]
    test bx, bx
    jz .done
    dec bx
    mov [gui_cmd_len], bx
    mov byte [gui_cmd_buf + bx], 0
.done:
    pop bx
    ret

; ── gui_exec_cmd: run gui_cmd_buf through sh_dispatch ──────────────────────
gui_exec_cmd:
    push ax
    push bx
    push cx
    push si
    push di
    call vid_clear
    ; copy cmd buf → sh_line
    mov si, gui_cmd_buf
    mov di, sh_line
    mov cx, 127
.cp:
    lodsb
    stosb
    test al, al
    jz .cp_done
    dec cx
    jnz .cp
.cp_done:
    ; parse command word
    mov si, sh_line
    call str_ltrim
    mov di, sh_cmd
    mov cx, 31
    call sh_get_word_uc
    ; parse argument
    call str_ltrim
    mov di, sh_arg
    xor bx, bx
.acp:
    lodsb
    mov [di+bx], al
    test al, al
    jz .acp_done
    inc bx
    jmp .acp
.acp_done:
    mov si, sh_cmd
    call sh_dispatch
    mov si, gui_s_back
    call vid_println
    call kbd_getkey
    mov word [gui_cmd_len], 0
    mov byte [gui_cmd_buf], 0
    call gui_load_entries
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ── gui_open_selected: enter a directory ────────────────────────────────────
gui_open_selected:
    push bx
    push si
    mov ax, [gui_sel]
    cmp ax, [gui_dir_count]
    jae .done
    mov bx, ax
    shl bx, 1
    mov si, [gui_entry_ptrs + bx]
    ; Only handle directories
    test byte [si+11], 0x10
    jz .done
    ; Format name → _sh_namebuf (needs ES=DS temporarily)
    push es
    push di
    mov ax, ds
    mov es, ax
    mov di, _sh_namebuf
    call fat_format_name
    pop di
    pop es
    ; Copy formatted name to sh_arg
    mov si, _sh_namebuf
    mov di, sh_arg
.nc:
    lodsb
    stosb
    test al, al
    jz .nc_done
    jmp .nc
.nc_done:
    call sh_CD
    call gui_load_entries
    mov word [gui_scroll], 0
    mov word [gui_sel], 0
.done:
    pop si
    pop bx
    ret

; ── gui_view_selected: TYPE the selected file ──────────────────────────────
gui_view_selected:
    push bx
    push si
    mov ax, [gui_sel]
    cmp ax, [gui_dir_count]
    jae .done
    mov bx, ax
    shl bx, 1
    mov si, [gui_entry_ptrs + bx]
    test byte [si+11], 0x10
    jnz .done           ; skip directories
    push es
    push di
    mov ax, ds
    mov es, ax
    mov di, _sh_namebuf
    call fat_format_name
    pop di
    pop es
    mov si, _sh_namebuf
    mov di, sh_arg
.nc:
    lodsb
    stosb
    test al, al
    jz .nc_done
    jmp .nc
.nc_done:
    call vid_clear
    call sh_TYPE
    mov si, gui_s_back
    call vid_println
    call kbd_getkey
    call gui_load_entries
.done:
    pop si
    pop bx
    ret

; ── gui_do_mkdir: F7 ────────────────────────────────────────────────────────
gui_do_mkdir:
    push si
    call gui_draw_all
    ; Print prompt in status bar area
    call gui_clear_row22
    mov dh, 22
    mov dl, 2
    call vid_set_cursor
    mov al, ATTR_YELLOW
    call vid_set_attr
    mov si, gui_s_mkdpmt
    call vid_print
    mov al, ATTR_NORMAL
    call vid_set_attr
    ; Use shell readline
    mov si, sh_arg
    mov cx, 12
    call kbd_readline
    cmp byte [sh_arg], 0
    je .done
    call sh_MD
    call gui_load_entries
.done:
    pop si
    ret

; ── gui_do_delete: F8 ───────────────────────────────────────────────────────
gui_do_delete:
    push bx
    push si
    mov ax, [gui_sel]
    cmp ax, [gui_dir_count]
    jae .done
    mov bx, ax
    shl bx, 1
    mov si, [gui_entry_ptrs + bx]
    test byte [si+11], 0x10
    jnz .done           ; skip directories
    ; Show confirm in status bar
    call gui_clear_row22
    mov dh, 22
    mov dl, 2
    call vid_set_cursor
    mov al, ATTR_YELLOW
    call vid_set_attr
    mov si, gui_s_delask
    call vid_print
    mov al, ATTR_NORMAL
    call vid_set_attr
    call kbd_getkey
    cmp al, 'Y'
    je .dodel
    cmp al, 'y'
    je .dodel
    jmp .done
.dodel:
    push es
    push di
    mov ax, ds
    mov es, ax
    mov di, _sh_namebuf
    call fat_format_name
    pop di
    pop es
    mov si, _sh_namebuf
    mov di, sh_arg
.nc:
    lodsb
    stosb
    test al, al
    jz .nc_done
    jmp .nc
.nc_done:
    call sh_DEL
    call gui_load_entries
.done:
    pop si
    pop bx
    ret

; ── gui_clear_row22: clear status bar row 22 using BIOS ────────────────────
gui_clear_row22:
    push ax
    push bx
    push cx
    push dx
    mov ax, 0x0600      ; scroll up = clear
    mov bh, GUI_STATUS_ATTR
    mov cx, (22 << 8) | 0   ; top-left
    mov dx, (22 << 8) | 79  ; bottom-right
    int 0x10
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ==========================================================================
; gui_load_entries: rebuild gui_entry_ptrs from DIR_BUF
; ==========================================================================
gui_load_entries:
    push ax
    push bx
    push cx
    push si
    push di
    call fat_load_dir
    call fat_max_entries    ; CX = number of entry slots
    xor bx, bx              ; valid entry count
    mov si, DIR_BUF
    mov di, gui_entry_ptrs
.scan:
    test cx, cx
    jz .done
    cmp byte [si], 0x00
    je .done                ; end-of-dir marker
    cmp byte [si], 0xE5
    je .skip                ; deleted entry
    test byte [si+11], 0x08
    jnz .skip               ; volume label
    mov al, [si+11]
    and al, 0x0F
    cmp al, 0x0F
    je .skip                ; LFN entry
    ; Valid — store pointer
    mov [di], si
    add di, 2
    inc bx
    cmp bx, 256
    jae .done
.skip:
    add si, 32
    dec cx
    jmp .scan
.done:
    mov [gui_dir_count], bx
    ; Clamp selection
    mov ax, [gui_sel]
    test bx, bx
    jz .zero_sel
    cmp ax, bx
    jb .sel_ok
    mov ax, bx
    dec ax
    mov [gui_sel], ax
    jmp .sel_ok
.zero_sel:
    mov word [gui_sel], 0
.sel_ok:
    call gui_ensure_visible
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ── gui_ensure_visible: adjust scroll so selection is on screen ─────────────
gui_ensure_visible:
    push ax
    push bx
    mov ax, [gui_sel]
    cmp ax, [gui_scroll]
    jge .check_bot
    mov [gui_scroll], ax
    jmp .done
.check_bot:
    mov bx, [gui_scroll]
    add bx, GUI_LIST_ROWS
    cmp ax, bx
    jl .done
    ; scroll = sel - (LIST_ROWS - 1)
    sub ax, GUI_LIST_ROWS - 1
    mov [gui_scroll], ax
.done:
    pop bx
    pop ax
    ret

; ── gui_sel_up / gui_sel_down ───────────────────────────────────────────────
gui_sel_up:
    push ax
    mov ax, [gui_sel]
    test ax, ax
    jz .done
    dec ax
    mov [gui_sel], ax
    call gui_ensure_visible
.done:
    pop ax
    ret

gui_sel_down:
    push ax
    push bx
    mov ax, [gui_sel]
    mov bx, [gui_dir_count]
    test bx, bx
    jz .done
    dec bx
    cmp ax, bx
    jge .done
    inc ax
    mov [gui_sel], ax
    call gui_ensure_visible
.done:
    pop bx
    pop ax
    ret

; ==========================================================================
; gui_ptr: VGA byte offset for row DH, col DL → DI
;   offset = row*160 + col*2   (80 cols × 2 bytes/col = 160)
; Clobbers: DI only.  Preserves all other registers.
; ==========================================================================
gui_ptr:
    push ax
    push bx
    push cx
    push dx
    mov cl, dl          ; save col (DX will be clobbered by mul)
    xor ax, ax
    mov al, dh          ; row
    xor dx, dx
    mov bx, 160
    mul bx              ; AX = row*160 (DX=0, no overflow for row≤24)
    movzx bx, cl
    shl bx, 1           ; BX = col*2
    add ax, bx
    mov di, ax
    pop dx              ; restore caller's DX (DH=row, DL=col untouched)
    pop cx
    pop bx
    pop ax
    ret

; ── gui_fill: write CX copies of char AL with attr AH at ES:DI; DI advances
gui_fill:
    test cx, cx
    jz .done
.lp:
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    dec cx
    jnz .lp
.done:
    ret

; ── gui_puts: write DS:SI null-terminated string, attr AH, at ES:DI; DI advances
gui_puts:
.lp:
    lodsb
    test al, al
    jz .done
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    jmp .lp
.done:
    ret

; ==========================================================================
; gui_draw_all: redraw every UI zone
; ==========================================================================
gui_draw_all:
    call gui_draw_title
    call gui_draw_path
    call gui_draw_frame
    call gui_draw_files
    call gui_draw_status
    call gui_draw_cmdline
    call gui_draw_fkeys
    ; Position BIOS cursor at end of CMD input
    mov al, [gui_cmd_len]
    add al, 5           ; "CMD: " = 5 chars
    mov dh, 23
    mov dl, al
    call vid_set_cursor
    ret

; ==========================================================================
; gui_draw_title: row 0
; ==========================================================================
gui_draw_title:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov ax, 0xB800
    mov es, ax
    ; Fill row 0
    mov dh, 0
    mov dl, 0
    call gui_ptr
    mov al, ' '
    mov ah, GUI_TITLE_ATTR
    mov cx, 80
    call gui_fill
    ; Center the title string
    mov si, gui_s_title
    call str_len            ; AX = length
    mov bx, 80
    sub bx, ax
    jle .no_center
    shr bx, 1               ; BX = start column
    mov dh, 0
    mov dl, bl
    call gui_ptr
.no_center:
    mov si, gui_s_title
    mov ah, GUI_TITLE_ATTR
    call gui_puts
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ==========================================================================
; gui_draw_path: row 1
; ==========================================================================
gui_draw_path:
    push ax
    push cx
    push dx
    push si
    push di
    push es
    mov ax, 0xB800
    mov es, ax
    ; Fill row 1
    mov dh, 1
    mov dl, 0
    call gui_ptr
    mov al, ' '
    mov ah, GUI_PATH_ATTR
    mov cx, 80
    call gui_fill
    ; Write "  Dir: " + sh_cwd
    mov dh, 1
    mov dl, 0
    call gui_ptr
    mov si, gui_s_pathpfx
    mov ah, GUI_PATH_ATTR
    call gui_puts
    mov si, sh_cwd
    call gui_puts
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    ret

; ==========================================================================
; gui_draw_frame: panel borders (rows 2-4, side borders 5-20, row 21)
; ==========================================================================
gui_draw_frame:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    mov ax, 0xB800
    mov es, ax
    mov ah, GUI_BORDER_ATTR

    ; Row 2: ╔══...══╗
    mov dh, 2
    mov dl, 0
    call gui_ptr
    mov al, 0xC9            ; ╔
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    mov al, 0xCD            ; ═
    mov cx, 78
    call gui_fill
    mov al, 0xBB            ; ╗
    mov [es:di], al
    mov [es:di+1], ah

    ; Row 3: ║ header content ║
    mov dh, 3
    mov dl, 0
    call gui_ptr
    mov al, 0xBA            ; ║
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    mov al, ' '
    push ax
    mov ah, GUI_HDR_ATTR
    mov cx, 78
    call gui_fill
    pop ax
    mov al, 0xBA
    mov [es:di], al
    mov [es:di+1], ah
    ; Overlay header text
    push si
    mov dh, 3
    mov dl, 1
    call gui_ptr
    mov si, gui_s_hdr
    mov ah, GUI_HDR_ATTR
    call gui_puts
    pop si

    ; Row 4: ╠══...══╣
    mov ah, GUI_BORDER_ATTR
    mov dh, 4
    mov dl, 0
    call gui_ptr
    mov al, 0xCC            ; ╠
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    mov al, 0xCD
    mov cx, 78
    call gui_fill
    mov al, 0xB9            ; ╣
    mov [es:di], al
    mov [es:di+1], ah

    ; Rows 5-20: ║ blue fill ║
    mov bh, GUI_LIST_FIRST
.side:
    cmp bh, GUI_LIST_LAST
    jg .side_done
    mov dh, bh
    mov dl, 0
    call gui_ptr
    mov al, 0xBA
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    mov al, ' '
    push ax
    mov ah, GUI_NORM_ATTR
    mov cx, 78
    call gui_fill
    pop ax
    mov al, 0xBA
    mov [es:di], al
    mov [es:di+1], ah
    inc bh
    jmp .side
.side_done:

    ; Row 21: ╚══...══╝
    mov dh, 21
    mov dl, 0
    call gui_ptr
    mov al, 0xC8            ; ╚
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    mov al, 0xCD
    mov cx, 78
    call gui_fill
    mov al, 0xBC            ; ╝
    mov [es:di], al
    mov [es:di+1], ah

    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ==========================================================================
; gui_draw_files: rows 5-20  (the 16-slot file list)
; ==========================================================================
gui_draw_files:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp

    mov ax, 0xB800
    mov es, ax
    xor bp, bp              ; slot index 0..15

.slot:
    cmp bp, GUI_LIST_ROWS
    jge .slots_done

    ; Screen row = GUI_LIST_FIRST + slot
    mov ax, bp
    add ax, GUI_LIST_FIRST
    mov dh, al

    ; Absolute entry index = scroll + slot
    mov ax, [gui_scroll]
    add ax, bp

    ; If beyond end, draw a blank row
    cmp ax, [gui_dir_count]
    jge .blank_slot

    ; Get pointer to the directory entry
    mov bx, ax
    shl bx, 1
    mov si, [gui_entry_ptrs + bx]

    ; Decide row colour
    mov bx, [gui_scroll]
    add bx, bp              ; BX = absolute index
    cmp bx, [gui_sel]
    je .colour_sel
    test byte [si+11], 0x10
    jnz .colour_dir
    test byte [si+11], 0x06
    jnz .colour_sys
    mov ah, GUI_NORM_ATTR
    jmp .colour_done
.colour_dir:  mov ah, GUI_DIR_ATTR    ; jmp .colour_done
    jmp .colour_done
.colour_sys:  mov ah, GUI_SYS_ATTR
    jmp .colour_done
.colour_sel:  mov ah, GUI_SEL_ATTR
.colour_done:

    ; Fill cols 1-78 with row background colour
    mov dl, 1
    call gui_ptr
    mov al, ' '
    mov cx, 78
    call gui_fill

    ; ── Col 1: selection arrow ──────────────────────────────────────────
    mov dl, 1
    call gui_ptr
    mov bx, [gui_scroll]
    add bx, bp
    cmp bx, [gui_sel]
    jne .no_arrow
    mov al, 0x10            ; ► (CP437)
    mov [es:di], al
    mov [es:di+1], ah
.no_arrow:

    ; ── Col 3: entry type indicator ────────────────────────────────────
    mov dl, 3
    call gui_ptr
    mov al, '-'
    test byte [si+11], 0x10
    jz .no_dir_ch
    mov al, '/'
.no_dir_ch:
    mov [es:di], al
    mov [es:di+1], ah

    ; ── Cols 5-17: formatted name (13 chars padded) ────────────────────
    ; fat_format_name needs ES=DS; save/restore ES around it
    push ax                 ; save row colour (AH) and row attr
    push es
    push di
    mov ax, ds
    mov es, ax
    mov di, _sh_namebuf
    call fat_format_name    ; SI=entry → _sh_namebuf = "NAME.EXT\0"
    pop di
    pop es
    pop ax                  ; restore row colour (AH)

    mov dl, 5
    call gui_ptr
    push si
    mov si, _sh_namebuf
    mov cx, 13
.name_w:
    lodsb
    test al, al
    jz .name_pad
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    dec cx
    jnz .name_w
    jmp .name_end
.name_pad:
    test cx, cx
    jz .name_end
    mov al, ' '
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    dec cx
    jmp .name_pad
.name_end:
    pop si

    ; ── Cols 19-26: size or "<DIR>   " (8 chars) ──────────────────────
    mov dl, 19
    call gui_ptr
    test byte [si+11], 0x10
    jz .size_num
    ; directory tag
    push si
    mov si, gui_s_dirtag
    mov cx, 8
.dtag:
    lodsb
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    loop .dtag
    pop si
    jmp .after_size
.size_num:
    push ax
    mov ax, [si+28]         ; 16-bit file size (FAT12 floppy max = 1.44 MB < 65536? no)
    ; For files up to 1.44 MB we need 32-bit. Use [si+28] as low word only
    ; (large files display as "xxxxx" low 16 bits – acceptable for demo)
    call gui_put_dec8       ; AX=value, AH=attr, ES:DI → writes 8 chars
    pop ax
.after_size:

    ; ── Cols 28-37: date  "DD-MM-YYYY" ────────────────────────────────
    mov dl, 28
    call gui_ptr
    mov ax, [si+24]         ; date word
    mov [gui_date_tmp], ax  ; save to temp variable
    push ax                 ; save date word on stack
    ; Day (bits 4-0)
    and ax, 0x001F
    mov cx, ax
    call gui_put2d          ; writes 2 digits, advances DI
    mov al, '-'
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    ; Month (bits 8-5)
    pop ax                  ; restore date word
    push ax
    mov cx, ax
    shr cx, 5
    and cx, 0x000F
    call gui_put2d
    mov al, '-'
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    ; Year (bits 15-9) + 1980
    pop ax
    shr ax, 9
    add ax, 1980
    mov cx, ax
    call gui_put4d

    ; ── Cols 39-42: attribute flags  A R S H ──────────────────────────
    mov dl, 39
    call gui_ptr
    ; Archive
    mov al, '-'
    test byte [si+11], 0x20
    jz .a0
    mov al, 'A'
.a0:
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    ; Read-only
    mov al, '-'
    test byte [si+11], 0x01
    jz .r0
    mov al, 'R'
.r0:
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    ; System
    mov al, '-'
    test byte [si+11], 0x04
    jz .s0
    mov al, 'S'
.s0:
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    ; Hidden
    mov al, '-'
    test byte [si+11], 0x02
    jz .h0
    mov al, 'H'
.h0:
    mov [es:di], al
    mov [es:di+1], ah

    jmp .next_slot

.blank_slot:
    mov dl, 1
    call gui_ptr
    mov al, ' '
    mov ah, GUI_NORM_ATTR
    mov cx, 78
    call gui_fill

.next_slot:
    inc bp
    jmp .slot

.slots_done:
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; --------------------------------------------------------------------------
; gui_put_dec8: write AX as decimal, right-justified in 8 chars, attr AH
;              Advances DI. Clobbers nothing else visible.
; --------------------------------------------------------------------------
gui_put_dec8:
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, gui_dec_buf
    mov bx, 10
    xor cx, cx
    test ax, ax
    jnz .cvt
    mov byte [si], '0'
    inc si
    inc cx
    jmp .cvt_done
.cvt:
    xor dx, dx
    div bx
    add dl, '0'
    mov [si], dl
    inc si
    inc cx
    test ax, ax
    jnz .cvt
.cvt_done:
    ; Print spaces for padding
    push cx
    mov bx, 8
    sub bx, cx          ; spaces needed
.pad:
    test bx, bx
    jz .pad_done
    mov al, ' '
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    dec bx
    jmp .pad
.pad_done:
    pop cx
    ; Print digits (reversed: si points one past last written)
.digs:
    dec si
    mov al, [si]
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    dec cx
    jnz .digs

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; --------------------------------------------------------------------------
; gui_put2d: write CX as 2-digit decimal at ES:DI, attr AH. Advances DI.
; --------------------------------------------------------------------------
gui_put2d:
    push ax
    push cx
    push dx
    mov ax, cx
    xor dx, dx
    mov cx, 10
    div cx          ; AL=tens, DL=units
    add al, '0'
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    add dl, '0'
    mov [es:di], dl
    mov [es:di+1], ah
    add di, 2
    pop dx
    pop cx
    pop ax
    ret

; --------------------------------------------------------------------------
; gui_put4d: write CX as 4-digit decimal at ES:DI, attr AH. Advances DI.
; --------------------------------------------------------------------------
gui_put4d:
    push ax
    push cx
    push dx
    mov ax, cx
    ; thousands
    xor dx, dx
    mov cx, 1000
    div cx
    add al, '0'
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    ; hundreds
    mov ax, dx
    xor dx, dx
    mov cx, 100
    div cx
    add al, '0'
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    ; tens
    mov ax, dx
    xor dx, dx
    mov cx, 10
    div cx
    add al, '0'
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    ; units
    add dl, '0'
    mov [es:di], dl
    mov [es:di+1], ah
    add di, 2
    pop dx
    pop cx
    pop ax
    ret

; ==========================================================================
; gui_draw_status: row 22
; ==========================================================================
gui_draw_status:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    mov ax, 0xB800
    mov es, ax

    ; Fill row 22
    mov dh, 22
    mov dl, 0
    call gui_ptr
    mov al, ' '
    mov ah, GUI_STATUS_ATTR
    mov cx, 80
    call gui_fill

    ; Write hint text
    mov dh, 22
    mov dl, 0
    call gui_ptr
    mov si, gui_s_hint
    mov ah, GUI_STATUS_ATTR
    call gui_puts

    ; Overwrite right portion with "  NNN files"
    mov dh, 22
    mov dl, 68
    call gui_ptr
    mov ax, [gui_dir_count]
    mov ah, GUI_STATUS_ATTR
    call gui_put_dec8       ; 8 chars
    mov si, gui_s_files
    call gui_puts           ; " files"

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ==========================================================================
; gui_draw_cmdline: row 23
; ==========================================================================
gui_draw_cmdline:
    push ax
    push cx
    push dx
    push si
    push di
    push es
    mov ax, 0xB800
    mov es, ax

    ; Fill row 23
    mov dh, 23
    mov dl, 0
    call gui_ptr
    mov al, ' '
    mov ah, GUI_CMD_ATTR
    mov cx, 80
    call gui_fill

    ; "CMD: "  in green
    mov dh, 23
    mov dl, 0
    call gui_ptr
    mov si, gui_s_cmdp
    mov ah, GUI_CMDP_ATTR
    call gui_puts

    ; Command buffer content in white
    mov si, gui_cmd_buf
    mov ah, GUI_CMD_ATTR
    call gui_puts

    ; Position BIOS cursor at end of cmd buffer
    mov al, [gui_cmd_len]
    add al, 5               ; length of "CMD: "
    mov dh, 23
    mov dl, al
    call vid_set_cursor

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    ret

; ==========================================================================
; gui_draw_fkeys: row 24
; ==========================================================================
gui_draw_fkeys:
    push ax
    push cx
    push dx
    push si
    push di
    push es
    mov ax, 0xB800
    mov es, ax

    ; Fill row 24 black
    mov dh, 24
    mov dl, 0
    call gui_ptr
    mov al, ' '
    mov ah, GUI_FK_NAME
    mov cx, 80
    call gui_fill

    ; Walk gui_fk_data table: [attr_byte, "text\0", ...]  end=0x00
    mov dh, 24
    mov dl, 0
    call gui_ptr
    mov si, gui_fk_data
.fk:
    mov ah, [si]            ; attribute byte
    inc si
    test ah, ah
    jz .fk_done
.fk_str:
    lodsb
    test al, al
    jz .fk             ; end of this segment → next attr byte
    mov [es:di], al
    mov [es:di+1], ah
    add di, 2
    jmp .fk_str
.fk_done:

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    ret
