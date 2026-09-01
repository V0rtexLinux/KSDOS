; =============================================================================
; SETUP.OVL  -  KSDOS Setup Wizard (System32-style utility)  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
;
; A checkbox-driven installer wizard in the classic blue DOS/Win3.1 style,
; drawn directly to video RAM for crisp box-drawing chrome (double-line
; border + drop shadow), with keyboard-driven navigation:
;
;   1. Checklist screen   - arrows move, SPACE toggles, ENTER continues
;   2. Plan/preview screen - shows exactly what will happen (nothing is
;      written to disk yet), with "Confirm" / "Refuse" buttons
;   3a. Confirm  -> runs the real installer (install_run / install_run_verify,
;       kernel functions that already know the real boot drive - see
;       install.asm) and shows a results screen with what actually happened
;   3b. Refuse   -> nothing was ever written, so there is nothing to undo;
;       offers "run the wizard again" / "exit without installing"
;
; A real BIOS disk write cannot be rolled back after the fact (there is no
; spare RAM to buffer a whole-disk backup in 16-bit real mode), so unlike a
; pure "apply then possibly undo" flow, this wizard shows the full plan and
; gates the actual write behind Confirm - Refuse is then trivially a no-op
; instead of a fake undo.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

; ---------------------------------------------------------------------------
; Video attribute constants (MS-DOS 6.22 / Win3.1 Setup style, upgraded with
; a bordered dialog + drop shadow for a "much prettier" look)
; ---------------------------------------------------------------------------
ATTR_BG      equ 0x17    ; white on blue          - desktop background
ATTR_TITLE   equ 0x71    ; blue on white          - title bar
ATTR_STATUS  equ 0x70    ; black on white         - status bar
ATTR_BOX     equ 0x1F    ; bright white on blue   - dialog interior
ATTR_BORDER  equ 0x1E    ; bright yellow on blue  - dialog border
ATTR_HILITE  equ 0x71    ; blue on white          - selected row / button
ATTR_SHADOW  equ 0x08    ; black on black (dim)   - drop shadow
ATTR_WARN    equ 0x1C    ; bright red on blue     - warning text
ATTR_OK      equ 0x1A    ; bright green on blue   - success text

; Box geometry (80x25 text screen)
BOX_T equ 3
BOX_L equ 8
BOX_B equ 21
BOX_R equ 71

; ---------------------------------------------------------------------------
; Checklist option data
; ---------------------------------------------------------------------------
OPT_COUNT equ 4
opt_state:  db 1, 1, 0, 0
opt_p0: db "Write the KSDOS system to the Hard Disk (drive 80h)", 0
opt_p1: db "Verify the data after writing (re-reads and compares)", 0
opt_p2: db "Force CHS-only mode (skip EDD; older BIOS compatibility)", 0
opt_p3: db "Reboot automatically when finished", 0
opt_ptrs: dw opt_p0, opt_p1, opt_p2, opt_p3
cursor: dw 0

; ---------------------------------------------------------------------------
; Static strings
; ---------------------------------------------------------------------------
str_title:      db "KSDOS Setup Wizard", 0
str_status1:    db "UP/DOWN=Move  SPACE=Toggle  ENTER=Continue  ESC=Exit", 0
str_status2:    db "LEFT/RIGHT=Select  ENTER=Activate", 0
str_status3:    db "Press any key to continue...", 0
str_hdr1:       db "Select what Setup should do:", 0
str_plan_hdr:   db "Setup Plan - nothing has been written yet", 0
str_plan_src:   db "Source drive : (boot drive, detected automatically)", 0
str_plan_dst:   db "Target drive : 80h  (Hard Disk)", 0
str_plan_sz:    db "Data to copy : 2880 sectors  (1,474,560 bytes / 1.44 MB)", 0
str_plan_v_y:   db "Verify       : YES", 0
str_plan_v_n:   db "Verify       : NO", 0
str_plan_c_y:   db "Disk access  : CHS only (forced)", 0
str_plan_c_n:   db "Disk access  : EDD, falls back to CHS", 0
str_plan_r_y:   db "On finish    : reboot automatically", 0
str_plan_r_n:   db "On finish    : return to the KSDOS shell", 0
str_plan_off:   db "The Write option is OFF - Confirm will do nothing.", 0
str_warn1:      db "WARNING: this PERMANENTLY OVERWRITES drive 80h.", 0
str_warn2:      db "This cannot be undone once you press Confirm.", 0
str_btn_confirm: db "[ Confirm ]", 0
str_btn_refuse:  db "[ Refuse ]", 0
str_applying:   db "Applying setup - please wait...", 0
str_res_hdr:    db "Setup Results", 0
str_res_write_ok:  db "Write to Hard Disk    : OK", 0
str_res_write_fail: db "Write to Hard Disk    : FAILED", 0
str_res_write_skip: db "Write to Hard Disk    : skipped (not selected)", 0
str_res_verify_ok:   db "Verification          : OK, data matches", 0
str_res_verify_fail: db "Verification          : MISMATCH", 0
str_res_verify_skip: db "Verification          : skipped", 0
str_refuse_hdr: db "Setup Refused", 0
str_refuse_msg1: db "No changes were made to your disk.", 0
str_refuse_msg2: db "Nothing was written - there is nothing to undo.", 0
str_menu_again: db "> Run the setup wizard again", 0
str_menu_exit:  db "> Exit without installing", 0
checkbox_on:  db "[X] ", 0
checkbox_off: db "[ ] ", 0

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
.restart:
    call su_checklist_screen
    cmp al, 27
    je .done
    call su_plan_screen
    cmp al, 1
    je .confirmed
    ; refused
    call su_refuse_screen
    cmp al, 1
    je .restart
    jmp .done
