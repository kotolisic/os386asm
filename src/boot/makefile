all:
	fasm disk32.asm
	dd conv=notrunc if=disk32.bin of=../disk.img bs=446 count=1
	cd .. && bochs -f c.bxrc -q

# Только для справки. sdX поменять на sde, sdf и так далее (для диска)
usb:
	dd conv=notrunc if=disk32.bin of=/dev/sdX bs=446 count=1
