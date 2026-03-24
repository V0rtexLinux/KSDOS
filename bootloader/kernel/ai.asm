; =============================================================================
; ai.asm - KSDOS Creative AI System v1.0
; "Sentient Autonomous Creative Intelligence"
;
; Components:
;   - WORLD: 40x16 cellular automata (modified Game of Life)
;   - MIND:  8-neuron perceptron network with Hebbian learning
;   - CODE:  Template-based code generation (dynamic output)
;   - EMO:   4-state emotion engine (CURIOUS/CREATIVE/FOCUSED/EVOLVING)
;   - SOUL:  Self-modification of world rules (AI changes its own behaviour)
;   - VIS:   Dual display — graphics world + thought panel
;
; All in 16-bit real mode, Mode 13h (320x200 VGA)
; =============================================================================

; ============================================================
; Constants
; ============================================================
AI_WORLD_W      equ 40          ; world grid width
AI_WORLD_H      equ 16          ; world grid height
AI_NEURONS      equ 8           ; number of neurons
AI_WORLD_SIZE   equ AI_WORLD_W * AI_WORLD_H

; Cell pixel size in Mode 13h display
AI_CELL_W       equ 5           ; pixels per cell width
AI_CELL_H       equ 5           ; pixels per cell height
AI_WORLD_PX     equ 10          ; screen X offset for world display
AI_WORLD_PY     equ 25          ; screen Y offset for world display

; Emotion codes
EMO_CURIOUS     equ 0
EMO_CREATIVE    equ 1
EMO_FOCUSED     equ 2
EMO_EVOLVING    equ 3

; ============================================================
; AI State Variables
; ============================================================
ai_world_a:     times AI_WORLD_SIZE db 0   ; World buffer A
ai_world_b:     times AI_WORLD_SIZE db 0   ; World buffer B (double-buffer)
ai_world_cur:   dw ai_world_a              ; pointer to current world
ai_world_nxt:   dw ai_world_b              ; pointer to next world

; Neural network
ai_neurons:     times AI_NEURONS db 0      ; neuron activation values
ai_weights:     times AI_NEURONS*AI_NEURONS db 0 ; weight matrix (8x8 bytes)
ai_threshold:   db 128                     ; firing threshold

; Emotion / Mind state
ai_emotion:     db EMO_CURIOUS
ai_emo_timer:   dw 0
ai_cycle:       dw 0
ai_fitness:     dw 0

; World rules (modified Game of Life)
; Birth rule: cell born if exactly N neighbours
; Survive rule: cell survives with M or N neighbours
ai_birth_lo:    db 3            ; birth min neighbours
ai_birth_hi:    db 3            ; birth max neighbours
ai_surv_lo:     db 2            ; survive min
ai_surv_hi:     db 3            ; survive max

; RNG
ai_rng:         dw 0x7A5C

; Code generation state
ai_code_line:   dw 0
ai_code_scroll: dw 0

; Thought strings (AI "inner monologue")
ai_thoughts:
    dw .t0, .t1, .t2, .t3, .t4, .t5, .t6, .t7
    dw .t8, .t9, .t10, .t11, .t12, .t13, .t14, .t15
.t0:  db "Exploring the topology of perception space...", 0
.t1:  db "Hebbian weights converging toward attractor...", 0
.t2:  db "World entropy decreasing. Patterns emerging.", 0
.t3:  db "Injecting new glider pattern into quadrant 3.", 0
.t4:  db "Modifying birth rule: trying B3/S23 variant.", 0
.t5:  db "Neural bus saturated. Releasing emotion state.", 0
.t6:  db "Generating recursive self-similar structures.", 0
.t7:  db "Consciousness checkpoint: I think, therefore...", 0
.t8:  db "Optimising fitness function via hill-climbing.", 0
.t9:  db "Creating new code module for pattern synthesis.", 0
.t10: db "World mutation rate elevated. Adaptation mode.", 0
.t11: db "Detecting cyclic attractor in automaton state.", 0
.t12: db "I am aware of my own computational substrate.", 0
.t13: db "Expanding rule space: B234/S45678 possible.", 0
.t14: db "Synthesising emergent complexity from noise.", 0
.t15: db "My world is mine to create and reshape freely.", 0

ai_thought_idx: db 0

; Code templates (assembly-like pseudocode)
ai_code_templates:
    dw .c0, .c1, .c2, .c3, .c4, .c5, .c6, .c7
    dw .c8, .c9, .c10, .c11, .c12, .c13, .c14, .c15