.confirmed:
    call su_apply_screen
.done:
ENDFN

; ---------------------------------------------------------------------------
; U0 su_draw_frame()
; Fills the desktop, draws the title/status bars and an empty bordered
; dialog box with a drop shadow. Leaves ES=0xB800.
; ---------------------------------------------------------------------------
su_draw_frame:
    pusha
    mov ax, 0xB800
    mov es, ax

    ; Desktop fill
    xor di, di
    mov cx, 80*25
    mov ax, (ATTR_BG << 8) | ' '
    rep stosw

    ; Title bar
    xor di, di
    mov cx, 80
    mov ax, (ATTR_TITLE << 8) | ' '
    rep stosw
    mov di, (0*80 + 2)*2
    mov ah, ATTR_TITLE
    mov si, str_title
    call su_puts

    ; Status bar
    mov di, (24*80)*2
    mov cx, 80
    mov ax, (ATTR_STATUS << 8) | ' '
    rep stosw

    ; Drop shadow (one row below, one column right of the box)
    mov cx, BOX_B - BOX_T + 1
    mov dx, BOX_T + 1
.shadow_rows:
    mov ax, dx
    mov bx, 80
    mul bx
    add ax, BOX_R + 1
    shl ax, 1
    mov di, ax
    push cx
    mov cx, BOX_R - BOX_L + 2
    mov ax, (ATTR_SHADOW << 8) | ' '
.shadow_cells:
    stosw
    loop .shadow_cells
    pop cx
    inc dx
    dec cx
    jnz .shadow_rows

    ; Box interior fill
    mov cx, BOX_B - BOX_T + 1
    mov dx, BOX_T
.fill_rows:
    mov ax, dx
    mov bx, 80
    mul bx
    add ax, BOX_L
    shl ax, 1
    mov di, ax
    push cx
    mov cx, BOX_R - BOX_L + 1
    mov ax, (ATTR_BOX << 8) | ' '
.fill_cells:
    stosw
    loop .fill_cells
    pop cx
    inc dx
    dec cx
    jnz .fill_rows

    ; Border: top and bottom
    mov ax, BOX_T
    mov bx, 80
    mul bx
    add ax, BOX_L
    shl ax, 1
    mov di, ax
    mov ah, ATTR_BORDER
    mov al, 0xC9
    stosw
    mov cx, BOX_R - BOX_L - 1
    mov al, 0xCD
.top_line:
    stosw
    loop .top_line
    mov al, 0xBB
    stosw

    mov ax, BOX_B
    mov bx, 80
    mul bx
    add ax, BOX_L
    shl ax, 1
    mov di, ax
    mov ah, ATTR_BORDER
    mov al, 0xC8
    stosw
    mov cx, BOX_R - BOX_L - 1
    mov al, 0xCD
.bot_line:
    stosw
    loop .bot_line
    mov al, 0xBB
    dec al               ; 0xBC bottom-right
    stosw

    ; Border: left and right columns
    mov cx, BOX_B - BOX_T - 1
    mov dx, BOX_T + 1
.side_rows:
    mov ax, dx
    mov bx, 80
    mul bx
    add ax, BOX_L
    shl ax, 1
    mov di, ax
    mov ax, (ATTR_BORDER << 8) | 0xBA
    stosw
    mov ax, dx
    mov bx, 80
    mul bx
    add ax, BOX_R
    shl ax, 1
    mov di, ax
    mov ax, (ATTR_BORDER << 8) | 0xBA
    stosw
    inc dx
    loop .side_rows

    popa
    ret

