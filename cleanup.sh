#!/bin/bash
architecture="armhf"

function ask() {
    # http://djm.me/ask
    while true; do

        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question
        read -p "$1 [$prompt] " REPLY

        # Default?
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi

        # Check if the reply is valid
        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}

echo "[+] Checking for previous build folders"
if [ -d kali-$architecture ]; then
	umount -l kali-$architecture/proc/sys/fs/binfmt_misc
	umount -l kali-$architecture/dev/pts
	umount -l kali-$architecture/dev/
	umount -l kali-$architecture/proc
	if ask "[?] Remove previous chroot build?"; then
		rm -rf kali-$architecture
	fi
fi

if [ -d rpi2-kali ]; then
	umount rpi2-kali/root
	umount rpi2-kali/bootp
	umount rpi2-kali
        if ask "[?] Remove previous image build folder?"; then
		rm -rf rpi2-kali
	fi
fi

if [ -d /tmp/rpi ]; then
	dir=/tmp/rpi
	sudo umount $dir/boot
	sudo umount -l $dir/proc
	sudo umount -l $dir/dev/
	sudo umount -l $dir/dev/pts
	sudo umount $dir
        if ask "[?] Remove previous tmp mounted folder /tmp/rpi?"; then
		rm -rf /tmp/rpi
	fi
fi
echo "[+] Finished"
