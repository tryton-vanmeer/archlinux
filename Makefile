build:
	sudo chown -R root:root airootfs/
	sudo ./build.sh
	sudo chown -R 1000:1000 airootfs/
clean:
	sudo rm -r ./work ./out
clean_mount:
	sudo umount ./img
	sudo losetup -d /dev/loop0
	sudo rmdir ./img