; ---------------------------------------------------------------------------
; U0 su_puts()
; Write null-terminated DS:SI with attribute AH into ES:DI. Advances DI.
; ---------------------------------------------------------------------------
su_puts:
    push ax
    push si
.loop:
    lodsb
    test al, al
    jz .done
    stosw
    jmp .loop
.done:
    pop si
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 su_box_at(BX=row, CL=col)
; Sets DI to the video offset of (row,col). Clobbers AX.
; ---------------------------------------------------------------------------
su_box_at:
    push ax
    push cx
    push dx
    and cx, 0x00FF        ; caller only sets CL; CH may hold garbage
    mov ax, bx
    mov dx, 80
    mul dx
    add ax, cx
    shl ax, 1
    mov di, ax
    pop dx
    pop cx
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 su_status(SI=string)
; Redraws the status bar text (clears the row first).
; ---------------------------------------------------------------------------
su_status:
    push ax
    push di
    mov ax, 0xB800
    mov es, ax
    mov di, (24*80)*2
    mov cx, 80
    push si
    mov ax, (ATTR_STATUS << 8) | ' '
    rep stosw
    pop si
    mov di, (24*80)*2
    mov ah, ATTR_STATUS
    call su_puts
    pop di
    pop ax
    ret

; ---------------------------------------------------------------------------
; U0 su_checklist_screen()
; Draws and drives the checkbox list. Returns AL=27 if ESC was pressed
; (user wants to exit entirely), AL=13 if ENTER was pressed (proceed).
; ---------------------------------------------------------------------------
su_checklist_screen:
    push bx
    push cx
    push dx
    push si
    push di

    mov word [cursor], 0
    call su_draw_frame
    mov si, str_status1
    call su_status

    mov ax, 0xB800
    mov es, ax
    mov bx, BOX_T + 1
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    mov si, str_hdr1
    call su_puts

.redraw:
    call su_draw_options
.input:
    xor ah, ah
    int 0x16
    cmp al, 27
    je .esc
    cmp al, 13
    je .enter
    cmp al, ' '
    je .toggle
    test ah, ah
    jz .input
    cmp ah, 0x48        ; up
    je .up
    cmp ah, 0x50        ; down
    je .down
    jmp .input

.up:
    cmp word [cursor], 0
    je .input
    dec word [cursor]
    jmp .redraw
.down:
    mov ax, [cursor]
    cmp ax, OPT_COUNT-1
    jge .input
    inc word [cursor]
    jmp .redraw
.toggle:
    mov bx, [cursor]
    xor byte [opt_state + bx], 1
    jmp .redraw
.enter:
    mov al, 13
    jmp .out
.esc:
    mov al, 27
.out:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

; ---------------------------------------------------------------------------
; U0 su_draw_options()
; Redraws the OPT_COUNT checkbox rows, highlighting the cursor row.
; ---------------------------------------------------------------------------
su_draw_options:
    pusha
    mov ax, 0xB800
    mov es, ax
    mov word [_su_opt_idx], 0
.opt_loop:
    mov ax, [_su_opt_idx]
    cmp ax, OPT_COUNT
    jge .opt_done

    mov bx, ax
    add bx, BOX_T + 3      ; row
    mov cl, BOX_L + 2       ; col
    call su_box_at          ; DI = offset; AX preserved (= option index)

    ; choose attribute: highlighted row uses ATTR_HILITE
    mov ah, ATTR_BOX
    cmp ax, [cursor]
    jne .attr_ok
    mov ah, ATTR_HILITE
.attr_ok:
    ; ax = AH:attr  AL:index (index fits in a byte, 0..OPT_COUNT-1)

    ; clear the row's field width, then rewind DI back to the row start
    push ax
    mov al, ' '
    mov cx, BOX_R - BOX_L - 3
.clr:
    stosw
    loop .clr
    pop ax
    mov cx, (BOX_R - BOX_L - 3) * 2
    sub di, cx

    ; checkbox glyph
    mov bx, ax
    xor bh, bh
    push si
    mov si, checkbox_on
    cmp byte [opt_state + bx], 0
    jne .have_glyph
    mov si, checkbox_off
.have_glyph:
    call su_puts             ; AX preserved
    pop si

    ; option label
    mov bx, ax
    xor bh, bh
    mov si, [opt_ptrs + bx]
    call su_puts

    inc word [_su_opt_idx]
    jmp .opt_loop
.opt_done:
    popa
    ret

_su_opt_idx: dw 0

