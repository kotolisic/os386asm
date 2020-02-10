all:
	fasm os386.asm
	mv os386.bin disk/
	bochs -f c.bxrc -q

disk:
	dd if=/dev/zero of=disk.img bs=1024 count=262144
	mkdir disk

mount:
	sudo mount disk.img -t vfat -o loop,rw,uid="`whoami`",sync,offset=$[1048576] disk/

