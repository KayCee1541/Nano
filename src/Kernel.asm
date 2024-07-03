[org 0x70000]
[cpu 186]

; Boot Code
mov ax, 0x7000
mov ds, ax

; necessary functions
MCOPY: ; es:si source memory location, fs:di destination memory location, ax number of bytes to transfer
    push bx
.loop1:
    or ax, ax
    jz .end
    mov bl, byte [es:si]
    mov byte [fs:di], bl
    dec ax
    jmp .loop1
.end:
    pop bx
    ret

; INTERRUPT HANDLERS
INT80:  ; DRAW CHARACTER
        ; INPUTS: ah = character color, al = character ascii, bh = Y position, bl = X position
    

; GLOBAL DATA