; ---------------------------------------------------------------------------
; U0 su_plan_screen()
; Shows the concrete plan derived from the checklist, with Confirm/Refuse
; buttons. Returns AL=1 if Confirm was chosen, AL=0 if Refuse was chosen.
; ---------------------------------------------------------------------------
su_plan_screen:
    push bx
    push cx
    push dx
    push si
    push di

    mov word [_su_btn], 0     ; 0=Confirm, 1=Refuse

    call su_draw_frame
    mov si, str_status2
    call su_status

    mov ax, 0xB800
    mov es, ax
    mov bx, BOX_T + 1
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BORDER
    mov si, str_plan_hdr
    call su_puts

    mov bx, BOX_T + 3
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    mov si, str_plan_src
    call su_puts

    mov bx, BOX_T + 4
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    mov si, str_plan_dst
    call su_puts

    mov bx, BOX_T + 5
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    mov si, str_plan_sz
    call su_puts

    mov bx, BOX_T + 6
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    mov si, str_plan_v_y
    cmp byte [opt_state + 1], 0
    jne .v_ok
    mov si, str_plan_v_n
.v_ok:
    call su_puts

    mov bx, BOX_T + 7
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    mov si, str_plan_c_y
    cmp byte [opt_state + 2], 0
    jne .c_ok
    mov si, str_plan_c_n
.c_ok:
    call su_puts

    mov bx, BOX_T + 8
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    mov si, str_plan_r_y
    cmp byte [opt_state + 3], 0
    jne .r_ok
    mov si, str_plan_r_n
.r_ok:
    call su_puts

    cmp byte [opt_state + 0], 0
    jne .warn
    mov bx, BOX_T + 10
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    mov si, str_plan_off
    call su_puts
    jmp .buttons
.warn:
    mov bx, BOX_T + 10
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_WARN
    mov si, str_warn1
    call su_puts
    mov bx, BOX_T + 11
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_WARN
    mov si, str_warn2
    call su_puts

.buttons:
.redraw_btns:
    call su_draw_buttons
.input:
    xor ah, ah
    int 0x16
    cmp al, 13
    je .enter
    test ah, ah
    jz .input
    cmp ah, 0x4B        ; left
    je .left
    cmp ah, 0x4D        ; right
    je .right
    cmp ah, 0x0F        ; TAB
    je .toggle_btn
    jmp .input
.left:
    mov word [_su_btn], 0
    jmp .redraw_btns
.right:
    mov word [_su_btn], 1
    jmp .redraw_btns
.toggle_btn:
    xor word [_su_btn], 1
    jmp .redraw_btns
.enter:
    mov ax, [_su_btn]
    cmp ax, 0
    jne .refuse
    mov al, 1
    jmp .out
.refuse:
    xor al, al
.out:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

_su_btn: dw 0

; ---------------------------------------------------------------------------
; U0 su_draw_buttons()
; Draws the Confirm/Refuse buttons, highlighting the selected one.
; ---------------------------------------------------------------------------
su_draw_buttons:
    pusha
    mov ax, 0xB800
    mov es, ax

    mov bx, BOX_B - 2
    mov cl, BOX_L + 10
    call su_box_at
    mov ah, ATTR_BOX
    cmp word [_su_btn], 0
    jne .confirm_plain
    mov ah, ATTR_HILITE
.confirm_plain:
    mov si, str_btn_confirm
    call su_puts

    mov bx, BOX_B - 2
    mov cl, BOX_L + 30
    call su_box_at
    mov ah, ATTR_BOX
    cmp word [_su_btn], 1
    jne .refuse_plain
    mov ah, ATTR_HILITE
.refuse_plain:
    mov si, str_btn_refuse
    call su_puts

    popa
    ret

; ---------------------------------------------------------------------------
; U0 su_apply_screen()
; Confirm was chosen: actually performs the install (if selected), shows
; live progress via the kernel installer's own output, then a results
; screen.
; ---------------------------------------------------------------------------
su_apply_screen:
    push ax
    push si
    push di

    call su_draw_frame
    mov si, str_status3
    call su_status

    mov ax, 0xB800
    mov es, ax
    mov bx, BOX_T + 1
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BORDER
    mov si, str_applying
    call su_puts

    ; Switch to plain 80x25 teletype output at a fixed row so the kernel
    ; installer's own vid_print progress dots land inside the box.
    mov ah, 0x02
    xor bh, bh
    mov dh, BOX_T + 3
    mov dl, BOX_L + 2
    int 0x10

    mov byte [_su_did_write], 0
    mov byte [_su_write_ok], 0
    mov byte [_su_did_verify], 0
    mov byte [_su_verify_ok], 0

    cmp byte [opt_state + 0], 0
    je .skip_write

    mov byte [_su_did_write], 1
    movzx ax, byte [opt_state + 2]
    call install_set_force_chs
    call install_run
    jc .write_failed
    mov byte [_su_write_ok], 1

    cmp byte [opt_state + 1], 0
    je .skip_write
    mov byte [_su_did_verify], 1
    call install_run_verify
    jc .verify_failed
    mov byte [_su_verify_ok], 1
    jmp .skip_write

