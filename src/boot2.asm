bits 16
org 0x8000

; transfer over important data:
mov byte[TERM_ROW], al

mov cx, SUCCESS_MSG
call print
cli
hlt

print:
    ; cx will be the address of the message we want to print, make sure to save cx before destroying it
    push bx
    push es
    push di
    push ax
    ; save all registers we will destroy

    mov ax, 0xb800
    mov es, ax
    xor bx, bx
    xor ax, ax

    mov di, TERM_ROW
    mov al, byte[di]
    mov bl, 160
    mul bl
    mov di, ax
    xor ax, ax
    xor bx, bx

    ; can only use es and si for addressing, and we are addressing multiple memory locations.
    ; Idea:
    ; at start of .loop, si points to an address in video memory. We push this value to the stack,
    ; then set si to BOOT_MSG. We get the next character, then pop the original video memory address
    ; back to si. 

    ; color:
    ; 0 = black
    ; 1 = blue
    ; 2 = green
    ; 3 = cyan
    ; 4 = red
    ; 5 = purple
    ; 6 = brown
    ; 7 = gray 1
    ; 8 = gray 2
    ; 9 = light blue
    ; A = light green
    ; B = light cyan
    ; C = light red
    ; D = light purple
    ; E = light yellow
    ; F = white
    ; color goes bg:fg
.loop:
    push di

    mov di, cx
    mov al, byte [di + bx] ; move character at index bx in the string to al
    mov ah, 07h ; set color to black and white

    pop di 
    or al, al ; check if the loaded character is null
    jz .end ; if so, jump to .end

    mov word [es:di],ax ; if not, write the character to proper memory location
    add di, 2 ; increment address
    inc bx
    jmp .loop ; do it all over again

.end:
    mov ax, 0
    mov es, ax
    mov di, TERM_ROW
    mov al, byte[di]
    inc al
    mov byte[es:di], al

    pop ax
    pop di
    pop es
    pop bx

    ret

SUCCESS_MSG: db "SUCCESS!", 0
TERM_ROW: db 0