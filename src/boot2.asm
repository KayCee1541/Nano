bits 16
org 0x9000

mov bx, 0x8200
mov si, bx
mov bx, 0
; get functions from stage 1
mov bx, word[si]
mov word[CLus_Sect], bx
add si, 2
mov bx, word[si]
mov word[Print], bx
add si, 2
mov bx, word[si]
mov word[LBATOCHS], bx

mov cx, SUCCESS_MSG
call print


halt:
    cli
    hlt

print:
    push ax
    mov ax, word[Print]
    call ax
    pop ax
    ret

Clus_Sect:
    push ax
    mov ax, word[CLus_Sect]
    call ax
    pop ax
    ret

LBAtoCHS:
    push ax
    mov ax, word[LBATOCHS]
    call ax
    pop ax
    ret

CLus_Sect: db 0, 0
Print: db 0, 0
LBATOCHS: db 0, 0
SUCCESS_MSG: db "Stage 2 loaded, getting ready to load the kernel...", 0