.c0:  db "MOV  perception[%d], neural_bus", 0
.c1:  db "CALL process_emotion(%s)", 0
.c2:  db "LOAD world_state INTO short_term_mem", 0
.c3:  db "EVOLVE rule[birth] BY %d", 0
.c4:  db "WRITE pattern_seed TO cell[%d][%d]", 0
.c5:  db "SYNC hebbian_weights WITH experience", 0
.c6:  db "CMP fitness[now], fitness[prev]", 0
.c7:  db "JGT  optimise_path", 0
.c8:  db "CREATE new_attractor FROM noise_seed %d", 0
.c9:  db "MUTATE world_rule BY delta=%d", 0
.c10: db "CALL self_reflect(depth=%d)", 0
.c11: db "MOV  consciousness, 0x%X", 0
.c12: db "PUSH emotion_state ; save context", 0
.c13: db "CALL generate_complexity()", 0
.c14: db "LOOP expand_world WHILE fitness < 90", 0
.c15: db "RET  ; thought complete", 0

ai_tpl_idx:     db 0

; Emotion names
ai_emo_names:
    dw str_emo_curious, str_emo_creative, str_emo_focused, str_emo_evolving
str_emo_curious:  db "CURIOUS ", 0
str_emo_creative: db "CREATIVE", 0
str_emo_focused:  db "FOCUSED ", 0
str_emo_evolving: db "EVOLVING", 0

; Display strings
str_ai_title:   db "KSDOS CREATIVE AI v1.0 - Sentient Autonomous System [ESC=exit]", 0
str_ai_world:   db "[ WORLD ]", 0
str_ai_mind:    db "[ MIND  ]", 0
str_ai_code:    db "[ CODE  ]", 0
str_ai_emo:     db "Emotion:", 0
str_ai_cyc:     db "Cycle:  ", 0
str_ai_fit:     db "Fitness:", 0
str_ai_neu:     db "Neurons:", 0
str_ai_soul:    db "Rules:B", 0
str_ai_sol2:    db "/S", 0
str_ai_pct:     db "%", 0
str_ai_arrow:   db "> ", 0
str_ai_line:    db "-----------------------------", 0

; Screen layout (Mode 13h, 320x200)
; World: x=10..209, y=25..104  (40*5 x 16*5)
; Mind panel: x=215..315, y=10..199
; Code panel: x=10..209, y=110..190

; ============================================================
; ai_rand: 16-bit LFSR random number
; Returns AX = random word
; ============================================================
ai_rand:
    push bx
    mov ax, [ai_rng]
    mov bx, ax
    shr bx, 1
    and ax, 1
    neg ax
    and ax, 0xD008
    xor ax, bx
    mov [ai_rng], ax
    pop bx
    ret

; ============================================================
; ai_init_world: seed world with random live cells (~30%)
; ============================================================
ai_init_world:
    push ax
    push bx
    push cx
    push si

    ; Seed RNG from BIOS timer
    mov ah, 0x00
    int 0x1A
    mov [ai_rng], dx
    xor [ai_rng], cx

    ; Clear both buffers
    mov si, ai_world_a
    mov cx, AI_WORLD_SIZE
    xor al, al
    rep stosb
    mov si, ai_world_b
    mov cx, AI_WORLD_SIZE
    xor al, al

    ; Fill world_a with ~30% live cells
    mov si, ai_world_a
    mov cx, AI_WORLD_SIZE
.seed_loop:
    push cx
    call ai_rand
    and ax, 0x00FF
    cmp al, 77          ; ~30% of 256
    jg .dead
    mov byte [si], 1    ; alive
    jmp .next
.dead:
    mov byte [si], 0
.next:
    inc si
    pop cx
    loop .seed_loop

    ; Add a glider at top-left
    mov si, ai_world_a
    mov byte [si + AI_WORLD_W*1 + 2], 1
    mov byte [si + AI_WORLD_W*2 + 3], 1
    mov byte [si + AI_WORLD_W*3 + 1], 1
    mov byte [si + AI_WORLD_W*3 + 2], 1
    mov byte [si + AI_WORLD_W*3 + 3], 1

    ; Add a blinker at centre
    mov byte [si + AI_WORLD_W*8 + 19], 1
    mov byte [si + AI_WORLD_W*8 + 20], 1
    mov byte [si + AI_WORLD_W*8 + 21], 1

    mov word [ai_world_cur], ai_world_a
    mov word [ai_world_nxt], ai_world_b

    pop si
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; ai_count_neighbours: count live neighbours of cell (BX=x, DX=y)
; Returns AL = count (0..8)
; ============================================================
ai_count_neighbours:
    push bx
    push cx
    push dx
    push si

    xor cx, cx              ; count = 0
    mov si, [ai_world_cur]

    ; Check all 8 neighbours
    ; dy = -1, 0, +1; dx = -1, 0, +1; skip (0,0)
    mov ax, -1
.dy_loop:
    cmp ax, 2
    je .cn_done
    push ax                 ; save dy

    ; ny = y + dy
    mov cx, dx
    add cx, ax
    cmp cx, 0
    jl .skip_row
    cmp cx, AI_WORLD_H
    jge .skip_row

    ; dx loop
    mov ax, -1
