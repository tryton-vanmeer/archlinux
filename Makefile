build:
	sudo chown -R root:root airootfs/
	sudo ./build.sh -v
	sudo chown -R 1000:1000 airootfs/
clean:
	sudo rm -r ./work ./out
test:
	qemu-system-x86_64 -enable-kvm -bios /usr/share/ovmf/x64/OVMF.fd -m 1G -cdrom out/archlinux-*.iso