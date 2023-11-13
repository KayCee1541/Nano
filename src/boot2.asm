bits 16
org 0x9000

mov bx, 0x8200
mov si, bx
mov bx, 0
; get functions from stage 1
mov bx, word[si]
mov word[CLus_Sect], bx
add si, 2
mov bx, word[si]
mov word[Print], bx
add si, 2
mov bx, word[si]
mov word[LBATOCHS], bx

mov cx, SUCCESS_MSG
call print

mov cx, memMap_stat
call print

; get memory map
memMap:
    mov ebx, 0 ; Hey, first use of a 32 bit register! Shits only getting more complicated from here
    mov ax, 0
    mov es, ax
    mov ax, 0x500
    mov word[.loc], ax

.loop:
    mov di, word[.loc] ; load data to location 0x1000 - 0x7000
    cmp di, 0x7000 ; check if exceeding maximum allowed value
    jz .error
    mov eax, 0x0000e820
    mov ecx, 24 ; fill 24 bytes
    mov edx, 0x534D4150 ; required, for some reason
    int 15h
    and bx, bx ; check if bx is 0
    jz .end
    jc .errcheck

    ; because we have not reached the end of the memory map, increment di by 24 and go again
    mov di, word[.loc]
    add di, 24
    mov word[.loc], di
    jmp .loop

.errcheck:
    and ah, ah
    jnz .error
    jmp .end ; ah will be zero if we have finished mapping memory but bx was not set to 0 (some bioses do not set bx to 0)

.error:
    mov cx, memMap_err
    call print
    call halt

.loc: dw 0

.end:

mov cx, memMap_succ
call print

; a20 line controls:
mov bx, 0 ; use this to count how many times we have tried to enable a20
a20:
    clc ; clear carry flag
    mov ax, 0x2402
    int 15h
    jc .error

    and al, al ; check status
    jz .disabled
    cmp al, 1 ; check if a20 is enabled
    jz .enabled

    jnz .error ; al should never be more than 1. if it is, error occured

.disabled:
    cmp bx, 5 ; check if we have looped 5 times
    jz .error

    inc bx
    clc
    mov ax, 0x2401
    int 15h ; enable a20 line
    jc .error

    jmp a20 ; verify a20 line was enabled

.error:
    mov cx, a20_error
    call print
    call halt

.enabled: ; continue with execution of boot2

mov cx, a20_success
call print

cli ; disable interrupts

; disable nmi
in al, 0x70
or al, 0x80
out 0x70, al
in al, 0x71
xor al, al

; load GDT
lgdt [GDTR]

; load IDT
lidt [IDTR]

; save stack current stack location
mov word[CUR_SP], sp
mov word[CUR_SS], ss

; enter protected mode
call halt
mov eax, cr0
or al, 1
mov cr0, eax ; we have now enabled PM
jmp 0x08:PMMain

halt:
    cli
    hlt

print:
    push ax
    mov ax, word[Print]
    call ax
    pop ax
    ret

Clus_Sect:
    push ax
    mov ax, word[CLus_Sect]
    call ax
    pop ax
    ret

LBAtoCHS:
    push ax
    mov ax, word[LBATOCHS]
    call ax
    pop ax
    ret

; cx contains entry data type location, es:si contains location of entry. Automatically updates si
LoadGDTEntry:
    mov di, cx 
    mov eax, dword[di] ; load first 4 bytes of entry
    add di, 4
    mov dword[es:si], eax
    add si, 4
    mov eax, dword[di] ; load last 4 bytes of entry
    add di, 4
    mov dword[es:si], eax
    add si, 4
    ret

CLus_Sect: db 0, 0
Print: db 0, 0
LBATOCHS: db 0, 0
SUCCESS_MSG: db "Stage 2 loaded, getting ready to load the kernel...", 0
a20_error: db "ERROR WHILST ENABLING A20!", 0
a20_success: db "A20 successfully enabled!", 0
memMap_err: db "ERR: Couldn't get memory map!", 0
memMap_stat: db "Getting memory map", 0
memMap_succ: db "Memory map loaded!", 0
CUR_SP: dw 0
CUR_SS: dw 0