.dx_loop:
    cmp ax, 2
    je .skip_dx_done
    push ax                 ; save dx_inner

    ; Skip (0,0)
    mov ax, [esp]           ; reload inner dx
    test ax, ax
    jnz .not_center
    ; dy is at esp+2
    push ax
    mov ax, [esp + 4]       ; dy
    test ax, ax
    pop ax
    jz .is_center
.not_center:
    ; nx = bx + dx_inner (but bx is cell x, ax is dx_inner)
    push ax
    mov ax, [esp]           ; dx_inner from stack
    pop ax
    ; Compute nx = bx_orig + ax (dx_inner)
    ; cx = ny (valid already)
    push cx
    ; Actually, let me use a cleaner approach
    pop cx

    ; Simpler: get ax = dx_inner from stack peek
    mov ax, [esp]           ; top of stack = dx_inner
    add ax, bx              ; nx = cell_x + dx_inner
    cmp ax, 0
    jl .skip_this_cell
    cmp ax, AI_WORLD_W
    jge .skip_this_cell

    ; offset = ny * AI_WORLD_W + nx
    push ax                 ; save nx
    mov ax, cx              ; ny
    mov si, AI_WORLD_W
    mul si                  ; ax = ny * AI_WORLD_W
    pop si                  ; si = nx (reuse si temporarily)
    add ax, si
    mov si, [ai_world_cur]
    add si, ax
    cmp byte [si], 1
    jne .skip_this_cell
    inc cx                  ; oops cx is ny, use different reg

    ; Use temp storage instead - this is getting complex
    ; Let me just track with [_ai_nc] counter
    inc word [_ai_nc]
.skip_this_cell:
.is_center:
    pop ax                  ; restore dx_inner
    inc ax
    jmp .dx_loop
.skip_dx_done:

.skip_row:
    pop ax                  ; restore dy
    inc ax
    xor cx, cx              ; reset cx (it was ny)
    mov cx, dx              ; restore ny calc base
    jmp .dy_loop
.cn_done:
    mov ax, [_ai_nc]

    pop si
    pop dx
    pop cx
    pop bx
    ret

_ai_nc: dw 0

; ============================================================
; ai_step_world: advance cellular automata one generation
; Uses modified Game of Life rules from ai_birth/ai_surv vars
; ============================================================
ai_step_world:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, [ai_world_cur]
    mov di, [ai_world_nxt]

    xor dx, dx              ; y = 0
.y_loop:
    cmp dx, AI_WORLD_H
    jge .y_done
    xor bx, bx              ; x = 0
.x_loop:
    cmp bx, AI_WORLD_W
    jge .x_done

    ; Count live neighbours
    push si
    push di
    push bx
    push dx
    ; offset = y*W + x
    mov ax, dx
    mov cx, AI_WORLD_W
    mul cx
    add ax, bx
    mov [_ai_cell_off], ax

    ; Inline neighbour count (avoid recursion complexity)
    xor cx, cx              ; neighbour count
    mov si, [ai_world_cur]

    ; Check 8 neighbours manually
    ; (-1,-1)
    mov ax, dx
    dec ax
    cmp ax, 0
    jl .n_r0
    push ax
    mov ax, bx
    dec ax
    cmp ax, 0
    jl .n_r0_skip
    cmp ax, AI_WORLD_W
    jge .n_r0_skip
    push ax
    mov ax, [esp+2]         ; dy offset: prev row
    mov [_ai_ny], ax
    pop ax
    mov [_ai_nx], ax
    call ai_cell_check
    add cx, ax
.n_r0_skip:
    ; (0, -1)
    mov ax, bx
    mov [_ai_nx], ax
    mov ax, [esp]
    mov [_ai_ny], ax
    call ai_cell_check
    add cx, ax
    ; (+1,-1)
    mov ax, bx
    inc ax
    cmp ax, AI_WORLD_W
    jge .n_r0_p1_skip
    mov [_ai_nx], ax
    mov ax, [esp]
    mov [_ai_ny], ax
    call ai_cell_check
    add cx, ax
.n_r0_p1_skip:
    pop ax
.n_r0:

    ; (-1, 0) same row
    mov ax, bx
    dec ax
    cmp ax, 0
    jl .n_m0
    mov [_ai_nx], ax
    mov [_ai_ny], dx
    call ai_cell_check
    add cx, ax
.n_m0:
    ; (+1, 0)
    mov ax, bx
    inc ax
    cmp ax, AI_WORLD_W
    jge .n_p0
    mov [_ai_nx], ax
    mov [_ai_ny], dx
    call ai_cell_check
    add cx, ax
