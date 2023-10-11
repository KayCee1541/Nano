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
    mov si, ax
    mov bx, ax
    mov al, " "
    mov ah, 0x00
.loop:
    mov cx, 2000
    mov word[es:si], ax
    add si, 2
    inc bx
    sub cx, bx
    jz .end
    jmp .loop


.end:

xor ax, ax
mov bx, ax
mov cx, ax
mov dx, ax
mov si, ax
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
    push si
    push bx
    push es
    push di
    push ax
    ; save all registers we will destroy

    mov ax, 0xb800
    mov es, ax
    xor bx, bx
    xor ax, ax

    mov si, TERM_ROW
    mov al, byte[si]
    mov bl, 160
    mul bl
    mov si, ax
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
    push si

    mov si, cx
    mov al, byte [si + bx] ; move character at index bx in the string to al
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
    mov ax, 0
    mov es, ax
    mov si, TERM_ROW
    mov al, byte[si]
    inc al
    mov byte[es:si], al

    pop ax
    pop di
    pop es
    pop bx
    pop si

    ret

read_disk:
    push ax
    push bx
    push cx
    push dx
    push es
    push di

    ; check if disk drive extensions are supported
    db 0xf8 ; clear carry flag
    mov ah, 41h
    mov bx, 55AAh
    mov dl, 80h
    int 13h

    jc .error2

    jmp .error1

    db 0xf8 ; clear carry flag

    pop di
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.error1:
    mov cx, DISK_ERROR1
    call print
    ret

.error2:
    mov cx, DISK_ERROR2
    call print

    db 0xf8 ; clear carry flag
    ret

.error3:
    mov cx, DISK_ERROR3
    call print
    ret

TERM_ROW: db 0
BOOT_MSG: db "Booting...", 0
DISK_INFO1: db "Getting disk info...",0
DISK_ERROR1: db "DISK ERROR", 0
DISK_ERROR2: db "BIOS STATES LBA NOT SUPPORTED, ATTEMPTING TO FORCE...", 0
DISK_ERROR3: db "COULDN'T READ DISK INFO, STOPPING...", 0
BLANK: db 0
times 510-($-$$) db 0 ; fill rest of sector with 0's
db 0x55, 0xAA