[org 0x7c00]
[CPU 186]

JMP_CODE: times 3 db 0
OEM_IDEN: times 8 db 0
BYTE_SEC: times 2 db 0
SEC_CLUS: db 0
RES_SECT: times 2 db 0
NUM_FATS: db 0
NUM_RDES: times 2 db 0
SEC_COUN: times 2 db 0
MED_DESC: db 0
SECT_FAT: times 2 db 0
SECT_TRK: times 2 db 0
NUM_HEAD: times 2 db 0
NUM_HIDN: times 4 db 0
LRGE_SEC: times 4 db 0
DRIV_NUM: db 0
RESERVED: times 6 db 0
VOL_LBST: times 11 db 0
SYS_IDST: times 8 db 0

mov byte [DRIV_NUM], dl
mov bp, 0x7c00
xor ax, ax
mov ss, ax
mov sp, bp ; set up stack

; compute sector number for cluster 0
mov ax, word [SECT_FAT]
mul byte [NUM_FATS]
add ax, word [RES_SECT]
xor bx, bx
mov bl, byte [SEC_CLUS]
sub ax, bx
mov word [Start_Cluster], ax

call Load_File
jmp 0x7000:0

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

Read_Disk: ; ax contains LBA of sector, bl contains number of sectors to transfer, es:dx is the address for the transfer buffer
    pusha
    mov byte [Disk_Buffer + 2], bl
    mov word [Disk_Buffer + 4], dx
    mov word [Disk_Buffer + 6], es
    mov word [Disk_Buffer + 8], ax
    mov si, Disk_Buffer
    mov ah, 0x42
    mov dl, byte [DRIV_NUM]
    int 0x13
    jc .error
    or ah, ah
    jnz .error
    popa
    ret
.error:
    mov si, DRE
    call Print
    call Halt

strcomp: ;si = first string address, di = second string address, ax = string length. Sets carry if different
    pusha
.loop1:
    or ax, ax
    clc
    jz .same
    mov bl, byte [ds:si]
    cmp bl, byte [ds:di]
    jne .notsame
    inc si
    inc di
    dec ax
    jmp .loop1
.notsame:
    stc
.same:
    popa
    ret

Read_Cluster: ; ax contains cluster number, bl contains number of sectors to read, es:dx is the address for the transfer buffer
    pusha
    push dx
    mul byte[SEC_CLUS]
    pop dx
    add ax, word [Start_Cluster]
    call Read_Disk
    popa
    ret

Load_File:
    ; stage 1: load root directory and look for kernel.bin
    ; stage 2: once found, save staring cluster and load sector of fat and next sector of fat (because the file will have a size less than 256 clusters)
    ; stage 3: look for starting cluster in fat. Once found, load to 0x70000
    pusha
    mov ax, word [Start_Cluster]
    xor bx, bx
    mov bl, byte [SEC_CLUS]
    add ax, bx ; compute root directory cluster number
    xor dx, dx
    mov es, dx
    mov dx, 0x7e00
    call Read_Disk
    ; now begin comparing file entries
    mov si, Kernel_Name
    mov di, 0x7e00
    mov ax, 11
.ScanRootDir:
    push ax
    mov ax, word [BYTE_SEC]
    xor cx, cx
    mov cl, byte [SEC_CLUS]
    mul cx
    add ax, 0x7e00
    mov cx, ax
    pop ax
    cmp di, cx
    je .NotFound
    call strcomp
    jnc .Found
    add di, 32 ; go to next entry
    jmp .ScanRootDir
.Found:
    add di, 30
    mov cx, word [ds:di]
    or cx, cx
    jnz .FileTooLarge
    sub di, 4
    mov cx, word [ds:di]
    ; cx will contain starting cluster
    ; we will now load 2 sectors of the FAT and search through it for the starting cluster.
    ; if we reach the end of the first sector of data, we will load the next sectors. Files should never exceed 64k in size,
    ; or at most 512 bytes of data.
    mov ax, word [RES_SECT]
    mov bl, 2
    dec ax ; we will increment ax in .LoadFAT, so we need to prematurely decrement it.
    ; other registers were not modified, so we can directly load the FAT
    ; Transfer buffer is having issues, so we will rebuild it
    xor dx, dx
    mov es, dx
    mov dx, 0x7e00
.LoadFAT:
    inc ax
    call Read_Disk
    mov di, 0x7e00
.ScanFAT:
    cmp di, 0x8000 ; we are only scanning the first loaded sector, which ends at 0x8000
    je .LoadFAT
    cmp cx, word [di]
    je .LoadClusters
    add di, 2
    jmp .ScanFAT

.LoadClusters:
    mov bl, byte [SEC_CLUS]
    mov dx, 0x7000
    mov es, dx
    xor dx, dx ; set up transfer buffer to load data to where the kernel expects to be in memory
    ; cx will contain how many bytes we load each time
    push ax
    mov ax, word [BYTE_SEC]
    xor cx, cx
    mov cl, byte [SEC_CLUS]
    mul cx
    mov cx, ax
    pop ax
.LoadLoop:
    mov ax, word [di]
    cmp ax, 0xffff
    je .EndLoad
    call Read_Cluster
    add dx, cx
    add di, 2
    jmp .LoadLoop

.EndLoad:
    popa
    ret

.NotFound:
    mov si, NoKernel
    call Print
    jmp Halt

.FileTooLarge:
    mov si, KernelTooBig
    call Print
    jmp Halt

NoKernel: db "Kernel Not Found!", 0
DRE: db "DRE!", 0
Kernel_Name: db "Kernel  sys"
KernelTooBig: db "Kernel Too Big!", 0
Start_Cluster: dw 0

align 16,db 0
Disk_Buffer:
    db 0x10
    db 0
    dw 0
    dd 0
    dd 0
    dd 0

times 510-($-$$) db 0
db 0x55, 0xaa