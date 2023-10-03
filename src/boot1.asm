bits 16
org 0x7c00

mov ah, 0
mov al,03h ; set video mode to be 80x25 video
int 10h


xor ax, ax
mov ss, ax
mov ds, ax
mov es, ax ; set registers to 0

mov bp, 7c00h
mov ss, ax
mov sp, bp ; set up stack

call print
call halt

print:
    push si
    push bx
    push es
    push di
    push cx
    ; save all registers we will destroy

    mov ax, 0xb800
    mov es, ax
    mov cx, BOOT_MSG
    xor bx, bx
    xor cx, cx
    xor ax, ax
    mov si, ax

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
    push si

    mov si, BOOT_MSG
    mov al, byte [si + bx] ; write character at index bx in the string to al
    mov ah, 07h ; set color to black and white

    pop si 
    or al, al ; check if the loaded character is null
    jz .end ; if so, jump to .end

    mov word [es:si],ax ; if not, write the character to proper memory location
    inc si ; increment address
    inc si
    inc bx
    jmp .loop ; do it all over again

.end:
    pop cx
    pop di
    pop es
    pop bx
    pop si

    ret

halt:
    cli
    hlt

BOOT_MSG: db "Booting...", 0
times 510-($-$$) db 0
db 0x55
db 0xAA