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

; initialize ps/2 controller
mov al, 0xAD ; disable port 1
out 0x64, al
wait3:
    in al, 0x64
    and al, 1 ; check if bit 1 is set
    jnz wait3

mov al, 0xA7 ; disable port 2
out 0x64, al
wait4:
    in al, 0x64
    and al, 1 ; check if bit 1 is set
    jnz wait4

in al, 0x60 ; clear output buffer
mov al, 0x20
out 0x64, al
wait5:
    in al, 0x64
    and al, 1 ; check if bit 1 is set
    jnz wait5

in al, 0x60
mov cl, al
and cl, 0x43 ; see which bits 0, 1, and/or 6 are set
xor al, cl ; clear bits 0, 1, 6
out 0x60, al
mov al, 0x60
out 0x64, al ; tell controller to set configuration
wait6:
    in al, 0x64
    and al, 1 ; check if bit 1 is set
    jnz wait6

mov al, 0xAA ; perform controller self-test
out 0x64, al
wait1:
    in al, 0x60
    cmp al, 0x55
    jz .pass
    cmp al, 0xFC
    jz .fail
    jmp wait1 ; wait for response from ps/2 controller

.fail:
    mov cx, PS2_FAIL_MSG
    call print
    call halt

.pass:
mov al, 0xAB
out 0x64, al
wait2:
    in al, 0x60
    or al, al
    jz .pass
    cmp al, 0x05
    js .fail
    jmp wait2 ; wait for response from ps/2 controller

.fail:
    mov cx, PS2_FAIL_MSG
    call print
    call halt

.pass:
mov al, 0xAE
out 0x64, al
wait7:
    in al, 0x64
    and al, 1 ; check if bit 1 is set
    jnz wait7

mov cx, PS2_PASS_MSG
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
PS2_FAIL_MSG: db "PS/2 CONTROLLER FAILED TEST, STOPPING...", 0
PS2_PASS_MSG: db "PS/2 controller passed test", 0
PS2_START_INIT: db "Setting up PS/2 controller...", 0