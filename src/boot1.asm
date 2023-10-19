; BOOT1 CAN ONLY READ UP TO SECTOR 65535, DO NOT PUT STAGE 2 ANY HIGHER THAN 65535
; NO TOUCHY! I WORK! ONLY TOUCHIE IF I BREAKIE OR YOU CAN MAKE ME BETTER, IN WHICH CASE PLEASE TOUCH ME!

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
    mov ah, 02
    mov al, 1 ; read 1 sector
    mov dl, 0x80 ; in drive 0x80
    mov bx, 0
    mov es, bx
    mov bx, 0x7e00 ; load data to 0000:7e00
    int 13h

    jc error ; jump if error occurs
    add ah, 0
    jnz error ; jump if status code is not 0

    mov word[SECT_COUNT], 516

.loop:
    clc
    mov ax, word[SECT_COUNT] ; load start of DT
    cmp ax, 4612 ; check if index has reached the end of DT
    jz .error1
    call LBAtoCHS
    mov ah, 02
    mov al, 32 ; load 32 sectors, end of data = 0xD000
    mov dl, 0x80
    mov bx, 0
    mov es, bx
    mov bx, 0x9000
    int 13h

    jc error ; jump if error occurs
    add ah, 0
    jnz error ; jump if status code is not 0

    mov ax, word[SECT_COUNT]
    add ax, 32
    mov word[SECT_COUNT], ax ; increment SECT_COUNT by 32
    mov dx, 0x9000 ; set si to where data was loaded
    mov si, dx

.dtscan:
    cmp si, 0xD000
    jz .loop ; check if si has reached the end of loaded DT
    mov bx, 31 ; last byte of DT entry
    mov cl, byte[si + bx]
    cmp cl, 0x32 ; check if entry contains magic number
    jz .found

    add si, 32 ; go to next entry
    jmp .dtscan

.found:
    mov bx, 0x17
    mov cx, word[si + bx]
    mov word[START_CLUS], cx

    ; running out of space, go to stage 1.5
    jmp 0x7e00

.error1:
    mov ah, 0xf0 ; 0xf0 = boot2 not found in DT

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
    inc ax
    mov bh, 0
    mov bl, byte[SEC_TRCK]
    mov dh, 0
    mov ch, 0

.while: ; while
    cmp ax, bx ; ax (lba) - bx (spt)
    js .end 
    jz .end ; > 0

    sub ax, bx ; ax (lba) = ax (lba) - bx (spt)
    inc dh ; head += 1

    cmp dh, byte[NUM_HEAD] ; if 
    jz .branch ; dh (head) == HPC

    jmp .while

.branch:
    mov dh, 0 ; dh (head) = 0
    inc ch ; ch (cylinder) += 1
    jmp .while

.end:
    mov cl, al ; cl (sector) = ax (lba) (ah should be 0 at this point, so ax = ah)
    ret

TERM_ROW: db 0
BOOT_MSG: db "Booting...", 0
DISK_INFO: db "Found s2, Loading...", 0
DISK_ERROR1: db "ERR:BOOT ERR", 0
START_CLUS: db 0, 0
SECT_COUNT: db 0, 0
times 510-($-$$) db 0 ; fill rest of sector with 0's
db 0x55, 0xAA
; -------------- end of boot1, start of boot1.5

mov cx, DISK_INFO
call print

FAT_LOOKUP:
    mov ax, 2 ; start of fat1
    mov word[SECT_COUNT], ax

.loop:
    clc
    mov ax, word[SECT_COUNT] 
    cmp ax, 258 ; check if index has reached the end of FAT1
    jz .error1
    call LBAtoCHS
    mov ah, 02
    mov al, 32 ; load 32 sectors, end of data = 0xD000
    mov dl, 0x80
    mov bx, 0
    mov es, bx
    mov bx, 0x9000
    int 13h

    jc error ; jump if error occurs
    add ah, 0
    jnz error ; jump if status code is not 0

    mov ax, word[SECT_COUNT]
    add ax, 32
    mov word[SECT_COUNT], ax ; increment SECT_COUNT by 32
    mov bx, 0x9000 ; set si to where data was loaded
    mov si, bx

    mov bx, word[START_CLUS]

.scan:
    cmp si, 0xD000
    jz .loop ; check if si has reached the end of loaded data
    mov cx, word[si]
    cmp cx, bx ; check if entry is equal to start_clus
    jz .found

    add si, 2 ; go to next entry
    jmp .scan

.found:
    mov cx, word[si]
    cmp cx, 0xFFFF
    jz LoadS2 ; check to see if end of FAT entry
    add cx, 0
    jz .error2 ; check if entry is corrupted

    push si ; save current FAT entry address
    mov bx, word[ClusterTableIndex]
    mov si, Cluster_Table
    mov word[si + bx], cx ; save entry
    add bx, 2
    mov word[ClusterTableIndex], bx
    pop si ; restore si

    add si, 2 ; go to next FAT entry
    jmp .found

.error1:
    mov ah, 0xf1 ; 0xf1 = couldn't find FAT entry
    jmp error

.error2:
    mov ah, 0xf2 ; 0xf2 = Entry is corrupted
    jmp error

LoadS2:
    mov bx, 0
    mov word[ClusterTableIndex], bx

    mov bx, 0x8000
    mov word[Load_Loc], bx
    mov si, Cluster_Table

.loop:
    mov bx, word[ClusterTableIndex]
    mov ax, word[si + bx]
    add ax, 0
    jz .end
    call Clus_Sect
    call LBAtoCHS
    mov ah, 2
    mov al, 4 ; load 1 cluster
    mov dl, 0x80
    mov bx, 0
    mov es, bx
    mov bx, word[Load_Loc]
    int 13h

    jc error ; jump if error occurs
    add ah, 0
    jnz error ; jump if status code is not 0

    mov bx, word[ClusterTableIndex]
    add bx, 2
    mov word[ClusterTableIndex], bx ; increment index by 2

    mov bx, word[Load_Loc]
    add bx, 2048
    mov word[Load_Loc], bx ; increment Load location by 4 sectors
    jmp .loop

.end:
    mov ax, word [TERM_ROW]
    jmp 0x8000

; takes ax as input, outputs ax
Clus_Sect:
    dec ax ; cluster 1 ranges from sector 0 to sector 3, not sector 4 to sector 7, make sure to account for this
    push bx
    mov bx, 4
    mul bx
    pop bx ; preserve bx
    ret

ClusterTableIndex: db 0, 0
Load_Loc: db 0, 0
Cluster_Table: db 0
times 1024-($-$$) db 0 ; make sure we stay within the sector