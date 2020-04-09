#!/bin/bash

set -e -u

iso_name=archlinux
iso_label="ARCH_$(date +%Y%m)"
iso_version=$(date +%Y.%m.%d)
install_dir=archiso
work_dir=work
out_dir=out
img_dir=img

script_path=$(readlink -f "${0%/*}")

umask 0022

make_image() {
    fallocate -l 2G "${out_dir}/${iso_name}-${iso_version}.img"
    losetup /dev/loop0 "${out_dir}/${iso_name}-${iso_version}.img"
    parted /dev/loop0 mklabel gpt
    mkfs.vfat -n "${iso_label}" /dev/loop0
    mount /dev/loop0 "${img_dir}"
}

# Setup custom pacman.conf with current cache directories.
make_pacman_conf() {
    local _cache_dirs
    _cache_dirs=("$(pacman -v 2>&1 | grep '^Cache Dirs:' | sed 's/Cache Dirs:\s*//g')")
    sed -r "s|^#?\\s*CacheDir.+|CacheDir = $(echo -n "${_cache_dirs[@]}")|g" "${script_path}/pacman.conf" > ${work_dir}/pacman.conf
}

# Base installation, plus needed packages (airootfs)
make_basefs() {
    mkarchiso -v -w "${work_dir}/x86_64" -C "${work_dir}/pacman.conf" -D "${install_dir}" init
    mkarchiso -v -w "${work_dir}/x86_64" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "haveged intel-ucode amd-ucode mkinitcpio-nfs-utils nbd efitools" install
}

# Additional packages (airootfs)
make_packages() {
    mkarchiso -v -w "${work_dir}/x86_64" -C "${work_dir}/pacman.conf" -D "${install_dir}" -p "$(grep -h -v "^#" "${script_path}/packages.x86_64")" install
}

# Copy mkinitcpio archiso hooks and build initramfs (airootfs)
make_setup_mkinitcpio() {
    local _hook
    mkdir -p ${work_dir}/x86_64/airootfs/etc/initcpio/hooks
    mkdir -p ${work_dir}/x86_64/airootfs/etc/initcpio/install
    for _hook in archiso archiso_shutdown archiso_pxe_common archiso_pxe_nbd archiso_pxe_http archiso_pxe_nfs archiso_loop_mnt; do
        cp /usr/lib/initcpio/hooks/${_hook} ${work_dir}/x86_64/airootfs/etc/initcpio/hooks
        cp /usr/lib/initcpio/install/${_hook} ${work_dir}/x86_64/airootfs/etc/initcpio/install
    done
    sed -i "s|/usr/lib/initcpio/|/etc/initcpio/|g" ${work_dir}/x86_64/airootfs/etc/initcpio/install/archiso_shutdown
    cp /usr/lib/initcpio/install/archiso_kms ${work_dir}/x86_64/airootfs/etc/initcpio/install
    cp /usr/lib/initcpio/archiso_shutdown ${work_dir}/x86_64/airootfs/etc/initcpio
    cp "${script_path}/mkinitcpio.conf" ${work_dir}/x86_64/airootfs/etc/mkinitcpio-archiso.conf

    mkarchiso -v -w "${work_dir}/x86_64" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r 'mkinitcpio -c /etc/mkinitcpio-archiso.conf -k /boot/vmlinuz-linux -g /boot/archiso.img' run
}

# Customize installation (airootfs)
make_customize_airootfs() {
    cp -af "${script_path}/airootfs" "${work_dir}/x86_64"

    cp "${script_path}/pacman.conf" "${work_dir}/x86_64/airootfs/etc"

    curl -o "${work_dir}/x86_64/airootfs/etc/pacman.d/mirrorlist" "https://www.archlinux.org/mirrorlist/?country=all&protocol=http&use_mirror_status=on"

    mkarchiso -v -w "${work_dir}/x86_64" -C "${work_dir}/pacman.conf" -D "${install_dir}" -r "/root/customize_airootfs.sh" run
    rm "${work_dir}/x86_64/airootfs/root/customize_airootfs.sh"
}

# Prepare kernel/initramfs ${install_dir}/boot/
make_efi() {
    mkdir -p "${img_dir}/EFI/archiso"
    mkdir -p "${img_dir}/EFI/boot"
    mkdir -p "${img_dir}/loader/entries"

    cp "${work_dir}/x86_64/airootfs/boot/archiso.img" "${img_dir}/EFI/${install_dir}/"
    cp "${work_dir}/x86_64/airootfs/boot/vmlinuz-linux" "${img_dir}/EFI/${install_dir}/vmlinuz"

    cp "${work_dir}/x86_64/airootfs/boot/intel-ucode.img" "${img_dir}/EFI/${install_dir}/intel_ucode.img"
    cp "${work_dir}/x86_64/airootfs/boot/amd-ucode.img" "${img_dir}/EFI/${install_dir}/amd_ucode.img"

    cp "${work_dir}/x86_64/airootfs/usr/share/efitools/efi/PreLoader.efi" "${img_dir}/EFI/boot/bootx64.efi"
    cp "${work_dir}/x86_64/airootfs/usr/share/efitools/efi/HashTool.efi" "${img_dir}/EFI/boot/"

    cp "${work_dir}/x86_64/airootfs/usr/lib/systemd/boot/efi/systemd-bootx64.efi" "${img_dir}/EFI/boot/loader.efi"
    cp "${script_path}/efiboot/loader/loader.conf" "${img_dir}/loader/"

    sed "s|%ARCHISO_LABEL%|${iso_label}|g;
        s|%INSTALL_DIR%|EFI/${install_dir}|g" \
       "${script_path}/efiboot/loader/entries/archiso-x86_64-usb.conf" > "${img_dir}/loader/entries/archiso-x86_64.conf"
}

# Build airootfs filesystem image
make_prepare() {
    cp -a -l -f "${work_dir}/x86_64/airootfs" "${work_dir}"
    mkdir -p "${img_dir}/EFI/${install_dir}/$(uname -m)/"

    mksquashfs "${work_dir}/airootfs" "${img_dir}/EFI/${install_dir}/$(uname -m)/airootfs.sfs" -noappend -comp zstd

    cd "${img_dir}/EFI/${install_dir}/$(uname -m)"
    sha512sum "airootfs.sfs" > "airootfs.sha256"
    cd "${OLDPWD}"

    rm -rf "${work_dir}/airootfs"
}

cleanup() {
    umount "${img_dir}"
    losetup -d /dev/loop0
    rmdir "${img_dir}"
}

if [[ ${EUID} -ne 0 ]]; then
    echo "This script must be run as root."
    exit
fi

mkdir -p "${work_dir}"
mkdir -p "${out_dir}"
mkdir -p "${img_dir}"

make_image
make_pacman_conf
make_basefs
make_packages
make_setup_mkinitcpio
make_customize_airootfs
make_efi
make_prepare
cleanup