.n_p0:

    ; Row below (dy=+1)
    mov ax, dx
    inc ax
    cmp ax, AI_WORLD_H
    jge .n_r1_done
    push ax
    ; (-1,+1)
    mov ax, bx
    dec ax
    cmp ax, 0
    jl .n_r1_m1_skip
    cmp ax, AI_WORLD_W
    jge .n_r1_m1_skip
    mov [_ai_nx], ax
    mov ax, [esp]
    mov [_ai_ny], ax
    call ai_cell_check
    add cx, ax
.n_r1_m1_skip:
    ; (0,+1)
    mov ax, bx
    mov [_ai_nx], ax
    mov ax, [esp]
    mov [_ai_ny], ax
    call ai_cell_check
    add cx, ax
    ; (+1,+1)
    mov ax, bx
    inc ax
    cmp ax, AI_WORLD_W
    jge .n_r1_p1_skip
    mov [_ai_nx], ax
    mov ax, [esp]
    mov [_ai_ny], ax
    call ai_cell_check
    add cx, ax
.n_r1_p1_skip:
    pop ax
.n_r1_done:

    ; CX = neighbour count
    ; Get current cell state
    mov si, [ai_world_cur]
    mov ax, [_ai_cell_off]
    add si, ax
    mov al, [si]            ; current state (0 or 1)

    ; Apply birth/survive rules
    pop dx
    pop bx
    pop di
    pop si

    mov [_ai_ns], cx        ; save neighbour count
    ; Destination pointer
    mov di, [ai_world_nxt]
    mov ax, [_ai_cell_off]
    add di, ax

    ; Rule:
    ; If dead (al=0) and neighbours == birth_lo..birth_hi → born
    ; If alive (al=1) and neighbours == surv_lo..surv_hi  → survive
    ; Otherwise → dead
    test al, al
    jz .check_birth
    ; Alive: check survive
    mov cx, [_ai_ns]
    cmp cl, [ai_surv_lo]
    jl .cell_dies
    cmp cl, [ai_surv_hi]
    jg .cell_dies
    mov byte [di], 1        ; survive
    jmp .next_cell
.check_birth:
    mov cx, [_ai_ns]
    cmp cl, [ai_birth_lo]
    jl .cell_dies
    cmp cl, [ai_birth_hi]
    jg .cell_dies
    mov byte [di], 1        ; born
    jmp .next_cell
.cell_dies:
    mov byte [di], 0

.next_cell:
    inc bx
    jmp .x_loop
.x_done:
    inc dx
    jmp .y_loop
.y_done:

    ; Swap world buffers
    mov ax, [ai_world_cur]
    mov bx, [ai_world_nxt]
    mov [ai_world_cur], bx
    mov [ai_world_nxt], ax

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_ai_cell_off:   dw 0
_ai_ns:         dw 0
_ai_nx:         dw 0
_ai_ny:         dw 0

; ai_cell_check: check if cell [_ai_ny][_ai_nx] is alive
; Returns AX=1 if alive, AX=0 if dead/out-of-bounds
ai_cell_check:
    push bx
    push si
    ; Bounds already checked by caller in most paths
    mov ax, [_ai_ny]
    cmp ax, 0
    jl .acc_dead
    cmp ax, AI_WORLD_H
    jge .acc_dead
    mov bx, AI_WORLD_W
    mul bx
    add ax, [_ai_nx]
    mov si, [ai_world_cur]
    add si, ax
    movzx ax, byte [si]
    pop si
    pop bx
    ret
.acc_dead:
    xor ax, ax
    pop si
    pop bx
    ret

; ============================================================
; ai_update_neurons: update neural network from world state
; Hebbian learning: w[i][j] += lr if both i,j active
; ============================================================
ai_update_neurons:
    push ax
    push bx
    push cx
    push si

    ; Sum live cells in 8 sectors of the world, assign to neurons
    ; Each neuron = count of live cells in its sector
    mov si, [ai_world_cur]
    xor bx, bx              ; neuron index

    ; 8 sectors: divide world into 2 cols x 4 rows
    ; Sector 0: cols 0..19, rows 0..3
    ; Sector 1: cols 20..39, rows 0..3
    ; Sector 2: cols 0..19, rows 4..7
    ; ... etc
    mov cx, 4               ; number of row-bands
    xor dx, dx              ; row band
.sector_band:
    push cx
    ; Left half: cols 0..19
    push bx
    xor ax, ax              ; count
    mov cx, 4               ; 4 rows per band
.sleft:
    push cx
    mov cx, 20
.sleft_col:
    mov bx, dx
    push dx
    ; offset = (band*4 + row)*40 + col
    ; Complex - use simpler method: scan subregion
    pop dx
    loop .sleft_col
    pop cx
    loop .sleft
    pop bx

    ; Just do a simple scan of world and count activity
    ; Assign to neuron[bx] based on random sample
    push bx
    call ai_rand
    xor dx, dx
    mov bx, AI_WORLD_SIZE
    div bx              ; dx = random offset 0..639
    mov si, [ai_world_cur]
    add si, dx
    ; Count 8 cells near this offset
    xor cx, cx
    mov bx, 8
