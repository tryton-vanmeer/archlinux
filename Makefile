build:
	sudo ./build.sh -v
clean:
	sudo rm -r ./work ./out
test:
	qemu-system-x86_64 -enable-kvm -bios /usr/share/ovmf/x64/OVMF.fd -m 1G -cdrom out/archlinux-*.iso