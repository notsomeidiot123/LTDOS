;LTDOS by Kimi
;stack items are 2 bytes wide
;first function argument is at bp + 4 after enter
;formatted in fat16 cause i hate fat12

;NOTE
;ptrs are always LONG POINTERS, meaning they take up one DWORD of space
;1 word for segment (always comes first)
;1 word for offset  (always comes last)
org 0x7c00
bits 16
BPB:
    jmp short startup
    nop
    .OEM: db "LTDOS   "
    .BPS: dw 512
    .SPC: db 1
    .RSC: dw 4
    .FTC: db 2
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
    mov word [0x202], 0
    mov word [0x200], LTDOS_API_INT
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
    ;defined as data, to allow for relocation
    .disc_fat_ptr: dw 0x0000
    .disc_fat_seg: dw 0x1000
    .disc_dir_ptr: dw 0xa000
    .disc_dir_seg: dw 0x0000
    .disc_bpb_ptr: dw 0x9000
    .disc_bpb_seg: dw 0x0000
    
    .usedsegs_list: dw 0b0000_0000_0000_0011
    .err_str: db "An exception has occured. Error ", 0
    .filename_buffer: times 128 db 0
    .ftest: db "TEST.TXT", 0
    .flag: db "55AA"
    .kernel_current_file:
        dw 0
        dw 0
    
discinfo:
    .heads: dw 0
    .cylinders: dw 0
    .sectors: dw 0
    
LTDOS_API_INT:
    mov ax, 0xe41
    int 0x10
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
    
    push data.ftest
    push 0
    push data.kernel_current_file
    push 0
    call open_file
    
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
    
    mov bx, [data.disc_fat_seg]
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
    
    push ds
    push si
    push di
    push es
    
    xor bx, bx
    mov ds, bx
    
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
    
    
    pop es
    pop di
    pop si
    pop ds
    
    pop bp
    
    ret

