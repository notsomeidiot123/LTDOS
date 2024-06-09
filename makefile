AS = nasm
ASFLAGS = -f bin

all:
	$(AS) main.s $(ASFLAGS) -o main
	qemu-img resize --shrink main 2880K
	qemu-system-i386 -fda main -fdb fdb.img -m 1M -serial mon:stdio
	hexdump -C main > main.dump

run:
	qemu-system-i386 -fda main -fdb fdb.img -m 1M -serial mon:stdio
	hexdump -C main > main.dump