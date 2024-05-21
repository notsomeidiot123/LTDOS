;LTDOS by Kimi
;stack items are 2 bytes wide
;first function argument is at bp + 4 after enter
;formatted in fat16 cause i hate fat12
org 0x7c00
bits 16
BPB:
    jmp short startup
    nop
    .OEM: db "LTDOS   "
    .BPS: dw 512
    .SPC: db 1
    .RSC: dw 4
    .FTC: db 1
    .RDE: dw 512
    .SPV: dw 2880 * 2
    .MDT: db 0xf0
    .SPF: dw 23
    .SPT: dw 36
    .HPD: dw 2
    .HDN: dd 0
    .LSC: dd 0
EBPB:
    .DNM: db 0
    .NTF: db 0
    .SIG: db 0x29
    .VID: dd 0xaa55
    .VLS: db "LTDOSBOOTFD"
    .SID: db "FAT16   "
startup:
    mov sp, 0
    mov ss, sp
    mov bp, 0x7a00
    mov sp, 0x7a00
    mov [bootdata.bootdisc], dh
    jmp 0:set_load
set_load:
    cld
    mov word [0x100], 0
    mov word [0x100], LTDOS_API_INT
    mov ax, bootdata.welcome
    push bootdata.welcome
    call puts
    add sp, 2
    
    mov ax, 0
    mov es, ax
    mov bx, 0x7e00
    mov ah, 2
    mov al, 3
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, 0
    int 0x13
    jnc stage_two
    
    mov al, ah
    xor ah, ah
    push 10
    push ax
    call putd
    add sp, 4
    jmp $
; cdelc: puts(char *string)
puts:
    push bp
    mov bp, sp
    push si
    mov si, [bp + 4]
    
    mov ah, 0xe
    .loop:
        lodsb
        cmp al, 0
        je .exit
        int 0x10
        jmp .loop
    .exit:
        pop si
        pop bp
        ret

;cdecl: void putd(unsigned short number, unsigned short base)
putd:
    ;set frame
    push bp
    mov bp, sp
    push si
    push dx
    push bx
    push cx
    xor dx, dx
    mov ax, [bp + 4]
    ;if zero, just write zero
    cmp ax, 0
    jne .cont
    mov ah, 0xe
    mov al, '0'
    int 0x10
    jmp .exit
    .cont:
    mov bx, ax
    mov cx, [bp + 6]
    ;create character buffer
    mov si, 0x800
    mov byte [si], 0
    dec si
    .loop:
        xor dx, dx
        idiv cx
        add dx, '0'
        mov [si], dl
        dec si
        cmp ax, 0
        ; jmp $
        je .exit
        jmp .loop
    .exit:
    ; jmp $
        inc si
        push si
        call puts
        pop si
        pop cx
        pop bx
        pop dx
        pop si
        pop bp
        ret

bootdata:
    .welcome: db "Welcome to LTDOS by Kimi (Version 0.1.0)", 0xa, 0xd, 0
    .bootdisc: db 0

times 510 - ($-$$) db 0
db 0x55, 0xaa

data:
    .current_disc: db 0
    .disc_fat_ptr: dw 0xa000
    .disc_bpb_ptr: dw 0x9000
    .usedsegs_list: dw 0b0000_0000_0000_0011
    .err_str: db "An exception has occured. Error ", 0
    .filename_buffer: times 128 db 0
    .ftest: db "startup.sys", 0
    
discinfo:
    .heads: dw 0
    .cylinders: dw 0
    .sectors: dw 0
    
LTDOS_API_INT:
    iret

putn:
    push ax
    mov ax, 0xe0a
    int 0x10
    mov al, 0xd
    int 0x10
    pop ax
    ret

stage_two:
    push 'A'
    call open_disk
    cmp ax, 0
    jne error_halt
    add sp, 2
    
    mov ax, 0xe41
    int 0x10

    jmp $

error_halt:
    push ax
    push data.err_str
    call puts
    add sp, 2
    pop ax
    push 10
    push ax
    call putd
    
    jmp $

open_disk:
    push bp
    mov bp, sp
    push cx
    push dx
    push bx
    push di
    push es

    mov dl, [bp + 4]
    mov [data.current_disc], dl
    sub dl, 'A'
    mov ah, 0x8
    xor al, al
    xor di, di
    mov es, di
    int 0x13
    jc .ret_err
    
    mov ax, cx
    and ax, 0x3f;sectors
    shr cl, 6;cylinders
    xchg ch, cl
    
    add cx, 1
    add dh, 1
    
    mov [discinfo.heads], dh
    mov [discinfo.sectors], al
    mov [discinfo.cylinders], cx
    
    ;cache discs BPB
    xor bx, bx
    mov es, bx
    mov bx, [data.disc_bpb_ptr]
    
    mov ax, 0x0201 ;read one sector
    mov cx, 0x0001 ;read first sector
    mov dh, 0x00   ;read first head
    mov dl, [data.current_disc]
    sub dl, 'A'
    int 0x13
    
    ;cache discs FAT
    
    mov bx, [data.disc_bpb_ptr]
    push bx
    push word [bx + 0xe]
    call lba_to_chs
    add sp, 2
    pop bx
    
    mov al, [bx + 0x16]
    mov ah, 0x02
    
    xor bx, bx
    mov es, bx
    mov bx, [data.disc_fat_ptr]
    int 0x13
    
    mov ax, 0
    .ret_err:
        pop es
        pop di
        pop bx
        pop dx
        pop cx
        
        pop bp
        ret

;WARNING: DESTRUCTIVE, will destroy any data in the GP registers
lba_to_chs:
    push bp
    mov bp, sp
    
    mov di, [discinfo.sectors]
    xor dx, dx
    mov ax, [bp + 4]
    div di
    
    add dx, 1
    push dx; sectors !PUSH
    
    
    mov di, [discinfo.heads]
    xor dx, dx
    div di
    
    push dx; head   !PUSH
    
    xor dx, dx
    
    mov ax, [discinfo.sectors]
    mov di, [discinfo.heads]
    mul di
    mov di, ax
    
    mov ax, [bp + 4]
    xor dx, dx
    div di
    mov cx, ax
    xchg ch, cl
    and cl, ~0x3f
    
    pop dx
    mov ax, dx
    
    pop dx
    or cl, dl
    
    mov dx, ax
    mov dh, dl
    mov dl, [data.current_disc]
    sub dl, 'A'
    
    pop bp
    
    ret

open_file:
    
times 2048 - ($-$$) db 0
times (2880 * 1024) - ($ - $$) db 0