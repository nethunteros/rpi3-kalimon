#!/bin/bash

# Kali Linux on ARM with
# re4son's PI TFT kernel with nexmon
#
# re4son: https://whitedome.com.au/re4son/sticky-fingers-kali-pi/#Vanilla
# > github: https://github.com/re4son/
#
# nexmon: https://github.com/seemoo-lab/bcm-rpi3
#

# Package installations for various sections.
# This will build a minimal XFCE Kali system with the top 10 tools.
# This is the section to edit if you would like to add more packages.
# See http://www.kali.org/new/kali-linux-metapackages/ for meta packages you can
# use. You can also install packages, using just the package name, but keep in
# mind that not all packages work on ARM! If you specify one of those, the
# script will throw an error, but will still continue on, and create an unusable
# image, keep that in mind.


# This is the Raspberry Pi2 Kali ARM build script - http://www.kali.org/downloads
# A trusted Kali Linux image created by Offensive Security - http://www.offensive-security.com

if [[ $# -eq 0 ]] ; then
    echo "Please pass version number, e.g. $0 2.0"
    exit
fi

basedir=`pwd`/rpi2-kali			    # OUTPUT
architecture="armhf"			    # ARCH
DIRECTORY=`pwd`/kali-$architecture	# CHROOT FS
TOPDIR=`pwd`
VERSION=$1

function build_chroot(){

arm="abootimg cgpt fake-hwclock ntpdate u-boot-tools vboot-utils vboot-kernel-utils"
base="e2fsprogs initramfs-tools kali-defaults kali-menu parted sudo usbutils"
desktop="fonts-croscore fonts-crosextra-caladea fonts-crosextra-carlito gnome-theme-kali gtk3-engines-xfce kali-desktop-xfce kali-root-login lightdm network-manager network-manager-gnome xfce4 xserver-xorg-video-fbdev"
tools="ethtool hydra john libnfc-bin mfoc nmap passing-the-hash sqlmap usbutils winexe wireshark metasploit-framework"
services="apache2 openssh-server tightvncserver dnsmasq hostapd"
mitm="bettercap mitmf responder"
extras="iceweasel xfce4-terminal wpasupplicant florence tcpdump dnsutils gcc build-essential bluez-firmware"
pygame="fbi python-pbkdf2 python-pip cmake libusb-1.0-0-dev"
wireless="aircrack-ng kismet wifite mana-toolkit"

# kernel sauces take up space yo.
size=7000 # Size of image in megabytes

packages="${arm} ${base} ${desktop} ${tools} ${services} ${extras} ${pygame} ${mitm} ${wireless}"
architecture="armhf"

# If you have your own preferred mirrors, set them here.
# After generating the rootfs, we set the sources.list to the default settings.
mirror=http.kali.org

# Set this to use an http proxy, like apt-cacher-ng, and uncomment further down
# to unset it.
#export http_proxy="http://localhost:3142/"

# Make output folder
mkdir -p ${basedir}

# create the rootfs - not much to modify here, except maybe the hostname.
debootstrap --foreign --arch $architecture kali-rolling kali-$architecture http://$mirror/kali

cp /usr/bin/qemu-arm-static kali-$architecture/usr/bin/

LANG=C chroot kali-$architecture /debootstrap/debootstrap --second-stage
cat << EOF > kali-$architecture/etc/apt/sources.list
deb http://$mirror/kali kali-rolling main contrib non-free
EOF

# Copy Nexmon utility to temp so we can build in chroot at stage 3
cp nexmon/nexutil.c kali-$architecture/tmp/nexutil.c
cp -rf nexmon/libfakeioctl/ kali-$architecture/tmp/libfakeioctl

# Set hostname
echo "kali" > kali-$architecture/etc/hostname

# So X doesn't complain, we add kali to hosts
cat << EOF > kali-$architecture/etc/hosts
127.0.0.1       kali    localhost
::1             localhost ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

cat << EOF > kali-$architecture/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

cat << EOF > kali-$architecture/etc/resolv.conf
nameserver 8.8.8.8
EOF

export MALLOC_CHECK_=0 # workaround for LP: #520465
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

mount -t proc proc kali-$architecture/proc
mount -o bind /dev/ kali-$architecture/dev/
mount -o bind /dev/pts kali-$architecture/dev/pts

cat << EOF > kali-$architecture/debconf.set
console-common console-data/keymap/policy select Select keymap from full list
console-common console-data/keymap/full select en-latin1-nodeadkeys
EOF

cat << EOF > kali-$architecture/third-stage
#!/bin/bash
dpkg-divert --add --local --divert /usr/sbin/invoke-rc.d.chroot --rename /usr/sbin/invoke-rc.d
cp /bin/true /usr/sbin/invoke-rc.d
echo -e "#!/bin/sh\nexit 101" > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

apt-get update
apt-get --yes --force-yes install locales-all

debconf-set-selections /debconf.set
rm -f /debconf.set
apt-get update
apt-get -y install git-core binutils ca-certificates initramfs-tools u-boot-tools
apt-get -y install locales console-common less nano git
echo "root:toor" | chpasswd
wget https://gist.githubusercontent.com/sturadnidge/5695237/raw/444338d0389da39f5df615ff47ceb12d41be7fdb/75-persistent-net-generator.rules -O /lib/udev/rules.d/75-persistent-net-generator.rules
sed -i -e 's/KERNEL\!=\"eth\*|/KERNEL\!=\"/' /lib/udev/rules.d/75-persistent-net-generator.rules
rm -f /etc/udev/rules.d/70-persistent-net.rules

echo "[+] Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get --yes --force-yes install $packages
apt-get --yes --force-yes dist-upgrade
apt-get --yes --force-yes autoremove

# Because copying in authorized_keys is hard for people to do, let's make the
# image insecure and enable root login with a password.

echo "[+] Making root great again"
sed -i -e 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
update-rc.d ssh enable

# Add user "pi"
echo "[+] Creating pi user"
useradd -m pi
usermod -a -G sudo,kismet pi
echo "pi:raspberry" | chpasswd

# Nexmon utility build to /usr/bin/nexutil and ioctl intercept
cd /tmp
gcc -o /usr/bin/nexutil /tmp/nexutil.c
chmod +x /usr/bin/nexutil
cd libfakeioctl
make
cp libfakeioctl.so /usr/lib
make clean

# Install SDR-Scanner
cd /home/pi
git clone git://git.osmocom.org/rtl-sdr.git
cd rtl-sdr
mkdir build
cd build
cmake ../ -DINSTALL_UDEV_RULES=ON -DDETACH_KERNEL_DRIVER=ON
make
sudo make install
sudo ldconfig
sudo pip install pyrtlsdr
cd /home/pi
git clone https://github.com/adafruit/FreqShow.git

# PiTFT Touch menu
cd /home/pi
sudo pip install RPi.GPIO
git clone https://github.com/Re4son/pitftmenu -b 3.5-MSF # Default to 3.5 size screens (https://www.adafruit.com/product/1601)
echo '%pi ALL=(ALL:ALL) NOPASSWD: /sbin/poweroff, /sbin/reboot, /sbin/shutdown, /home/pi/pitftmenu/menu' >> /etc/sudoers
echo "/usr/bin/clear"  >> /home/pi/.profile
echo 'sudo /home/pi/pitftmenu/menu' >> /home/pi/.profile

# Allow "anybody" to access to xserver.  Either console or root
sed -i 's/allowed_users=console/allowed_users=anybody/' /etc/X11/Xwrapper.config
sed -i 's/allowed_users=root/allowed_users=anybody/' /etc/X11/Xwrapper.config

# Add virtual keyboard to login screen
echo "show-indicators=~language;~a11y;~session;~power" /etc/lightdm/lightdm-gtk-greeter.conf
echo "keyboard=florence --focus" >> /etc/lightdm/lightdm-gtk-greeter.conf

# Turn off wifi power saving
echo "## Fix WiFi drop out issues ##" >> /etc/rc.local
echo "iwconfig wlan0 power off" >> /etc/rc.local

# Add bluetooth packages from Raspberry Pi
cd /tmp
wget https://archive.raspberrypi.org/debian/pool/main/b/bluez/bluez_5.23-2+rpi2_armhf.deb
dpkg -i bluez_5.23-2+rpi2_armhf.deb
apt-mark hold bluez

wget https://archive.raspberrypi.org/debian/pool/main/p/pi-bluetooth/pi-bluetooth_0.1.1_armhf.deb
dpkg -i pi-bluetooth_0.1.1_armhf.deb
apt-mark hold pi-bluetooth

rm -f /usr/sbin/policy-rc.d
rm -f /usr/sbin/invoke-rc.d
dpkg-divert --remove --rename /usr/sbin/invoke-rc.d

rm -f /third-stage
EOF

chmod +x kali-$architecture/third-stage
LANG=C chroot kali-$architecture /third-stage

echo "[+] Creating backup wifi firmware in /root"
cp -f nexmon/brcmfmac43430-sdio.orig.bin kali-$architecture/root
cp -f nexmon/brcmfmac43430-sdio.bin kali-$architecture/root
cp -f misc/rpi3/brcmfmac43430-sdio.txt kali-$architecture/root

cat << EOF > kali-$architecture/cleanup
#!/bin/bash
rm -rf /root/.bash_history
apt-get update
apt-get clean
rm -f /0
rm -rf /tmp/*.deb /tmp/libfakeioctl /tmp/*.c
rm -f /hs_err*
rm -f cleanup
rm -f /usr/bin/qemu*
EOF

chmod +x kali-$architecture/cleanup
LANG=C chroot kali-$architecture /cleanup

umount kali-$architecture/dev/pts
umount kali-$architecture/dev/
umount kali-$architecture/proc
}

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

function build_image(){

mkdir -p ${basedir}

size=7000 # Size of image in megabytes

# Create the disk (img file) and partition it
echo "[+] Creating image file for Raspberry Pi2"
dd if=/dev/zero of=${basedir}/kali-$VERSION-rpi2.img bs=1M count=$size
parted ${basedir}/kali-$VERSION-rpi2.img --script -- mklabel msdos
parted ${basedir}/kali-$VERSION-rpi2.img --script -- mkpart primary fat32 0 64
parted ${basedir}/kali-$VERSION-rpi2.img --script -- mkpart primary ext4 64 -1

# Set the partition variables
# http://matthewkwilliams.com/index.php/2015/10/09/mounting-partitions-from-image-files-on-linux/
loopdevice=`losetup -f --show ${basedir}/kali-$VERSION-rpi2.img`
device=`kpartx -va $loopdevice| sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`
sleep 5
device="/dev/mapper/${device}"
bootp=${device}p1
rootp=${device}p2

# Create file systems
echo "[+] BOOTP filesystem mkfs.vfat"
mkfs.vfat $bootp
echo "[+] ROOT filesystem mkfs.ext4"
mkfs.ext4 $rootp

# Create the dirs for the partitions bootp & root and mount them
echo "[+] Creating ${basedir}/bootp ${basedir}/root folders and mounting"
mkdir -p ${basedir}/bootp ${basedir}/root
mount $bootp ${basedir}/bootp
mount $rootp ${basedir}/root

# Copy kali to /root folder
echo "[+] Rsyncing rootfs ${DIRECTORY}/ into root folder for image: ${basedir}/root/"
rsync -HPavz -q ${DIRECTORY}/ ${basedir}/root/

# Enable login over serial
echo "T0:23:respawn:/sbin/agetty -L ttyAMA0 115200 vt100" >> ${basedir}/root/etc/inittab

cat << EOF > ${basedir}/root/etc/apt/sources.list
deb http://http.kali.org/kali kali-rolling main contrib non-free
#deb-src http://http.kali.org/kali kali-rolling main non-free contrib
EOF

# Kernel section. If you want to use a custom kernel, or configuration, replace
# them in this section.
git clone --depth 1 https://github.com/Re4son/re4son-raspberrypi-linux.git -b rpi-4.4.y-re4son ${basedir}/root/usr/src/kernel
cd ${basedir}/root/usr/src/kernel
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

# Make kernel with re4sons defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- re4son_pi2_defconfig
make -j $(grep -c processor /proc/cpuinfo) zImage modules dtbs
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- modules_install INSTALL_MOD_PATH=${basedir}/root

# RPI Firmware
git clone --depth 1 https://github.com/raspberrypi/firmware.git rpi-firmware
cp -rf rpi-firmware/boot/* ${basedir}/bootp/

# ARGH.  Device tree support requires we run this *sigh*
perl scripts/mkknlimg --dtok arch/arm/boot/zImage ${basedir}/bootp/kernel7.img
#cp arch/arm/boot/zImage ${basedir}/bootp/kernel7.img
cp arch/arm/boot/dts/bcm*.dtb ${basedir}/bootp/
cp arch/arm/boot/dts/overlays/*overlay*.dtb* ${basedir}/bootp/overlays/
rm -rf ${basedir}/root/lib/firmware
cd ${basedir}/root/lib
git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git firmware
rm -rf ${basedir}/root/lib/firmware/.git
cd ${basedir}/root/usr/src/kernel
make INSTALL_MOD_PATH=${basedir}/root firmware_install
make mrproper
cp ${basedir}/root/usr/src/kernel/arch/arm/configs/re4son_pi2_defconfig arch/arm/configs/re4son_pi2_defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- re4son_pi2_defconfig
make modules_prepare
rm -rf rpi-firmware
cd ${basedir}

# Create cmdline.txt file
cat << EOF > ${basedir}/bootp/cmdline.txt
dwc_otg.fiq_fix_enable=2 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait rootflags=noload net.ifnames=0
EOF

# systemd doesn't seem to be generating the fstab properly for some people, so
# let's create one.
cat << EOF > ${basedir}/root/etc/fstab
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
proc /proc proc nodev,noexec,nosuid 0  0
/dev/mmcblk0p2  / ext4 errors=remount-ro 0 1
# Change this if you add a swap partition or file
#/var/swapfile none swap sw 0 0
/dev/mmcblk0p1 /boot vfat noauto 0 0
EOF

# Unmount partitions
umount $bootp
umount $rootp
kpartx -dv $loopdevice
losetup -d $loopdevice

# Clean up all the temporary build stuff and remove the directories.
# Comment this out to keep things around if you want to see what may have gone
# wrong.
echo "Cleaning up the temporary build files..."
rm -rf ${basedir}/kernel
rm -rf ${basedir}/bootp
rm -rf ${basedir}/root
rm -rf ${basedir}/boot
rm -rf ${basedir}/patches

# If you're building an image for yourself, comment all of this out, as you
# don't need the sha1sum or to compress the image, since you will be testing it
# soon.
OUTPUTFILE="${basedir}/kali-$VERSION-rpi2.img"

if [ -f "${OUTPUTFILE}" ]; then

    dir=/tmp/rpi
    test "umount" = "${OUTPUTFILE}" && sudo umount $dir/boot && sudo umount $dir
    image="${OUTPUTFILE}"
    test -r "$image"

    o_boot=`sudo sfdisk -l $image | grep FAT32 | awk '{ print $2 }'`
    o_linux=`sudo sfdisk -l $image | grep Linux | awk '{ print $2 }'`

    echo "Mounting img o_linux: $o_linux and o_boot: $o_boot"
    test -d $dir || mkdir -p $dir
    sudo mount -o offset=`expr $o_linux \* 512`,loop $image $dir
    sudo mount -o offset=`expr $o_boot  \* 512`,loop $image $dir/boot
    sudo mount -t proc proc $dir/proc
    sudo mount -o bind /dev/ $dir/dev/
    sudo mount -o bind /dev/pts $dir/dev/pts

    cp /usr/bin/qemu-arm-static $dir/usr/bin/
    chmod +755 $dir/usr/bin/qemu-arm-static

    # Copy firmware for nexmon
    echo "[+] Copying wifi firmware"
    mkdir -p $dir/lib/firmware/brcm/
    cp -rf $TOPDIR/nexmon/brcmfmac43430-sdio.bin $dir/lib/firmware/brcm/
    cp -rf $TOPDIR/misc/rpi3/brcmfmac43430-sdio.txt $dir/lib/firmware/brcm/

    echo "[+] Copying bt firmware"
    cp -f $TOPDIR/misc/bt/99-com.rules $dir/etc/udev/rules.d/99-com.rules
    cp -f $TOPDIR/misc/bt/BCM43430A1.hcd $dir/lib/firmware/brcm/BCM43430A1.hcd

    echo "[+] Copy Zram"
    cp -f $TOPDIR/misc/rpi3/zram $dir/etc/init.d/zram
    chmod +x $dir/etc/init.d/zram

    # Set up TFT
    wget https://raw.githubusercontent.com/Re4son/Re4son-Pi-TFT-Setup/rpts-4.4/adafruit-pitft-touch-cal -O $dir/root/adafruit-pitft-touch-cal
    wget https://raw.githubusercontent.com/Re4son/Re4son-Pi-TFT-Setup/rpts-4.4/re4son-pi-tft-setup -O $dir/root/re4son-pi-tft-setup
    chmod +x $dir/root/re4son-pi-tft-setup
    chmod +x $dir/root/adafruit-pitft-touch-cal
    sudo chroot $dir /bin/bash -c "/root/re4son-pi-tft-setup -t 35r -u /root"

    echo "Unmounting"
    sudo umount $dir/boot
    sudo umount -l $dir/proc
    sudo umount -l $dir/dev/
    sudo umount -l $dir/dev/pts
    sudo umount $dir
    rm -rf $dir

	# Compress output and generate sha1sum
	cd ${basedir}
	echo "Generating sha1sum for ${OUTPUTFILE}"
	sha1sum ${OUTPUTFILE} > ${OUTPUTFILE}.sha1sum
	echo "Compressing ${OUTPUTFILE}"
	xz -z ${OUTPUTFILE}
	echo "Generating sha1sum for kali-$VERSION-rpi2.img.xz"
	sha1sum ${OUTPUTFILE}.xz > ${OUTPUTFILE}.xz.sha1sum
else
	echo "${OUTPUTFILE} NOT FOUND!!!"
fi
}

if [ ! -d "$DIRECTORY" ]; then
	if ask "[?] Missing chroot. Build?"; then
		build_chroot
        build_image
	else
		exit
	fi
else
	if ask "[?] Previous chroot found.  Build new one?"; then
		build_chroot
        build_image
	else
		echo "Skipping chroot build"
		build_image
	fi
fi
