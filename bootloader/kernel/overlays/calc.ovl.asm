; =============================================================================
; CALC.OVL  -  Calculator  (KSDOS)
; Written in HolyC16 — the HolyC-inspired macro language for NASM 16-bit.
;
; Reads a line like "12 + 5 * 3", tokenizes into number/operator arrays,
; then evaluates with correct precedence: a pass collapses all * and /
; left-to-right, then a second pass folds the remaining + and - chain.
; Integers are 16-bit signed; literals must be non-negative (use "0 - N"
; for a negative result). Type EXIT to leave.
; =============================================================================
BITS 16
ORG OVERLAY_BUF
%include "ovl_api.asm"
%include "holyc16.mac"

MAX_TOK equ 16

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
STRBUF calc_line, 128
WORDBUF calc_nums, MAX_TOK
STRBUF  calc_ops,  MAX_TOK
U16 calc_ntok, 0
U16 calc_otok, 0
U16 calc_result, 0

STR str_title,   "KSDOS Calculator v1.0 - integer arithmetic (+ - * /)"
STR str_help,    "Example: 12 + 5 * 3     (type EXIT to quit)"
STR str_prompt,  "> "
STR str_eq,      "= "
STR str_err_syn, "Syntax error"
STR str_err_div, "Division by zero"
STR str_neg_min, "-32768"
STR str_exit1,   "EXIT"
STR str_exit2,   "exit"

; ---------------------------------------------------------------------------
; U0 calc_tokenize()
; Parses calc_line into calc_nums[]/calc_ops[]. CF=1 on syntax error.
; ---------------------------------------------------------------------------
FN U0, calc_tokenize
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov word [calc_ntok], 0
    mov word [calc_otok], 0
    mov si, calc_line

.skip_ws:
    mov al, [si]
    cmp al, ' '
    jne .check_char
    inc si
    jmp .skip_ws

.check_char:
    test al, al
    jz .tok_done
    cmp al, '0'
    jb .check_op
    cmp al, '9'
    ja .check_op

    ; ---- parse a number into DI ----
    xor di, di
.num_loop:
    mov al, [si]
    cmp al, '0'
    jb .num_done
    cmp al, '9'
    ja .num_done
    push ax
    mov ax, di
    mov cx, 10
    mul cx
    mov di, ax
    pop ax
    sub al, '0'
    xor ah, ah
    add di, ax
    inc si
    jmp .num_loop
.num_done:
    mov bx, [calc_ntok]
    cmp bx, MAX_TOK
    jge .err
    shl bx, 1
    mov [calc_nums + bx], di
    inc word [calc_ntok]
    jmp .skip_ws

.check_op:
    cmp al, '+'
    je .store_op
    cmp al, '-'
    je .store_op
    cmp al, '*'
    je .store_op
    cmp al, '/'
    je .store_op
    jmp .err
.store_op:
    mov bx, [calc_otok]
    cmp bx, MAX_TOK - 1
    jge .err
    mov [calc_ops + bx], al
    inc word [calc_otok]
    inc si
    jmp .skip_ws

.tok_done:
    mov ax, [calc_ntok]
    test ax, ax
    jz .err
    mov bx, [calc_otok]
    inc bx
    cmp ax, bx
    jne .err
    clc
    jmp .tok_ret
.err:
    stc
.tok_ret:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
ENDFN

; ---------------------------------------------------------------------------
; U0 calc_remove_tok(BX=op index)
; Deletes calc_ops[BX] and calc_nums[BX+1], shifting later entries down.
; ---------------------------------------------------------------------------
FN U0, calc_remove_tok
    push ax
    push cx
    push si
    push di

    mov cx, [calc_otok]
    dec cx
    mov si, bx
.shift_ops:
    cmp si, cx
    jge .ops_done
    mov al, [calc_ops + si + 1]
    mov [calc_ops + si], al
    inc si
    jmp .shift_ops
.ops_done:
    dec word [calc_otok]

    mov cx, [calc_ntok]
    dec cx
    mov si, bx
    inc si
.shift_nums:
    cmp si, cx
    jge .nums_done
    mov di, si
    shl di, 1
    mov ax, [calc_nums + di + 2]
    mov [calc_nums + di], ax
    inc si
    jmp .shift_nums
.nums_done:
    dec word [calc_ntok]

    pop di
    pop si
    pop cx
    pop ax
ENDFN

; ---------------------------------------------------------------------------
; U0 calc_eval()
; Evaluates calc_nums[]/calc_ops[] into calc_result. CF=1 on division by 0.
; ---------------------------------------------------------------------------
FN U0, calc_eval
    push ax
    push bx
    push cx
    push dx
    push si

    ; ---- Pass 1: * and / (left to right) ----
    xor bx, bx
.mul_pass:
    mov cx, [calc_otok]
    cmp bx, cx
    jge .mul_done
    mov al, [calc_ops + bx]
    cmp al, '*'
    je .do_mul
    cmp al, '/'
    je .do_div
    inc bx
    jmp .mul_pass
.do_mul:
    mov si, bx
    shl si, 1
    mov ax, [calc_nums + si]
    imul word [calc_nums + si + 2]
    mov [calc_nums + si], ax
    call calc_remove_tok
    jmp .mul_pass
.do_div:
    mov si, bx
    shl si, 1
    mov ax, [calc_nums + si + 2]
    test ax, ax
    jz .div_zero
    mov ax, [calc_nums + si]
    cwd
    idiv word [calc_nums + si + 2]
    mov [calc_nums + si], ax
    call calc_remove_tok
    jmp .mul_pass
.div_zero:
    stc
    jmp .eval_ret
.mul_done:

    ; ---- Pass 2: + and - (left to right) ----
    mov ax, [calc_nums + 0]
    mov cx, [calc_otok]
    test cx, cx
    jz .sum_done
    xor bx, bx
.sum_pass:
    cmp bx, cx
    jge .sum_done
    mov dl, [calc_ops + bx]
    mov si, bx
    shl si, 1
    add si, 2
    cmp dl, '+'
    je .do_add
    sub ax, [calc_nums + si]
    jmp .sum_next
.do_add:
    add ax, [calc_nums + si]
.sum_next:
    inc bx
    jmp .sum_pass
.sum_done:
    mov [calc_result], ax
    clc
.eval_ret:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
ENDFN

; ---------------------------------------------------------------------------
; U0 calc_print_signed(AX=value)
; ---------------------------------------------------------------------------
FN U0, calc_print_signed
    test ax, ax
    jns .positive
    cmp ax, 0x8000
    jne .neg_normal
    Print str_neg_min
    jmp .print_done
.neg_normal:
    PrintChar '-'
    neg ax
    call print_word_dec
    jmp .print_done
.positive:
    call print_word_dec
.print_done:
ENDFN

; ---------------------------------------------------------------------------
; U0 ovl_entry()
; ---------------------------------------------------------------------------
FN U0, ovl_entry
    Banner YELLOW, str_title
    PrintLn str_help

.loop:
    NewLine
    Print str_prompt
    ReadLine calc_line, 127

    StrCmp calc_line, str_exit1
    je .quit
    StrCmp calc_line, str_exit2
    je .quit

    mov al, [calc_line]
    test al, al
    jz .loop

    call calc_tokenize
    jc .syntax_err
    call calc_eval
    jc .div_zero_err

    Print str_eq
    mov ax, [calc_result]
    call calc_print_signed
    NewLine
    jmp .loop

.syntax_err:
    PrintLn str_err_syn
    jmp .loop
.div_zero_err:
    PrintLn str_err_div
    jmp .loop

.quit:
ENDFN
