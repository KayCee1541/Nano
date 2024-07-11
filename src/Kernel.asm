[org 0x70000]
[cpu 286]

; Boot Code
mov ax, 0x7000
mov ds, ax

mov si, Hello_World
call Print

Halt:
    cli
    hlt

Print: ; si contains address of null-terminated string to print
    pusha
    mov ah, 0x0e
    mov bh, 0
    mov bl, 0x03
.loop1:
    mov al, byte [si]
    or al, al
    jz .end
    int 0x10
    inc si
    jmp .loop1
.end:
    popa
    ret

; GLOBAL DATA
Hello_World: db "Hello World!", 0