open_file: ;CDECL int open_file(char *fname, FILE *fptr)
    ;|ARG NAME    | OFFSET|
    ;|------------|-------|
    ;|char *fname | 0x8   |
    ;|FILE *fptr  | 0x4   |
    ;|------------|-------|
    ;RETURNS:
    ;int ecode (0 = success)
    ;find file, return struct
    
    ;VERSION 0.1.0: DOES NOT SUPPORT DIRECTORIES
    
    ;set up function stack
    push bp
    mov bp, sp
    
    push es
    push ds
    push bx
    push dx
    push cx
    push di
    push si
    
    ;Step 1: Copy and Tokenize File name
    
    mov bx, [bp + 0x8]
    mov ds, bx
    mov si, [bp + 0xa]
    mov bx, 0
    mov es, bx
    mov di, data.filename_buffer
    
    mov bx, di
    
    mov cx, 11;8.3 file name has 11 bytes. Good enough until i start supporting directories
    .movlp:
        movsb
        dec cx
        cmp byte [ds:si], 0
        je .movlpe
        test cx, cx
        jne .movlp
    .movlpe:
    ; jmp $ ;for debugging
    mov byte [es:bx + 12], 0;File name in buffer
    mov byte [es:bx + 8], 0
    mov di, bx
    
    
    ;Step 2: Read Root Directory
    ;first_root_dir_sector = reserved_sector_count + fat_count * fat_size
    xor dx, dx
    xor bx, bx
    mov ds, bx
    mov bx, [data.disc_bpb_ptr]
    mov ax, [bx + 0x10]
    mov cx, [bx + 0x16]
    mul cx
    mov cx, [bx + 0x0e]
    add cx, ax ;first_root_dir_sector is stored here
    
    ; push ax ;push fat_count * fat_size
    push cx
    call lba_to_chs
    add sp, 2
    mov ax, 0x220 ;read (0x2) 0x20 (32) sectors
    
    mov bx, [data.disc_dir_seg]
    mov es, bx
    mov bx, [data.disc_dir_ptr]
    int 0x13 ;CHS address filled by LBA_TO_CHS call
    
    ;root_dir_sector_count = (root_dir_entry_count * 32 + bytes_per_sector - 1)/bytes_per_sector
    
    ;Step 3: Recursively search directories until file is found
    ;TODO: actually add recursive searching
    ;TODO: fix file searching
    
    ;set up string pointers
    mov bx, [data.disc_dir_seg]
    mov es, bx
    mov di, [data.disc_dir_ptr]
    
    xor bx, bx
    mov ds, bx
    ; mov dx, 8
    ;set cx to max number of entries
    mov cx, 512
    .searchloop:
        mov si, [bp + 0xa]
        mov bx, di
    .filename_stringcmp:
        ; cmp byte [ds:si], 0
        ; je .found_filename
        
        ; mov al, [ds:si]
        ; cmp al, [es:bx]
        ; jne .searchloop_continue
        ; inc si
        ; inc bx
        ; mov ax, bx
        ; sub ax, di
        ; cmp ax, 11
        ; jle .found_filename
        mov al, [es:di]
        cmp al, [ds:si]
        jne .searchloop_continue
        inc si
        inc di
        cmp byte [ds:si], '0'
        je .found_filename
        mov ax, di
        sub ax, bx
        cmp ax, 11
        jge .found_filename
        cmp byte [ds:si], '.'
        jne .filename_stringcmp
        mov di, bx
        add di, 8
        inc si
        jmp .filename_stringcmp
        ;took me an hour to fix this... commented out code is staying in commit
    .found_filename:
        ; mov ax, bx
        ; sub ax, di
        ; cmp ax, 8
        ; jge .searchloop_end
        ; cmp byte [es:bx], '0'
        mov di, bx
        je .searchloop_end
    .searchloop_continue:
        mov di, bx
        add di, 32
        dec cx
        jcxz .ret_err
        
        cmp byte [es:di], 0
        jne  .searchloop
        
        mov ax, [bp + 0xa]
        push ax
        mov ax, [bp + 0x8]
        push ax
        mov ax, [bp + 0x6]
        push ax
        mov ax, [bp + 0x4]
        push ax
        
        call create_file
        add sp, 8
        jmp .ret
        ;if file does not exist, create file
        
        
    .searchloop_end:
    ;cmp data in directory
    ;Step 4: set data in struct
        mov ax, [es:di + 26]
        mov bx, [bp + 0x4]
        mov ds, bx
        mov bx, [bp + 0x6]
        mov [ds:bx], ax
        mov [ds:bx + 2], ax
    .ret: ; pop gp registers off of the stack, then return
        mov ax, 0
    .ret_err:
        pop si
        pop di
        pop cx
        pop dx
        pop bx
        pop ds
        pop es
        
        pop bp
        ret
        
