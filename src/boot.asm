bits 16
org 0x7c00

; following info will be filled in by the disk loader
db 0xeb, 0x19, 0x90 ; jump over disk format info
OEM_IDEN: db 'nano'
BYTE_SEC: db 0, 1 ; 512 bytes per sector
SEC_CLUS: db 0
RES_SECT: db 0, 0
NUM_FATS: db 0
FAT_SIZE: db 0, 0, 0, 0
NUM_RTDE: db 0, 0
SEC_COUN: db 0, 0, 0, 0
MEDIA_DT: db 0
DRIV_NUM: db 0x80

mov bp, 0x7c00
xor ax, ax
mov ss, ax
mov sp, bp ; set up stack

mov ah, 0
mov al,0x03 ; set video mode to be 80x25 video
int 10h

; read root directory
; eax will contain absolute sector number to read, bx will contain number of sectors to read
; compute number of sectors (1 cluster) first
mov ax, 1
mov bx, [SEC_CLUS]
mul bx
mov bx, ax
mov eax, [FAT_SIZE]
mov bx, [NUM_FATS]
mul bx
xor ebx, ebx
mov bx, [RES_SECT]
add eax, ebx
xor cx, cx
mov es, cx
mov cx, 0x8020
mov di, cx
call ReadDisk

; because we wrote it to 0x8020, we will begin reading from the root directory there
mov ecx, READ_FILES_RDIR
call Print
mov eax, 0x8020
READ_ROOT_DIRECTORY:
    mov dl, [eax]
    or dl, dl
    jz .end
    mov ebx, FILENAME_BUFF
    mov ecx, 8
    call mcopy
    mov ebx, FILE_EXT_BUFF
    mov ecx, 3
    call mcopy
    add eax, 24 ; already added 8 during mcopy, then adding another 24 = 32
    mov ecx, FILENAME_BUFF
    call Print
    jmp READ_ROOT_DIRECTORY
.end:

mov ecx, READ_FILES_END
call Print

Halt:
    cli
    hlt

Print: ; ecx = address of null-terminated string to write
    push ax
    push bx
    mov bx, 0x0007 ; bh = 0x00, bl = 0x07. bh = page, bl = color to print
    mov ah, 0Eh
.printchar:
    mov al, [ecx]
    or al, al
    jz .end
    cmp al, 0x0a ; due to a bug, if character is a feedline, we will need to do it manually
    jmp .newline
    int 10h
    inc ecx
    jmp .printchar

.newline:
    push eax
    push ebx
    push ecx
    push edx
    mov ah, 0x03
    mov bh, 0
    int 10h ; get cursor position
    inc dh ; zero out dh
    xor dl, dl ; zero out dl
    mov ah, 0x02 ; set cursor position
    mov bh, 0
    int 10h
    pop edx
    pop ecx
    pop ebx
    pop eax
    jmp .printchar

.end:
    pop bx
    pop ax
    ret

ReadDisk: ; eax = absolute sector number, bx = number of sectors to read, es = segment of transfer buffer, di = offset of transfer buffer.
    ; Transfer buffer must be 2 byte aligned
    ; This subroutine will automatically generate the disk address packet
    ; disk address packet will start at 0x8000
    push cx
    mov cl, 16
    mov [0x8000], cl
    xor cl, cl
    mov [0x8001], cl
    mov [0x8002], bx
    mov [0x8004], di
    mov [0x8006], es
    mov [0x8008], eax
    xor eax, eax
    mov [0x800C], eax

    mov ds, ax
    mov ax, 0x8000
    mov si, ax
    mov ah, 0x42
    mov dl, [DRIV_NUM]
    int 13h
    jc .error
    pop cx
    ret

.error:
    mov ecx, DISK_READ_ERR
    call Print
    jmp Halt

mcopy: ; eax = source, ebx = destination, ecx = number of bytes to copy
    push dx
.loop1:
    or ecx, ecx
    jz .end
    mov dl, [eax]
    mov [ebx], dl
    inc eax
    inc ebx
    dec ecx
    jmp .loop1
.end:
    pop dx
    ret
    

READ_FILES_RDIR: db "AVAIL. FILES:", 0x0a, 0
READ_FILES_END: db "ALL FILES LISTED", 0x0a, 0
DISK_READ_ERR: db "E1", 0
NO_FILES_FOUND_ERR: db "E2", 0
FILENAME_BUFF: db 0, 0, 0, 0, 0, 0, 0, 0, "." ; end with period to signify difference between name and extension
FILE_EXT_BUFF: db 0, 0, 0, 0x0a, 0 ; end with linefeed then null
times 510-($-$$) db 0
db 0x55, 0xaa