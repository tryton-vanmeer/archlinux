#!/bin/bash

set -e -u

sed -i 's/#\(en_CA\.UTF-8\)/\1/' /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/EST5EDT /etc/localtime

usermod -s /usr/bin/fish root

ln -sf /usr/bin/dash /usr/bin/sh

# Liveuser
useradd -m -g users -G "adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel" -s /usr/bin/fish liveuser
passwd -d liveuser
chown -R liveuser:users /home/liveuser

dconf update
xdg-user-dirs-update

sed -i 's/#\(PermitRootLogin \).\+/\1yes/' /etc/ssh/sshd_config
sed -i "s/#Server/Server/g" /etc/pacman.d/mirrorlist
sed -i 's/#\(Storage=\)auto/\1volatile/' /etc/systemd/journald.conf

sed -i 's/#\(HandleSuspendKey=\)suspend/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleHibernateKey=\)hibernate/\1ignore/' /etc/systemd/logind.conf
sed -i 's/#\(HandleLidSwitch=\)suspend/\1ignore/' /etc/systemd/logind.conf

systemctl enable pacman-init.service choose-mirror.service
systemctl set-default graphical.target

systemctl enable NetworkManager