create_file: ;cdelc void create_file(FILE *file, char *fname)
    push bp
    mov bp, sp
    
    push es
    push ds
    push cx
    push bx
    push si
    push di
    push dx
    
    mov ax, 0xe03
    int 0x10
    
    xor dx, dx
    xor bx, bx
    mov ds, bx
    mov bx, [data.disc_bpb_ptr]
    mov ax, [bx + 0x10]
    mov cx, [bx + 0x16]
    mul cx
    mov cx, [bx + 0x0e]
    add cx, ax ;first_root_dir_sector is stored here
    
    ; push ax ;push fat_count * fat_size
    push cx
    
    push cx
    call lba_to_chs
    add sp, 2
    mov ax, 0x220 ;read (0x2) 0x20 (32) sectors
    
    mov bx, [data.disc_dir_seg]
    mov es, bx
    mov bx, [data.disc_dir_ptr]
    int 0x13 ;CHS address filled by LBA_TO_CHS call
    
    mov di, [bp + 0x8]
    mov es, di
    mov di, [bp + 0xa]
    
    mov si, [data.disc_dir_ptr]
    push si
    mov si, [data.disc_dir_seg]
    mov ds, si
    pop si ;ds:si contains pointer to loaded directory (root)
    
    mov ax, 0xffff
    mov cx, 512
    .search_free_dirent:
        cmp byte [ds:si], 0
        je .set_filename
        add si, 32
        dec cx
        jcxz .return
        jmp .search_free_dirent
    .set_filename:
        mov ax, ds
        mov bx, es
        mov ds, bx
        mov es, ax
        
        mov cx, 8
        
        xchg di, si ;now es:di contains ptr to loaded directory
        mov bx, di
    .sfn_loop:
        movsb
        dec cx
        cmp byte [ds:si], '.'
        je .set_file_ext
        cmp cx, 0
        jle .set_file_ext
        cmp byte [ds:si], 0
        jne .sfn_loop
    .set_file_ext:
        mov ax, 0xe05
        int 0x10
        inc si
        mov di, bx
        add di, 8
    .sfe_loop:
        movsb
        cmp byte [ds:si], 0
        je .find_cluster
        jmp .sfe_loop
    
    .find_cluster:
        mov ax, 0xe04
        int 0x10
        mov di, bx
        call find_free_cluster
        
        mov word [es:di + 0x1a], ax ; dirent.first_cluster = cluster_index
        
        mov bx, [bp + 4]
        mov ds, bx
        mov bx, [bp + 6]
        
        mov [ds:bx], ax
        mov [ds:bx + 2], ax
        ;FILE[0] = cluster_index
        ;FILE[1] = FILE[0]
        
        push -1
        push ax
        call set_cluster
        add sp, 4
        
    .disk_writeback:
        call lba_to_chs
        add sp, 2
        mov ax, 0x320
        mov bx, [data.disc_dir_seg]
        mov es, bx
        mov bx, [data.disc_dir_ptr]
        int 0x13
        
        call fat_writeback
        
        ;write_disk(disk_dir, disk, disk_dir_lba)
        ;write_disk(disk_fat, disk, disk_fat_lba)
    .return:
        pop dx
        pop di
        pop si
        pop bx
        pop cx
        pop ds
        pop es
        
        pop bp
        ret

find_free_cluster: ;cdelc uint16_t find_free_cluster()
    ;search disk_fat_ptr array for any cluster marked 0
    push bp
    mov bp, sp
    
    push bx
    push ds
    push si
    push dx
    
    mov bx, [data.disc_fat_seg]
    mov si, [data.disc_fat_ptr]
    mov ds, bx
    xor bx, bx
    
    .find_cluster_loop:
        cmp word [ds:si + bx], 0
        je .found
        add bx, 2
        jmp .find_cluster_loop
    .found:
        mov ax, bx
        xor dx, dx
        mov bx, 2
        div bx
        
    pop dx
    pop si
    pop ds
    pop bx
    
    pop bp
    ret

set_cluster: ;cdelc void set_cluster(uint16_t index, uint16_t value)
    ;set cluster at index to value
    push bp
    mov bp, sp
    
    push ds
    push si
    push bx
    push dx
    
    mov bx, [data.disc_fat_seg]
    mov si, [data.disc_fat_ptr]
    mov ds, bx
    mov ax, [bp + 4]
    mov bx, 2
    xor dx, dx
    mul bx
    mov bx, ax
    
    mov ax, [bp + 6]
    mov [ds:si + bx], ax
    
    pop dx
    pop bx
    pop si
    pop ds
    
    pop bp
    ret

get_cluster: ;cdelc uint16_t get_cluster(uint16_t index)
    ;returns the value at cluster index
    push bp
    mov bp, sp
    
    push bx
    push ds
    push si
    push dx
    push cx
    
    mov bx, [data.disc_fat_seg]
    mov si, [data.disc_fat_ptr]
    mov ds, bx
    xor bx, bx
    
    mov ax, [bp + 0x4]
    mov bx, 2
    xor dx, dx
    mul bx
    
    mov bx, ax
    mov ax, [ds:si + bx]
    
    pop cx
    pop dx
    pop si
    pop ds
    pop bx
    
    pop bp
    ret