GDTR: dw 0xFFFF  ; size
      dd NULLSEG ; offset

IDTR: dw 0x2000 ; size
      dd 0x00030000 ; offset

NULLSEG: dw 0       ; limit 1
         dw 0       ; base 1
         db 0       ; base 2
         db 0       ; access byte
         db 0       ; flags : limit 2
         db 0       ; base 3

KCODESEG: dw 0xffff ; limit 1
          dw 0       ; base 1
          db 0       ; base 2
          db 0x9a    ; access byte
          db 0xcf    ; flags : limit 2
          db 0       ; base 3

KDATASEG: dw 0xffff ; limit 1
          dw 0       ; base 1
          db 0       ; base 2
          db 0x92    ; access byte
          db 0xcf    ; flags : limit 2
          db 0       ; base 3

UCODESEG: dw 0xffff ; limit 1
          dw 0       ; base 1
          db 0       ; base 2
          db 0xfa    ; access byte
          db 0xcf    ; flags : limit 2
          db 0       ; base 3

UDATASEG: dw 0xffff ; limit 1
          dw 0       ; base 1
          db 0       ; base 2
          db 0xf2    ; access byte
          db 0xcf    ; flags : limit 2
          db 0       ; base 3

TSSSEG: dw 0x6c    ; limit 1
        dw 0       ; base 1
        db 0       ; base 2
        db 0x89    ; access byte
        db 0x00    ; flags : limit 2
        db 0       ; base 3

; ASSUME EVERYTHING ABOVE THIS POINT CANNOT RUN IN 32 BIT MODE!!!
; basically below this point pretend this is all a different program
bits 32
PMMain:

mov esp, 0x51000 ; set stack
call PMClearScreen
mov ecx, TEST_MSG
call PMPrint
mov ecx, TEST_MSG2
call PMPrint
call PMHalt

; ecx contains address for string
PMPrint:
    push eax
    push ebx
    push edx
    
    xor eax, eax
    xor ebx, ebx
    xor edx, edx

    mov bx, [CURS_POSX]
    mov ax, [CURS_POSY]
    mov dh, [CONS_COL]
    ; vram index can be computed as (y * 80 + x) * 2  (because vram goes (byte)color:(byte)char)
    mov dl, 80
    mul dl ; y * 80
    add ax, bx ; + x
    mov dl, 2
    mul dl ; * 2
    add eax, 0xb8000 ; convert vram index into memory address

.printchar:
    ; check if posx is aob
    cmp bx, 80
    call .newline

    mov dl, [ecx]
    inc ecx
    and dl, dl
    jz .end ; check if character is null

    mov word[eax], dx
    add eax, 2
    mov bx, [CURS_POSX]
    inc bx
    mov [CURS_POSX], bx
    
    jmp .printchar

.newline:
    push eax
    mov al, 0
    mov byte[CURS_POSX], al
    mov al, byte[CURS_POSY]
    inc al
    cmp al, 25
    jz .res
    mov byte[CURS_POSY], al
    pop eax
    ret

.res:
    mov al, 0
    mov byte[CURS_POSY], al
    pop eax
    ret

.end:
    pop edx
    pop ebx
    pop eax
    ret


PMClearScreen:
    push eax
    push ecx
    push edx

    mov eax, 0xb8000
    mov ecx, 0
    mov dl, " "
    mov dh, [CONS_COL]

.loop:
    cmp ecx, 2000
    jz .end
    mov word [eax], dx
    inc ecx
    add eax, 2
    jmp .loop

.end:
    pop edx
    pop ecx
    pop eax
    ret

PMHalt:
    cli
    hlt

CURS_POSX: db 0
CURS_POSY: db 0
CONS_COL: db 07h

TEST_MSG: db "We have entered protected mode!", 0x0a, 0
TEST_MSG2: db "This is a test of the newline function!", 0