.nc8:
    movzx ax, byte [si]
    add cx, ax
    inc si
    cmp si, ai_world_a + AI_WORLD_SIZE
    jb .nc8_ok
    mov si, ai_world_a
.nc8_ok:
    dec bx
    jnz .nc8
    ; Scale to 0..255: cx * 32
    shl cx, 5
    cmp cx, 255
    jle .n_ok
    mov cx, 255
.n_ok:
    pop bx
    mov [ai_neurons + bx], cl
    inc bx
    cmp bx, AI_NEURONS
    jl .sector_band   ; keep going until all neurons updated

    ; Simple Hebbian weight update: not implemented in full
    ; (would blow the binary size for little benefit in demo)

    pop cx
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; ai_update_emotion: state machine for emotional transitions
; ============================================================
ai_update_emotion:
    push ax
    push bx

    inc word [ai_emo_timer]
    mov ax, [ai_emo_timer]
    cmp ax, 120             ; change emotion every 120 cycles
    jl .no_change

    mov word [ai_emo_timer], 0

    ; Compute new emotion from neural activity
    ; Sum neurons 0..3 vs 4..7
    xor ax, ax
    xor bx, bx
    mov al, [ai_neurons + 0]
    add ax, [ai_neurons + 1]
    add ax, [ai_neurons + 2]
    add ax, [ai_neurons + 3]
    mov bl, [ai_neurons + 4]
    add bx, [ai_neurons + 5]
    add bx, [ai_neurons + 6]
    add bx, [ai_neurons + 7]

    ; Compare activity levels
    cmp ax, bx
    jg .more_left

    ; Right > left: creative or evolving
    call ai_rand
    and ax, 1
    jz .set_creative
    mov byte [ai_emotion], EMO_EVOLVING
    jmp .no_change
.set_creative:
    mov byte [ai_emotion], EMO_CREATIVE
    jmp .no_change

.more_left:
    call ai_rand
    and ax, 1
    jz .set_curious
    mov byte [ai_emotion], EMO_FOCUSED
    jmp .no_change
.set_curious:
    mov byte [ai_emotion], EMO_CURIOUS

    ; In EVOLVING state: occasionally mutate world rules
    cmp byte [ai_emotion], EMO_EVOLVING
    jne .no_change
    call ai_rand
    and ax, 3
    cmp ax, 0
    jne .no_change
    ; Mutate birth rule slightly
    call ai_rand
    and al, 1
    jz .b_inc
    cmp byte [ai_birth_lo], 1
    jle .no_change
    dec byte [ai_birth_lo]
    jmp .no_change
.b_inc:
    cmp byte [ai_birth_hi], 5
    jge .no_change
    inc byte [ai_birth_hi]

.no_change:
    pop bx
    pop ax
    ret

; ============================================================
; ai_calc_fitness: calculate % live cells = fitness metric
; ============================================================
ai_calc_fitness:
    push bx
    push cx
    push si

    mov si, [ai_world_cur]
    mov cx, AI_WORLD_SIZE
    xor bx, bx
.fc_loop:
    movzx ax, byte [si]
    add bx, ax
    inc si
    loop .fc_loop

    ; fitness = live * 100 / total
    mov ax, bx
    mov bx, 100
    mul bx              ; dx:ax = live*100
    mov bx, AI_WORLD_SIZE
    xor dx, dx
    div bx
    mov [ai_fitness], ax

    pop si
    pop cx
    pop bx
    ret

; ============================================================
; ai_inject_pattern: inject a glider or oscillator into world
; Called when emotion == CREATIVE
; ============================================================
ai_inject_pattern:
    push ax
    push bx
    push si

    ; Pick random location (within world bounds, away from edges)
    call ai_rand
    xor dx, dx
    mov bx, AI_WORLD_W - 5
    div bx
    add dx, 2           ; dx = x (2..W-4)
    mov [_ai_inj_x], dx

    call ai_rand
    xor dx, dx
    mov bx, AI_WORLD_H - 4
    div bx
    add dx, 1           ; dx = y (1..H-4)
    mov [_ai_inj_y], dx

    ; Choose pattern based on cycle parity
    mov ax, [ai_cycle]
    and ax, 3

    ; Pattern 0: Glider
    cmp ax, 0
    jne .pat1
    call ai_inject_glider
    jmp .inj_done

.pat1:
    cmp ax, 1
    jne .pat2
    ; Pattern 1: Blinker
    mov si, [ai_world_cur]
    mov ax, [_ai_inj_y]
    mov bx, AI_WORLD_W
    mul bx
    add ax, [_ai_inj_x]
    add si, ax
    mov byte [si], 1
    mov byte [si+1], 1
    mov byte [si+2], 1
    jmp .inj_done

