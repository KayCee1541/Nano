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
    NUM_RDES: dw 0
    TOTL_SEC: dw 0
    MED_DESC: db 0
    SEC_FATS: dw 0
    SEC_TRCK: dw 0
    NUM_HEAD: dw 0
    HIDD_SEC: dd 0
    TOT_SECL: dd 0
    DRIV_NUM: db 0 ; ignore value at boot
    FLAG_VAL: db 0 ; if this value equals zero, we are booting from a floppy
    SIGNATUR: db 0x28
    VID_SERI: dd 0
    VOL_LABL: db "           "
    SYS_IDEN: dq 0

jmp 0:Start
Start:
; set up stack
cli
xor ax, ax
mov ss, ax
mov sp, 0x7c00
sti

; also reset segments
mov ds, ax
mov es, ax

; save drive number
mov [DRIV_NUM], dl

; compute size of root directory
mov ax, [NUM_RDES]
mov cl, 4
shr ax, cl  ; divide ax by 16.
            ; This works because we first need to multiply NUM_RDES by 32 (shift left 5) in order to get the size of the root directory in bytes
            ; Then, we need to divide by 512 (shift right 9) to get the number of sectors. ( ax << 5 ) >> 9 = ax >> 4
mov [RootDirSectors], al ; we can use AL because fuck you I am not dedicating two bytes to this shit, also because in no world would the number of sectors dedicated to the root directory exceed 255

; compute first data sector number
mov ax, [SEC_FATS]
xor bx, bx
mov bl, [NUM_FATS]
mul bx
; this is fat12, in no world will the number of sectors dedicated to the FATs be more than 64k, so we can just throw out DX
add ax, [RES_SECT] ; we have the sector number of the root directory now, save it for later.
mov [RootDirStartSec], ax
add ax, [RootDirSectors]
mov [FirstDataSector], ax

; Load first root directory sector at 0x08000
mov ax, 0x0800
mov es, ax
xor di, di
mov ax, [RootDirStartSec]
call LoadDiskSector
; wait for a while for the data to load from disk
mov cx, 0xFFFF
call PauseTime
; parse root directory first cluster to see if boot target exists
ParseRD:
    mov si, BootTarget
    mov cx, 11 ; check 11 bytes
.ploop:
    cmpsb
    jne .Fail
    loop .ploop
    ; if we got this far, we have found the boot target. Record starting sector number
    add di, 15 ; 11+15=26, location of starting sector.
    mov ax, [es:di]
    mov [BootTargetFirstCluster], ax

.Fail:


; subroutine for loading in a cluster to a specified memory address
; inputs are as follows: AX -> Cluster number ES:DI -> data buffer (NOTE: Recommended to keep DI=0 and to only use ES to point to the address of data buffer.)
LoadDiskCluster:
    xor cx, cx
    mov cl, [SEC_CLUS]
    mul cx ; DX yeeted, no way we have more than 64k sectors. If there were, I would be using FAT16 because it is much easier.
    add ax, [FirstDataSector] ; Cluster 0 doesnt exist at sector 0, it exists at the first data sector.
.Loop:
    ; we now loop through all sectors in the cluster, advancing ES:DI as needed.
    call LoadDiskSector ; AX, ES, DI, CX preserved
    inc ax
    add DI, 512
    loop .Loop
    ret

; subroutine for loading in a sector to a specified memory address
; inputs are as follows: AX -> LBA Sector number ES:DI -> data buffer
LoadDiskSector:
    push ax
    push es
    push di
    push cx
    mov bx, [SEC_TRCK]
    div bl ; no way there are more than 63 CHS sectors. AL = temp, AH = sector number. I got this backwards, so I will just put in a simple xchg
    xchg ah, al
    inc al ; need to increment sector number because CHS sectors start at 1
    mov cl, al ; sectors in final position
    mov al, ah ; put temp in AL
    xor ah, ah ; now temp takes up AX completely.
    xor dx, dx ; we need full 16 bit registers for this next part.
    mov bx, [NUM_HEAD]
    div bx ; head = dx, Cyl = ax
    mov dh, dl ; head exists in dh, final resting place.
    mov ch, al ; put low 8 bits of Cyl in final place
    push cx ; need to make cl available for bitshifting
    mov cl, 2
    shr ax, cl ; top 2 bits of Cyl exists in correct bit placement, now mask
    pop cx
    and al, 0b11000000 ; perform mask
    or cl, al ; now top 2 bits of Cyl exist in final position.
    ; now, we set up the interrupt itself
    mov bx, di
    mov ah, 0x02
    mov dl, [DRIV_NUM]
    mov al, 1
    int 0x13
    jc .error
    and ah, ah ; check if ah = 0
    jnz .error
    pop cx
    pop di
    pop es
    pop ax
    ret
.error:
    mov bl, ah
    mov bh, 0x10 ; 0x10 corresponds to drive
    call PrintEC

; bh = Device, bl = status.
PrintEC:
    ; write to ISABugger device.
    mov al, 0x02
    out 0x7a, al
    mov al, bh
    out 0x7b, al
    mov al, 0x04
    out 0x7a, al
    mov al, bl
    out 0x7b, al
    cli
    hlt

; cx = pause time
PauseTime:
    loop .waitTime
    ret
.waitTime:
    jmp PauseTime

RootDirSectors: db 0
FirstDataSector: dw 0
RootDirStartSec: dw 0
HexVals: db "0123456789ABCDEF"
BootTarget: db "test    txt"
BootTargetFirstCluster: dw 0

times 510-($-$$) db 0
db 0x55, 0xaa