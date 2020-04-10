# Custom Arch Linux Image

Archiso with GNOME desktop and personal tweaks.

## Extras

+ A systemd-boot entry is provided for booting [Netboot.xyz](https://netboot.xyz/)

+ Dark themes by default everywhere

+ `arch-wiki-docs` and `arch-wiki-lite` are installed. Firefox homepage is set to the local Installation Guide page.

+ Personal tweaks to Firefox

+ uBlock Origin installed

+ Fish is the default shell

+ Personal tweaks to GNOME and GNOME apps

+ Fractiona Scaling enabled by default

+ [Starship](https://starship.rs/) prompt installed

+ [inxi](https://github.com/smxi/inxi) installed

+ [Dracula](https://draculatheme.com/) theme applied

+ Extra apps like: GNOME Disk Utility, Evince, GParted, GNOME Screenshot, Gedit, and GNOME System Monitor

## Screenshots

![Screenshot Desktop 1](assets/screenshot-desktop-1.png)

## Building

`make build`

This will output a `img` instead of an `iso`. This can be written to a USB in the same
way, but will only boot on UEFI systems.