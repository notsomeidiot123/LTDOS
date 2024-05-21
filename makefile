AS = nasm
ASFLAGS = -f bin

all:
	$(AS) main.s $(ASFLAGS) -o main
	qemu-img resize --shrink main 2.88M
	qemu-system-i386 -fda main -fdb fdb.img -m 1M -serial mon:stdio