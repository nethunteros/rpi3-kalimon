#!/bin/bash
architecture="armhf"

umount -l kali-$architecture/proc/sys/fs/binfmt_misc
umount -l kali-$architecture/dev/pts
umount -l kali-$architecture/dev/
umount -l kali-$architecture/proc

umount rpi2-kali/root
umount rpi2-kali/bootp
umount rpi2-kali

dir=/tmp/rpi
sudo umount $dir/boot
sudo umount -l $dir/proc
sudo umount -l $dir/dev/
sudo umount -l $dir/dev/pts
sudo umount $dir

#rm -rf kali-$architecture