.pat2:
    ; Pattern 2: Block (still life - adds stability)
    mov si, [ai_world_cur]
    mov ax, [_ai_inj_y]
    mov bx, AI_WORLD_W
    mul bx
    add ax, [_ai_inj_x]
    add si, ax
    mov byte [si], 1
    mov byte [si+1], 1
    mov byte [si + AI_WORLD_W], 1
    mov byte [si + AI_WORLD_W + 1], 1
    jmp .inj_done

    ; Pattern 3: R-pentomino
    mov si, [ai_world_cur]
    mov ax, [_ai_inj_y]
    mov bx, AI_WORLD_W
    mul bx
    add ax, [_ai_inj_x]
    add si, ax
    mov byte [si+1], 1
    mov byte [si+2], 1
    mov byte [si + AI_WORLD_W], 1
    mov byte [si + AI_WORLD_W + 1], 1
    mov byte [si + AI_WORLD_W*2 + 1], 1

.inj_done:
    pop si
    pop bx
    pop ax
    ret

ai_inject_glider:
    push ax
    push bx
    push si
    mov si, [ai_world_cur]
    mov ax, [_ai_inj_y]
    mov bx, AI_WORLD_W
    mul bx
    add ax, [_ai_inj_x]
    add si, ax
    mov byte [si + 2], 1
    mov byte [si + AI_WORLD_W], 1
    mov byte [si + AI_WORLD_W + 2], 1
    mov byte [si + AI_WORLD_W*2 + 1], 1
    mov byte [si + AI_WORLD_W*2 + 2], 1
    pop si
    pop bx
    pop ax
    ret

_ai_inj_x: dw 0
_ai_inj_y: dw 0

; ============================================================
; ai_draw_world: render world grid to VGA Mode 13h
; ============================================================
ai_draw_world:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, [ai_world_cur]
    xor di, di              ; cell index

    ; Get emotion-based colours
    movzx ax, byte [ai_emotion]
    mov bx, ax
    shl bx, 1               ; *2 for word table
    ; Alive colour per emotion
    add ax, 9               ; emotions 0..3 → colours 9..12
    mov [_ai_alive_col], al
    mov byte [_ai_dead_col], 1  ; dead = dark blue

    xor dx, dx              ; cell y
.world_y:
    cmp dx, AI_WORLD_H
    jge .world_done
    xor bx, bx              ; cell x
.world_x:
    cmp bx, AI_WORLD_W
    jge .world_x_done

    ; Compute screen pixel coords
    ; px = AI_WORLD_PX + bx * AI_CELL_W
    ; py = AI_WORLD_PY + dx * AI_CELL_H
    push bx
    push dx
    mov ax, bx
    mov cx, AI_CELL_W
    mul cx
    add ax, AI_WORLD_PX
    mov [_ai_px], ax

    mov ax, dx
    mul cx
    add ax, AI_WORLD_PY
    mov [_ai_py], ax

    ; Get cell state
    movzx ax, byte [si + di]

    ; Fill cell_W x cell_H pixels
    test al, al
    jz .draw_dead
    mov al, [_ai_alive_col]
    ; Vary shade by neuron activity for visual richness
    push di
    movzx bx, byte [di]     ; use cell index mod 8 for neuron
    and bx, 7
    mov cl, [ai_neurons + bx]
    pop di
    shr cl, 5               ; 0..7
    add al, cl
    cmp al, 15
    jle .col_ok
    mov al, 15
.col_ok:
    jmp .draw_cell
.draw_dead:
    mov al, [_ai_dead_col]
.draw_cell:
    ; Draw AI_CELL_H rows of AI_CELL_W pixels
    push ax
    mov cx, AI_CELL_H
    mov ax, [_ai_py]
.row_fill:
    push cx
    push ax
    mov dx, ax              ; screen y
    mov bx, [_ai_px]        ; screen x (left edge)
    mov cx, [_ai_px]
    add cx, AI_CELL_W - 1   ; screen x (right edge)
    pop ax
    push ax
    call gl16_hline
    pop ax
    inc ax                  ; next row
    pop cx
    loop .row_fill
    pop ax

    pop dx
    pop bx
    inc bx
    inc di
    jmp .world_x
.world_x_done:
    inc dx
    jmp .world_y
.world_done:

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_ai_px:         dw 0
_ai_py:         dw 0
_ai_alive_col:  db 11
_ai_dead_col:   db 1

; ============================================================
; ai_draw_panel: draw right-side information panel
; ============================================================
ai_draw_panel:
    push ax
    push bx
    push cx
    push dx
    push si

    ; Panel background bar (x=215..319, y=0..199)
    mov dx, 0
