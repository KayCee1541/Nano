[bits 16]
[org 0x7c00]
[cpu 8086]

BPB:
    db 0xeb, 0x3c, 0x90
    OEM_IDEN: db "        "
    BYTE_SEC: dw 0
    SEC_CLUS: db 0
    RES_SECT: dw 0
    NUM_FATS: db 0
    NUM_RDES: dw 0 ; This value will be ignored
    TOTL_SEC: dw 0
    MED_DESC: db 0
    SEC_FATS: dw 0
    SEC_TRCK: dw 0
    NUM_HEAD: dw 0
    HIDD_SEC: dd 0
    TOT_SECL: dd 0
    DRIV_NUM: db 0 ; ignore value
    FLAG_VAL: db 0 ; if this value equals zero, we are booting from a floppy
    SIGNATUR: db 0x28
    VID_SERI: dd 0
    VOL_LABL: db "           "
    SYS_IDEN: dq 0

Start:
; set up stack
mov ax, 0
mov ss, ax
mov sp, 0x7c00

; Write to screen
mov ax, 0x00
mov ds, ax
mov si, MESSAGE
call PrintScr
cli
hlt

; Screen subroutine
PrintScr: ; ds:si = address of string to write
    push ax
    push bx
    mov ah, 0x0e
    mov bl, 0x07
.PrintChar:
    mov al, [ds:si]
    inc si
    or al, al
    jz .Exit
    int 0x10
    jmp .PrintChar
.Exit:
    pop bx
    pop ax
    ret

MESSAGE: db "THIS IS A TEST OF THE BOOTLOADER AND DISK FORMATTING ROUTINES. HALTING...", 0

times 510-($-$$) db 0
db 0x55, 0xaa