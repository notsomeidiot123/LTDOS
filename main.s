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

FD_HPC equ 2
FD_SPT equ 36

data:
    .current_disc: db 0
    .disc_fat_ptr: dw 0xa000
    .disc_bpb_ptr: dw 0x9000
    .usedsegs_list: dw 0b0000_0000_0000_0011
    .err_str: db "An exception has occured. Error ", 0
    .filename_buffer: times 128 db 0

LTDOS_API_INT:
    iret


stage_two:
    push 'A'
    call open_disk
    cmp ax, 0
    jne error_halt
    add sp, 2
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

allocate_cluster:
    ;search fat for free cluster ; claim if 0

delete_file:
    ;set all clusters in file's cluster chain to 0

;WARNING: DESTRUCTIVE, will destroy any data in DX, AX, and CX
lba_to_chs:
    push bp
    mov bp, sp
    
    ;calculate sector
    mov ax, [bp + 4]
    mov dl, FD_SPT
    div dl
    mov cl, ah
    inc cl
    ;calculate head
    and al, 1
    mov dh, al
    push dx
    ;calculate cylinder
    mov ax, [bp + 4]
    mov dl, FD_HPC * FD_SPT
    div dl
    mov ch, al
    
    pop dx
    .exit:
        pop bp
        mov ax, 0
        ret

open_disk:
    ;ARGS:
    ;char disc
    ;read BPB, cache FAT
    push bp
    mov bp, sp
    push cx
    push dx
    push es
    push bx
    
    mov ah, 2
    mov al, 1
    mov ch, 0
    mov cl, 1
    mov dh, 0
    mov dl, [bp + 4]
    sub dl, 'A'
    mov bx, 0
    mov es, bx
    mov bx, [data.disc_bpb_ptr]
    int 0x13
    jc .exit_err
    
    cmp byte [es:bx + 0x26], 0x29
    je .read
    cmp byte [es:bx + 0x26], 0x28
    jne .exit_err
    
    .read:
    push word [es:bx + 0xe]
    call lba_to_chs
    add sp, 2
    
    mov ah, 2
    mov al, [es:bx + 0x16]
    mov dl, [bp + 4]
    sub dl, 'A'
    mov bx, [data.disc_fat_ptr]
    int 0x13
    jc .exit_err
    mov [data.current_disc], dl
    
    .exit:
        pop bx
        pop dx
        pop es
        pop cx
        pop bp
        mov ax, 0
        ret
    .exit_err:
        mov ax, 1
        pop bx
        pop dx
        pop es
        pop cx
        pop bp
        ret

open_file:
    ;ARGS:
    ;char *file
    ;FILE *fptr
    ;find file, return struct
    ;ptr + 0 = current cluster index
    ;ptr + 2 = first cluster index
    push bp
    mov bp, sp
    push dx
    push bx
    push cx
    push es
    push ds
    push di
    push si
    
    mov bx, [bp + 10]
    mov ds, bx
    mov si, [bp + 8]
    
    mov di, 0
    mov es, di
    mov di, data.filename_buffer
    
    push di
    
    mov cx, 64
    rep movsw
    
    pop di
    push di
    xor cx, cx
    .tokenize:
        cmp byte [es:di], 0
        je .tokenize_end
        cmp byte [es:di], '/'
        jne .increment
        inc cx
        mov byte [es:di], 0
    .increment:
        inc di
        jmp .tokenize
    .tokenize_count: dw 0
    .tokenize_end:
    mov [.tokenize_count], cx
    ;OPEN ROOT DIRECTORY
    push es
    xor bx, bx
    mov es, bx
    mov bx, data.disc_bpb_ptr
    mov ax, [es:bx + 0x10]
    add ax, [es:bx + 0x0e]
    push ax
    call lba_to_chs
    add sp, 2
    
    xor ax, ax
    mov al, [es:bx + 0x11]
    mov bl, 0x20
    div bl
    
    mov ah, 2
    ;You've got to stop using magic numbers...
    mov bx, 0x1000
    mov es, bx
    xor bx, bx
    int 0x13
    jc .return_not_found
    
    pop es
    pop di
    ;string comparisons against each directory entry
    mov cx, [.tokenize_count]
    mov si, 0x1000
    mov ds, si
    xor si, si
    .search_directory:
        pop cx
        jcxz .return_not_found
        push cx
        xor cx, cx
        xor ax, ax
        
        cmp byte [ds:si], 0
        je .return_not_found
        
        cmp si, 0x4000
        jge .return_not_found
        
        repne scasb
        neg cx
        
        repe cmpsb
        je .load_next_dir
        add si, 0x20
        jmp .search_directory
        
    .load_next_dir:
        

    .return:
        pop si
        pop di
        pop ds
        pop es
        pop cx
        pop bx
        pop dx
        pop bp
        xor ax, ax
        ret
    .return_not_found:
        mov ax, 1
        pop si
        pop di
        pop ds
        pop es
        pop cx
        pop bx
        pop dx
        pop bp
        ret

create_file:
    ;ARGS:
    ;char *file
read_file:
    ;ARGS:
    ;FILE *fileptr
    ;char *buffer
    ;int size;
times 2048 - ($-$$) db 0
times (2880 * 1024) - ($ - $$) db 0