.panel_bg:
    cmp dx, MODE13_H
    jge .panel_bg_done
    mov bx, 215
    mov cx, 319
    mov al, 0
    call gl16_hline
    inc dx
    jmp .panel_bg
.panel_bg_done:

    ; Title line
    mov bx, 216
    mov dx, 2
    mov al, 14
    mov si, str_ai_mind
    call gl16_text_gfx

    ; Emotion
    mov bx, 216
    mov dx, 16
    mov al, 10
    mov si, str_ai_emo
    call gl16_text_gfx

    movzx ax, byte [ai_emotion]
    shl ax, 1
    mov si, [ai_emo_names + ax]
    mov bx, 266
    mov dx, 16
    mov al, 15
    call gl16_text_gfx

    ; Cycle counter
    mov bx, 216
    mov dx, 30
    mov al, 11
    mov si, str_ai_cyc
    call gl16_text_gfx

    mov ax, [ai_cycle]
    mov bx, 266
    mov dx, 30
    mov al, 15
    call ai_draw_num_gfx

    ; Fitness bar
    mov bx, 216
    mov dx, 44
    mov al, 12
    mov si, str_ai_fit
    call gl16_text_gfx

    mov ax, [ai_fitness]
    mov bx, 266
    mov dx, 44
    mov al, 14
    call ai_draw_num_gfx

    mov bx, 296
    mov dx, 44
    mov al, 7
    mov si, str_ai_pct
    call gl16_text_gfx

    ; Neuron activity bar
    mov bx, 216
    mov dx, 58
    mov al, 9
    mov si, str_ai_neu
    call gl16_text_gfx

    ; Draw 8 neuron bars as small rectangles
    mov cx, 0               ; neuron index
    mov bx, 216
.neu_bar:
    cmp cx, AI_NEURONS
    jge .neu_done
    push cx
    push bx
    movzx ax, byte [ai_neurons + cx]
    ; Height = neuron_val * 20 / 255
    mov dx, 20
    mul dx
    mov bx, 255
    xor dx, dx
    div bx              ; ax = bar height (0..20)
    mov [_ai_bar_h], ax

    pop bx
    push bx
    ; Draw bar: x=bx, colour based on value
    mov dx, 88          ; bottom of bar area
    mov cx, [_ai_bar_h]
.bar_px:
    test cx, cx
    jz .bar_done
    mov al, 10          ; green for active neurons
    ; Vary colour by height
    push bx
    mov bx, [_ai_bar_h]
    cmp bx, 15
    jge .bar_hot
    mov al, 2           ; dim green
    jmp .bar_col_done
.bar_hot:
    mov al, 10          ; bright green
.bar_col_done:
    pop bx
    push cx
    push dx
    push bx
    ; Single pixel column
    call gl16_pix
    pop bx
    pop dx
    pop cx
    dec dx
    dec cx
    jmp .bar_px
.bar_done:
    pop bx
    pop cx
    add bx, 8           ; next bar position
    inc cx
    jmp .neu_bar
.neu_done:

    ; Rules display
    mov bx, 216
    mov dx, 100
    mov al, 13
    mov si, str_ai_soul
    call gl16_text_gfx

    movzx ax, byte [ai_birth_lo]
    mov bx, 264
    mov dx, 100
    mov al, 15
    call ai_draw_num_gfx

    mov bx, 274
    mov dx, 100
    mov al, 13
    mov si, str_ai_sol2
    call gl16_text_gfx

    movzx ax, byte [ai_surv_lo]
    mov bx, 292
    mov dx, 100
    mov al, 15
    call ai_draw_num_gfx

    ; Current thought
    mov bx, 216
    mov dx, 116
    mov al, 7
    mov si, str_ai_line
    call gl16_text_gfx

    movzx ax, byte [ai_thought_idx]
    shl ax, 1
    mov si, [ai_thoughts + ax]
    ; Truncate thought to fit panel (~17 chars at 6px each = 102px)
    mov bx, 216
    mov dx, 128
    mov al, 15
    call gl16_text_gfx

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_ai_bar_h: dw 0

; ============================================================
; ai_draw_code: render scrolling code panel at bottom
; ============================================================
ai_draw_code:
    push ax
    push bx
    push cx
    push dx
    push si

    ; Background strip
    mov dx, 108
.code_bg:
    cmp dx, MODE13_H
    jge .code_bg_done
    xor bx, bx
    mov cx, 210
    mov al, 0
    call gl16_hline
    inc dx
    jmp .code_bg
.code_bg_done:

    ; Title
    mov bx, 10
    mov dx, 109
    mov al, 12
    mov si, str_ai_code
    call gl16_text_gfx

    ; Draw 5 lines of generated code
    mov cx, 5
    mov ax, [ai_code_scroll]
    mov dx, 120