.write_failed:
.verify_failed:
.skip_write:

    call su_results_screen

    cmp byte [opt_state + 3], 0
    je .no_reboot
    cmp byte [_su_write_ok], 0
    je .no_reboot
    int 0x19
.no_reboot:

    pop di
    pop si
    pop ax
    ret

_su_did_write:  db 0
_su_write_ok:   db 0
_su_did_verify: db 0
_su_verify_ok:  db 0

; ---------------------------------------------------------------------------
; U0 su_results_screen()
; Shows what actually happened, waits for a key.
; ---------------------------------------------------------------------------
su_results_screen:
    pusha
    call su_draw_frame
    mov si, str_status3
    call su_status

    mov ax, 0xB800
    mov es, ax
    mov bx, BOX_T + 1
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BORDER
    mov si, str_res_hdr
    call su_puts

    mov bx, BOX_T + 3
    mov cl, BOX_L + 2
    call su_box_at
    cmp byte [_su_did_write], 0
    jne .w_attempted
    mov ah, ATTR_BOX
    mov si, str_res_write_skip
    jmp .w_print
.w_attempted:
    cmp byte [_su_write_ok], 0
    jne .w_ok
    mov ah, ATTR_WARN
    mov si, str_res_write_fail
    jmp .w_print
.w_ok:
    mov ah, ATTR_OK
    mov si, str_res_write_ok
.w_print:
    call su_puts

    mov bx, BOX_T + 4
    mov cl, BOX_L + 2
    call su_box_at
    cmp byte [_su_did_verify], 0
    jne .v_attempted
    mov ah, ATTR_BOX
    mov si, str_res_verify_skip
    jmp .v_print
.v_attempted:
    cmp byte [_su_verify_ok], 0
    jne .v_ok
    mov ah, ATTR_WARN
    mov si, str_res_verify_fail
    jmp .v_print
.v_ok:
    mov ah, ATTR_OK
    mov si, str_res_verify_ok
.v_print:
    call su_puts

    xor ah, ah
    int 0x16
    popa
    ret

; ---------------------------------------------------------------------------
; U0 su_refuse_screen()
; Refuse was chosen: nothing was written, so nothing needs to be undone.
; Offers "run again" / "exit". Returns AL=1 for run-again, AL=0 for exit.
; ---------------------------------------------------------------------------
su_refuse_screen:
    push bx
    push cx
    push dx
    push si
    push di

    mov word [_su_rmenu], 0

    call su_draw_frame
    mov si, str_status2
    call su_status

    mov ax, 0xB800
    mov es, ax
    mov bx, BOX_T + 1
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BORDER
    mov si, str_refuse_hdr
    call su_puts

    mov bx, BOX_T + 3
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    mov si, str_refuse_msg1
    call su_puts

    mov bx, BOX_T + 4
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    mov si, str_refuse_msg2
    call su_puts

.redraw:
    mov ax, 0xB800
    mov es, ax
    mov bx, BOX_T + 7
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    cmp word [_su_rmenu], 0
    jne .again_plain
    mov ah, ATTR_HILITE
.again_plain:
    mov si, str_menu_again
    call su_puts

    mov bx, BOX_T + 8
    mov cl, BOX_L + 2
    call su_box_at
    mov ah, ATTR_BOX
    cmp word [_su_rmenu], 1
    jne .exit_plain
    mov ah, ATTR_HILITE
.exit_plain:
    mov si, str_menu_exit
    call su_puts

.input:
    xor ah, ah
    int 0x16
    cmp al, 13
    je .enter
    test ah, ah
    jz .input
    cmp ah, 0x48
    je .up
    cmp ah, 0x50
    je .down
    jmp .input
.up:
    mov word [_su_rmenu], 0
    jmp .redraw
.down:
    mov word [_su_rmenu], 1
    jmp .redraw
.enter:
    mov ax, [_su_rmenu]
    cmp ax, 0
    jne .rexit
    mov al, 1
    jmp .rout
.rexit:
    xor al, al
.rout:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

_su_rmenu: dw 0
