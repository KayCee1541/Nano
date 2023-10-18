; BOOT1 CAN ONLY READ UP TO SECTOR 65535, DO NOT PUT STAGE 2 ANY HIGHER THAN 65535


bits 16
org 0x7c00

; BPD, in little endian
db 0xeb, 0x3c, 0x90 ; jump over bpd and ebbr
OEM_IDEN: db "nanoboot" ; oem identifier
SEC_SIZE: db 0x00, 0x02 ; sector size (512)
SEC_CLUS: db 0x04 ; sectors per cluster
RES_SECT: db 0x02, 0x00 ; reserved sectors
NUM_FATS: db 0x02 ; # of fats
ROOT_ENT: db 0x00 ; root directory entries
TOT_SECT: db 0x00, 0x00 ; total sectors (0 if more than 65535)
MED_DESC: db 0x00 ; media descriptor type
SECT_FAT: db 0x00, 0x01 ; sectors per fat
SEC_TRCK: db 0x3f ; sectors per track
NUM_HEAD: db 0x00, 0x00 ; number of heads
NUM_HSEC: db 0x00, 0x00, 0x00, 0x00 ; number of hidden sectors
SECT_EXT: db 0xde, 0xff, 0x03, 0x00 ; Large sector count, used if # of sectors exceeds 65535

; EBBR
DRIV_NUM: db 0x80 ; drive number, 0x80 for hdd
FAT_TYPE: db 0x10 ; specify FAT type, in this case fat 16
EXT_BOOT: db 0x29 ; extended boot signature
VOLID_SN: db 0x00, 0x00, 0x00, 0x00 ; volumeid serial number, unused
VOL_LABL: db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ; volume label, unused
FAT_LABL: db "fat16", 0x20, 0x20, 0x20 ; label for FAT type, for redundancy

; resrved sectors goes until sector 2
; FATs goes from sector 2 until sector 514
; directory table goes from sector 516 until sector 4612
jmp start ; jump over error code and hex buffer

ERR_CODE: db 0,0,0
HEX_BUFF: db "0123456789ABCDEF", 0

start:

mov ah, 0
mov al,03h ; set video mode to be 80x25 video
int 10h

mov bp, 7c00h
mov ss, ax
mov sp, bp ; set up stack

clearscreen:
    mov ax, 0xb800
    mov es, ax
    xor ax, ax
    mov di, ax
    mov bx, ax
    mov al, " "
    mov ah, 0x00
.loop:
    mov cx, 2000
    mov word[es:di], ax
    add di, 2
    inc bx
    sub cx, bx
    jz .end
    jmp .loop


.end:

xor ax, ax
mov bx, ax
mov cx, ax
mov dx, ax
mov di, ax
mov ss, ax
mov ds, ax
mov es, ax ; set registers to 0

push cx
mov cx, BOOT_MSG
call print
pop cx

call read_disk

halt:
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

read_disk:

    xor ax, ax ; make sure AX is cleared in case error occurs

    ; get drive parameters
    mov es, ax
    mov di, ax ; protect in case bios bugs
    mov ah, 0x08
    mov dl, 0x80
    int 13h

    jc error ; jump if error occurs
    add ah, 0
    jnz error ; jump if status code is not 0
    
    ; write drive params to memory
    and cl, 0x3f
    mov byte[SEC_TRCK], cl
    inc dh
    mov byte[NUM_HEAD], dh

    clc ; load stage 1.5 into memory
    mov ax, 1
    call LBAtoCHS
    mov al, 1
    mov dl, 0x80
    mov bx, 0
    mov es, bx
    mov bx, 0x7e00
    int 13h

    jc error ; jump if error occurs
    add ah, 0
    jnz error ; jump if status code is not 0

    

error:
    mov al, ah
    mov ah, 0 ; transfer error code into al and zero ah

    mov cx, DISK_ERROR1
    call print

    call btohex
    mov cx, ERR_CODE
    call print
    ret

; takes al as input
btohex:
    xor bx, bx
    mov bl, 16
    div bl
    ; get byte value of al in two hex values stored in ah and al

    mov si, HEX_BUFF
    mov bl, ah
    mov ch, byte[si + bx]
    mov bl, al
    mov cl, byte[si + bx]
    mov word[ERR_CODE], cx ; move those values into the error code pointer

    ret

; takes ax as input
LBAtoCHS:
    inc ax ; get it so sector 1 = lba 1
    mov dl, 0
    mov ch, 0
    mov cl, 0
    mov bl, byte[SEC_TRCK]
    mov bh, 0

.loop:
    cmp ax, bx ; if comparison is negative, we have completed the process
    js .end

    sub ax, bx ; subtract sec_trck from ax
    inc dl
    cmp dl, byte[NUM_HEAD]
    jz .loop2
    jmp .loop

.loop2:
    mov dl, 0
    inc ch
    jmp .loop

.end:
    mov cl, al ; ax should be zero, therefore ax=al
    mov ax, 0
    clc ; clear carry to prevent false error
    ret

TERM_ROW: db 0
BOOT_MSG: db "Booting...", 0
DISK_INFO: db "Found s2, Loading..."
DISK_ERROR1: db "ERR:BOOT ERR", 0
START_CLUS: db 0, 0
SECT_COUNT: db 0, 0
times 510-($-$$) db 0 ; fill rest of sector with 0's
db 0x55, 0xAA
; -------------- end of boot1, start of boot1.5

mov cx, DISK_INFO
call print
call halt