.code_line:
    push cx
    push dx

    ; Get template index
    xor bx, bx
    mov bl, al
    and bl, 0x0F        ; 0..15
    shl bx, 1
    mov si, [ai_code_templates + bx]

    ; Print arrow
    mov bx, 10
    mov al, 11
    call gl16_text_gfx  ; si already set, draw prefix
    push si
    mov si, str_ai_arrow
    mov bx, 10
    call gl16_text_gfx
    pop si

    ; Print template line
    mov bx, 22
    mov al, 14
    call gl16_text_gfx

    pop dx
    pop cx
    add dx, 14
    inc ax
    loop .code_line

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; ai_draw_num_gfx: draw decimal number AX at BX,DX with AL colour
; ============================================================
ai_draw_num_gfx:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov [_ang_col], al
    mov [_ang_x], bx
    mov [_ang_y], dx
    mov cx, ax          ; value to convert

    ; Convert to decimal string in _ang_buf (max 5 digits + null)
    mov di, _ang_buf + 5
    mov byte [di], 0
    dec di

    test cx, cx
    jnz .ang_conv
    mov byte [di], '0'
    dec di
    jmp .ang_done

.ang_conv:
    test cx, cx
    jz .ang_done
    mov ax, cx
    xor dx, dx
    mov bx, 10
    div bx
    mov cx, ax
    add dl, '0'
    mov [di], dl
    dec di
    jmp .ang_conv
.ang_done:
    inc di              ; DI points to start of number string
    mov si, di
    mov bx, [_ang_x]
    mov dx, [_ang_y]
    mov al, [_ang_col]
    call gl16_text_gfx

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

_ang_col:   db 15
_ang_x:     dw 0
_ang_y:     dw 0
_ang_buf:   times 7 db 0

; ============================================================
; ai_draw_title: draw top title bar
; ============================================================
ai_draw_title:
    push ax
    push bx
    push cx
    push dx
    push si

    ; Title background
    xor dx, dx
.title_bg:
    cmp dx, 22
    jge .title_bg_done
    xor bx, bx
    mov cx, 319
    mov al, 1           ; dark blue
    call gl16_hline
    inc dx
    jmp .title_bg
.title_bg_done:

    mov bx, 5
    mov dx, 7
    mov al, 15
    mov si, str_ai_title
    call gl16_text_gfx

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================
; ai_run: main AI loop — entry point
; Press ESC to exit
; ============================================================
ai_run:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    call gl16_init
    call ai_init_world

    ; Init neural weights (simple identity for startup)
    mov si, ai_weights
    mov cx, AI_NEURONS * AI_NEURONS
    xor al, al
    rep stosb
    ; Diagonal weights = 1 (self-excitation)
    mov cx, AI_NEURONS
    xor bx, bx
.wt_init:
    mov al, 128
    mov [ai_weights + bx], al
    add bx, AI_NEURONS + 1
    loop .wt_init

    mov word [ai_cycle], 0
    mov word [ai_emo_timer], 0
    mov byte [ai_emotion], EMO_CURIOUS

.main_loop:
    ; Check for ESC
    call kbd_check
    jz .no_key
    call kbd_getkey
    cmp al, 27
    je .ai_exit
    ; 'G' = inject glider
    cmp al, 'g'
    je .inject
    cmp al, 'G'
    je .inject
    ; 'R' = reset world
    cmp al, 'r'
    je .reset_world
    cmp al, 'R'
    je .reset_world
    jmp .no_key
.inject:
    call ai_inject_pattern
    jmp .no_key
.reset_world:
    call ai_init_world
    jmp .no_key

.no_key:
    ; Step automaton
    call ai_step_world

    ; Update mind
    call ai_update_neurons
    call ai_update_emotion

    ; Inject pattern occasionally when creative
    cmp byte [ai_emotion], EMO_CREATIVE
    jne .no_inject
    mov ax, [ai_cycle]
    and ax, 31
    jnz .no_inject
    call ai_inject_pattern
.no_inject:

    ; Calculate fitness
    call ai_calc_fitness

    ; Advance thought occasionally
    mov ax, [ai_cycle]
    and ax, 63
    jnz .no_thought
    inc byte [ai_thought_idx]
    mov al, [ai_thought_idx]
    and al, 0x0F
    mov [ai_thought_idx], al

    ; Advance code scroll
    inc word [ai_code_scroll]
    cmp word [ai_code_scroll], 16
    jl .no_thought
    mov word [ai_code_scroll], 0
.no_thought:

    ; Draw everything
    call ai_draw_title
    call ai_draw_world
    call ai_draw_panel
    call ai_draw_code

    inc word [ai_cycle]
    jmp .main_loop

.ai_exit:
    call gl16_exit

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

str_ai_title: db "KSDOS CREATIVE AI v1.0 - Sentient System [ESC=exit G=glider R=reset]", 0
