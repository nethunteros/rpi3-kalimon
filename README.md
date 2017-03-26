# Official Builds are now in Offsec Repo:

https://github.com/offensive-security/kali-arm-build-scripts

Use the rpi3-nexmon.sh file and make sure you have a toolchain.

# Old Info

## Raspberry Pi 3 Image with monitor mode

_This is an unofficial Kali Raspberry Pi 3 image. Official releases are now being moved to offsec repo_

This uses re4son's PI TFT kernel with Nexmon firmware for native monitor mode.

## Download

Don't want to build but you are ready to download?

https://github.com/nethunteros/rpi3-kalimon/releases

## Screenshot

![Screenshot](http://i.imgur.com/KQxqcbP.jpg)

## Instructions to build your own image

On Ubuntu or Kali download prereqs:
```bash
dpkg --add-architecture i386  # For 64 bit
apt-get install -y git-core gnupg flex bison gperf libesd0-dev build-essential \
zip curl libncurses5-dev zlib1g-dev libncurses5-dev gcc-multilib g++-multilib \
parted kpartx debootstrap pixz qemu-user-static abootimg cgpt vboot-kernel-utils \
vboot-utils bc lzma lzop xz-utils automake autoconf m4 dosfstools rsync u-boot-tools \
schedtool git e2fsprogs device-tree-compiler ccache dos2unix debootstrap libgmp3-dev:i386 libgmp3-dev
```
Get the latest kernel and nexmon by running bootstrap.sh
```bash
./bootstrap.sh
```
Modify the variables at the top of pi3.sh.  You can turn off TFT display by turn it to false.

Then run pi3.sh with version number
```bash
./pi3.sh 0.1
```
If you receive an error about debootstrap not having permissions then you may need to remount your home folder:
```
mount -o remount,exec,dev /home/[yourusername]/ -i
```

## Modification

To change the size of LCD screen modify the command line with correct size of screen:
```bash
# This example is a 3.5" screen
sudo chroot $dir /bin/bash -c "/root/re4son-pi-tft-setup -t 35r -u /root"
```
You can also run the same command to switch to TFT display if you install one later:
```
/root/re4son-pi-tft-setup -t 35r -u /root
```

## Sources:

* Steev's Scripts: https://github.com/offensive-security/kali-arm-build-scripts
* re4son: https://whitedome.com.au/re4son/sticky-fingers-kali-pi/#Vanilla
* re4son's github: https://github.com/re4son/
* nexmon: https://github.com/seemoo-lab/bcm-rpi3
* g0tmi1lk: https://github.com/g0tmi1k/os-scripts/blob/master/kali-rolling.sh