write_data_cluster:;cdelc write_data_cluster(int16_t cluster, char *data_buffer)
    ;ARGS:  data_buffer_ptr : bp + 0x6
    ;       data_buffer_seg : bp + 0x4
    ;       cluster         : bp + 0x8
    push bp
    mov bp, sp
    
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    
    ;root_dir_sectors = (root_entry_count * 32 + bytes_per_sector - 1)/bytes_per_sector
    
    mov bx, [data.disc_bpb_seg]
    mov cx, [data.disc_bpb_ptr]
    mov ds, bx
    mov si, cx
    xor dx, dx
    mov ax, [ds:si + 0x11]
    
    mov bx, 32
    mul bx
    xor dx, dx
    add ax, 511
    mov bx, 512
    div bx
    push ax
    
    ;first_data_sector = ((fat_count * fat_size) + reserved_sectors + root_dir_sectors)
    mov ax, [ds:si + 0x16]
    mov bl, [ds:si + 0x10]
    mul bl
    pop bx
    add ax, bx           ; + root_dir_sectors
    add ax, [ds:si + 0xe]; + reserved_sectors
    push ax
    
    ;sector_to_read = first_data_sector + cluster * cluster_size_sectors
    mov al, [ds:si + 0xd]
    xor ah, ah
    
    xor dx, dx
    mov bx, [bp + 0x8]
    mul bx; ax = cluster * cluster_size_sectors
    pop bx
    add ax, bx
    
    push ax
    call lba_to_chs
    add sp, 2
    
    mov al, [ds:si + 0xd]
    mov ah, 0x3
    mov bx, [bp + 0x4]
    mov es, bx
    mov bx, [bp + 0x6]
    int 0x13;write cluster to disk
    
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    
    pop bp
    ret
    
read_data_cluster:;cdelc read_data_cluster(int16_t cluster, char *data_buffer)
    ;ARGS:  data_buffer_ptr : bp + 0x6
    ;       data_buffer_seg : bp + 0x4
    ;       cluster         : bp + 0x8
    push bp
    mov bp, sp
    
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    
    ;root_dir_sectors = (root_entry_count * 32 + bytes_per_sector - 1)/bytes_per_sector
    
    mov bx, [data.disc_bpb_seg]
    mov cx, [data.disc_bpb_ptr]
    mov ds, bx
    mov si, cx
    xor dx, dx
    mov ax, [ds:si + 0x11]
    
    mov bx, 32
    mul bx
    xor dx, dx
    add ax, 511
    mov bx, 512
    div bx
    push ax
    
    ;first_data_sector = ((fat_count * fat_size) + reserved_sectors + root_dir_sectors)
    mov ax, [ds:si + 0x16]
    mov bl, [ds:si + 0x10]
    mul bl
    pop bx
    add ax, bx           ; + root_dir_sectors
    add ax, [ds:si + 0xe]; + reserved_sectors
    push ax
    
    ;sector_to_read = first_data_sector + cluster * cluster_size_sectors
    mov al, [ds:si + 0xd]
    xor ah, ah
    
    xor dx, dx
    mov bx, [bp + 0x8]
    mul bx; ax = cluster * cluster_size_sectors
    pop bx
    add ax, bx
    
    push ax
    call lba_to_chs
    add sp, 2
    
    mov al, [ds:si + 0xd]
    mov ah, 0x2
    mov bx, [bp + 0x4]
    mov es, bx
    mov bx, [bp + 0x6]
    int 0x13;write cluster to disk
    
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    
    pop bp
    ret

fat_writeback:
    push bp
    mov bp, sp
    pusha
    
    mov bx, [data.disc_bpb_seg]
    mov si, [data.disc_bpb_ptr]
    mov ds, bx
    
    mov bx, [ds:si + 0x16]
    ; push bx
    push bx
    
    mov ax, [ds:si + 0xe]
    ; push ax
    push ax
    call lba_to_chs
    add sp, 2
    
    mov ah, -7
    pop bx
    mov al, bl ;for 2.88mb floppy drives, should not be larger than 22.5 sectors
    
    xor bx, bx
    mov ds, bx
    mov bx, [data.disc_fat_seg]
    mov es, bx
    mov bx, [data.disc_fat_ptr]
    
    int 0x13
    
    popa
    pop bp
    ret
times 2048 - ($-$$) db 0
;struct FILE *f{
    ;uint16_t current_index;
    ;uint16_t first_cluster_index;
; }

times (2880 * 1024) - ($ - $$) db 0