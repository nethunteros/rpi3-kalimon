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

#################
# MODIFY THESE  #
#################

BUILD_TFT=false      # Built for TFT Displays (Small LCD Screens)
COMPRESS=false       # Compress output file with XZ (useful for release images)
TFT_SIZE="35r"

#################
# TFT SIZE TBL  #
#################
# '28r'      (Adafruit 2.8 PID 1601)
# '28c'      (Adafruit 2.8 PID 1983)
# '35r'      (Adafruit 3.5)
# '22'       (Adafruit 2.2)
# 'elec22'   (Elecfreak 2.2)
# 'hy28b'    (Hotmcu HY28B 2.8)
# 'jb35'     (JBTek 3.5)
# 'kum35'    (Kuman 3.5)
# 'pi70'     (Raspberry Pi 7)
# 'sain32'   (Sainsmart 3.2)
# 'sain35'   (Sainsmart 3.5)
# 'wave32'   (Waveshare 3.2)
# 'wave35'   (Waveshare 3.5)
# 'wave35o'  (Waveshare 3.5 Overclocked)
# 'wave40'   (Waveshare 4)
# 'wave50'   (Waveshare 5\" HDMI)

if [[ $# -eq 0 ]] ; then
    echo "Please pass version number, e.g. $0 2.0"
    exit
fi

basedir=`pwd`/rpi2-kali             # OUTPUT FOLDER
architecture="armhf"                # DEFAULT ARCH
DIRECTORY=`pwd`/kali-$architecture  # CHROOT FS FOLDER
TOPDIR=`pwd`                        # CURRENT FOLDER
VERSION=$1

# BUILD THE KALI FILESYSTEM

function build_chroot(){

if [ ! -f /usr/share/debootstrap/scripts/kali-rolling ]; then
    #
    # For those not building on Kali
    #
    echo "Missing kali from debootstrap, downloading it"

    curl "http://git.kali.org/gitweb/?p=packages/debootstrap.git;a=blob_plain;f=scripts/kali;hb=refs/heads/kali/master" > /usr/share/debootstrap/scripts/kali
    ln -s /usr/share/debootstrap/scripts/kali /usr/share/debootstrap/scripts/kali-rolling
fi

arm="abootimg cgpt fake-hwclock ntpdate u-boot-tools vboot-utils vboot-kernel-utils"
base="e2fsprogs initramfs-tools kali-defaults kali-menu parted sudo usbutils bash-completion dbus"
desktop="fonts-croscore fonts-crosextra-caladea fonts-crosextra-carlito gnome-theme-kali kali-root-login lightdm network-manager network-manager-gnome xserver-xorg-video-fbdev xserver-xorg xinit"
xfce4="gtk3-engines-xfce xfconf kali-desktop-xfce xfce4-settings xfce4 xfce4-mount-plugin xfce4-notifyd xfce4-places-plugin xfce4-appfinder"
#lxde="lxde-core lxde lightdm kali-desktop-lxde lxtask gksu netsurf-gtk zenity xdg-utils"
tools="ethtool hydra john libnfc-bin mfoc nmap passing-the-hash sqlmap usbutils winexe wireshark metasploit-framework"
services="apache2 openssh-server tightvncserver dnsmasq hostapd"
mitm="bettercap mitmf responder backdoor-factory bdfproxy responder"
extras="unzip curl firefox-esr xfce4-terminal wpasupplicant florence tcpdump dnsutils gcc build-essential"
tft="fbi python-pbkdf2 python-pip cmake libusb-1.0-0-dev python-pygame bluez-firmware python-kivy"
wireless="aircrack-ng kismet wifite pixiewps mana-toolkit dhcpcd5 dhcpcd-gtk dhcpcd-dbus wireless-tools wicd-curses firmware-atheros firmware-libertas firmware-ralink firmware-realtek"
vpn="network-manager-openvpn network-manager-pptp network-manager-vpnc network-manager-openconnect network-manager-iodine"

# kernel sauces take up space yo.
size=7000 # Size of image in megabytes

if [ "${BUILD_TFT}" = true ] ; then
    packages="${arm} ${base} ${desktop} ${tools} ${services} ${extras} ${mitm} ${wireless} ${xfce4} ${tft} ${vpn}"
else
    packages="${arm} ${base} ${desktop} ${tools} ${services} ${extras} ${mitm} ${wireless} ${xfce4} ${vpn}"
fi

# Archteicture for Pi3 is armhf
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

echo "[+] Beginning SECOND stage"
LANG=C chroot kali-$architecture /debootstrap/debootstrap --second-stage

echo "[+] Sources.list"
cat << EOF > kali-$architecture/etc/apt/sources.list
deb http://$mirror/kali kali-rolling main contrib non-free
EOF

echo "[+] Hostname: kali"
# Set hostname
echo "kali" > kali-$architecture/etc/hostname

echo "[+] Hosts file"
# So X doesn't complain, we add kali to hosts
cat << EOF > kali-$architecture/etc/hosts
127.0.0.1       kali    localhost
::1             localhost ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF
chmod 644 kali-$architecture/etc/hosts

cat << EOF > kali-$architecture/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF
chmod 644 kali-$architecture/etc/network/interfaces

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

cat << EOF > kali-$architecture/etc/init.d/resize2fs_once
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO
. /lib/lsb/init-functions
case "$1" in
  start)
    log_daemon_msg "Starting resize2fs_once"
    ROOT_DEV=`grep -Eo 'root=[[:graph:]]+' /proc/cmdline | cut -d '=' -f 2-` &&
    resize2fs $ROOT_DEV &&
    update-rc.d resize2fs_once remove &&
    rm /etc/init.d/resize2fs_once &&
    log_end_msg $?
    ;;
  *)
    echo "Usage: $0 start" >&2
    exit 3
    ;;
esac
EOF
chmod 755 kali-$architecture/etc/init.d/resize2fs_once

cat << EOF > kali-$architecture/lib/systemd/system/regenerate_ssh_host_keys.service
#
[Unit]
Description=Regenerate SSH host keys

[Service]
Type=oneshot
ExecStartPre=/bin/sh -c "if [ -e /dev/hwrng ]; then dd if=/dev/hwrng of=/dev/urandom count=1 bs=4096; fi"
ExecStart=/usr/bin/ssh-keygen -A
ExecStartPost=/bin/rm /lib/systemd/system/regenerate_ssh_host_keys.service ; /usr/sbin/update-rc.d regenerate_ssh_host_keys remove

[Install]
WantedBy=multi-user.target
EOF
chmod 644 kali-$architecture/lib/systemd/system/regenerate_ssh_host_keys.service

# Tweaks
cp $TOPDIR/misc/xfce4-setup.sh kali-$architecture/tmp/xfce4-setup.sh
cp $TOPDIR/misc/bashtweaks.sh kali-$architecture/tmp/bashtweaks.sh

# Create monitor mode start/remove
cat << EOF > kali-$architecture/usr/bin/monstart
#!/bin/bash
echo "Brining interface down"
ifconfig wlan0 down
rmmod brcmfmac
echo "Copying modified firmware"
cp /root/brcmfmac43430-sdio.bin /lib/firmware/brcmfmac43430-sdio.bin && insmod /root/brcmfmac.ko
echo "Bringing wlan0"
ifconfig wlan0 up
EOF

cat << EOF > kali-$architecture/usr/bin/monstop
#!/bin/bash
echo "Brining interface down"
ifconfig wlan0 down
rmmod brcmfmac
echo "Copying original firmware"
cp /root/brcmfmac43430-sdio.orig.bin /lib/firmware/brcmfmac43430-sdio.bin && modprobe brcmfmac
EOF

echo "[+] Begin THIRD STAGE"
cat << EOF > kali-$architecture/third-stage
#!/bin/bash
dpkg-divert --add --local /lib/udev/rules.d/75-persistent-net-generator.rules
dpkg-divert --add --local --divert /usr/sbin/invoke-rc.d.chroot --rename /usr/sbin/invoke-rc.d
cp /bin/true /usr/sbin/invoke-rc.d
echo -e "#!/bin/sh\nexit 101" > /usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d

apt-get update
apt-get --yes --force-yes install locales-all

debconf-set-selections /debconf.set
rm -f /debconf.set
apt-get update
apt-get -y install git-core binutils ca-certificates initramfs-tools u-boot-tools curl
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

systemctl enable regenerate_ssh_host_keys
systemctl enable resize2fs_once

rm -f /etc/ssh/ssh_host_*_key*

# Because copying in authorized_keys is hard for people to do, let's make the
# image insecure and enable root login with a password.
echo "[+] Making root great again"
sed -i -e 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
update-rc.d ssh enable

# Add user "pi"
echo "[+] Creating pi user with password raspberry"
useradd -m pi -s /bin/bash
usermod -a -G sudo,kismet,pi pi
echo "pi:raspberry" | chpasswd
chown -R pi:pi /home/pi
echo "pi ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers 

# Enable autologin for user pi
mkdir -p /etc/lightdm/lightdm.conf.d/
echo "[SeatDefaults]\nautologin-user=pi" > /etc/lightdm/lightdm.conf.d/12-autologin.conf

# XFCE stuff (both users?)
echo "[+] Running XFCE setup"
chmod +x /tmp/xfce4-setup.sh
/tmp/xfce4-setup.sh

echo "[+] Running bash tweaks"
chmod +x /tmp/bashtweaks.sh
/tmp/bashtweaks.sh

chmod +x /usr/bin/monstart
chmod +x /usr/bin/monstop

# FOR TFT DISPLAYS
if [ "${BUILD_TFT}" = true ] ; then
    # Later version of xserver-org-input-libinput kill touch screen! Get last working version and hold!
    cd /tmp
    apt-get -y purge xserver-xorg-input-libinput
    wget http://http.kali.org/pool/main/x/xserver-xorg-input-libinput/xserver-xorg-input-libinput_0.19.0-1_armhf.deb
    dpkg -i xserver-xorg-input-libinput_0.19.0-1_armhf.deb
    apt-mark hold xserver-xorg-input-libinput
    rm -f xserver-xorg-input-libinput_0.19.0-1_armhf.deb
        
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
    git clone https://github.com/Re4son/pitftmenu -b 3.5-MSF # Default to 3.5 size screens
    echo '%pi ALL=(ALL:ALL) NOPASSWD: /sbin/poweroff, /sbin/reboot, /sbin/shutdown, /home/pi/pitftmenu/menu' >> /etc/sudoers
    echo "/usr/bin/clear"  >> /home/pi/.profile
    echo 'sudo /home/pi/pitftmenu/menu' >> /home/pi/.profile

    chown -R pi:pi /home/pi

    # Allow "anybody" to access to xserver.  Either console or root
    sed -i 's/allowed_users=console/allowed_users=anybody/' /etc/X11/Xwrapper.config
    sed -i 's/allowed_users=root/allowed_users=anybody/' /etc/X11/Xwrapper.config

    # Add virtual keyboard to login screen
    echo "show-indicators=~language;~a11y;~session;~power" /etc/lightdm/lightdm-gtk-greeter.conf
    echo "keyboard=florence --focus" >> /etc/lightdm/lightdm-gtk-greeter.conf
fi

# Turn off wifi power saving
echo "## Fix WiFi drop out issues ##" >> /etc/rc.local
echo "iwconfig wlan0 power off" >> /etc/rc.local

echo "exit 101" > /usr/sbin/policy-rc.d
chmod 744 /usr/sbin/policy-rc.d

# Wireshark remove warning
mkdir -p /home/pi/.wireshark/
mkdir -p /root/.wireshark/
echo "privs.warn_if_elevated: FALSE" > /home/pi/.wireshark/recent_common
echo "privs.warn_if_elevated: FALSE" > /root/.wireshark/recent_common
mv -f /usr/share/wireshark/init.lua{,.disabled}

############## Extra g0tmi1k apps ###############
apt -y -qq install ipcalc sipcalc psmisc htop gparted hashid webshells php-cli wordlists p0f seclists cowsay shutter

# Git clone webshells
git clone -q -b master https://github.com/sensepost/reGeorg.git /opt/regeorg-git
git clone -q -b master https://github.com/b374k/b374k.git /opt/b374k-git
git clone -q -b master https://github.com/vrana/adminer.git /opt/adminer-git
git clone -q -b master https://github.com/binkybear/rock3tman.git /opt/rock3tman-git

# Generate shells
pushd /opt/b374k-git/ >/dev/null
git pull -q
php index.php -o b374k.php -s
popd >/dev/null

pushd /opt/adminer-git/ >/dev/null
git pull -q
php compile.php 2>/dev/null
popd >/dev/null

# Symlink webshells
ln -sf /opt/reGeorg-git /usr/share/webshells/reGeorg
ln -sf /opt/b374k-git /usr/share/webshells/php/b374k
file=$(find /opt/adminer-git/ -name adminer-*.php -type f -print -quit)
ln -sf "${file}" /usr/share/webshells/php/adminer.php

# Fun MOTD
echo "Moo" | /usr/games/cowsay > /etc/motd

# SSH Allow authorized keys
sed -i 's/^#AuthorizedKeysFile /AuthorizedKeysFile /g' "/etc/ssh/sshd_config"  # Allow for key based login

# Crackmapexec
apt-get install -y libssl-dev libffi-dev python-dev build-essential virtualenvwrapper
#source /usr/share/virtualenvwrapper/virtualenvwrapper.sh
#mkvirtualenv CME
pip install crackmapexec

############################################################
# Add bluetooth packages from Raspberry Pi
# Make bluetooth work again
cd /tmp
wget https://archive.raspberrypi.org/debian/pool/main/b/bluez/bluez_5.23-2+rpi2_armhf.deb
dpkg -i bluez_5.23-2+rpi2_armhf.deb
apt-mark hold bluez

rm -f /usr/sbin/policy-rc.d
rm -f /usr/sbin/invoke-rc.d
dpkg-divert --remove --rename /usr/sbin/invoke-rc.d

rm -f /third-stage
EOF

# Execute Third-Stage
chmod +x kali-$architecture/third-stage
LANG=C chroot kali-$architecture /third-stage

####### END THIRD STAGE - CLEANUP ################

cat << EOF > kali-$architecture/cleanup
#!/bin/bash
rm -rf /root/.bash_history
apt-get update
apt-get clean
rm -f /0
rm -rf /tmp/*.deb /tmp/libfakeioctl /tmp/*.c /tmp/*.sh
rm -f /hs_err*
rm -f cleanup
rm -f /usr/bin/qemu*
EOF

chmod +x kali-$architecture/cleanup
LANG=C chroot kali-$architecture /cleanup

# Raspbian Configs worth adding

cat << EOF > kali-$architecture/etc/wpa_supplicant/wpa_supplicant.conf 
country=GB
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
EOF
chmod 600 kali-$architecture/etc/wpa_supplicant/wpa_supplicant.conf

#cat << EOF > kali-$architecture/etc/systemd/system/dhcpcd.service.d/wait.conf
#[Service]
#ExecStart=
#ExecStart=/sbin/dhcpcd -q -w
#EOF
#chmod 644 kali-$architecture/etc/systemd/system/dhcpcd.service.d/wait.conf

cat << EOF > kali-$architecture/etc/apt/apt.conf.d/50raspi
# never use pdiffs. Current implementation is very slow on low-powered devices
Acquire::PDiffs "0";

# download up to 5 pdiffs:
#Acquire::PDiffs::FileLimit "5";
EOF
chmod 644 kali-$architecture/etc/apt/apt.conf.d/50raspi

cat << EOF > kali-$architecture/etc/modprobe.d/ipv6.conf
# Don't load ipv6 by default
alias net-pf-10 off
#alias ipv6 off
EOF
chmod 644 kali-$architecture/etc/modprobe.d/ipv6.conf

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

echo "*********************************************"
echo "$(tput setaf 2)
   .~~.   .~~.
  '. \ ' ' / .'$(tput setaf 1)
   .~ .~~~..~.
  : .~.'~'.~. :
 ~ (   ) (   ) ~
( : '~'.~.'~' : )
 ~ .~ (   ) ~. ~
  (  : '~' :  ) $(tput sgr0)Kali PI3 Image Generator$(tput setaf 1)
   '~ .~~~. ~'
       '~'
$(tput sgr0)"
echo "*********************************************"
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
# Old way
# git clone --depth 1 https://github.com/nethunteros/re4son-raspberrypi-linux.git -b rpi-4.4.y-re4son ${basedir}/root/usr/src/kernel
# cd ${basedir}/root/usr/src/kernel
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-

# RPI Firmware (copy to /boot)
echo "[+] Copying Raspberry Pi Firmware to /boot"
git clone --depth 1 https://github.com/raspberrypi/firmware.git rpi-firmware
cp -rf rpi-firmware/boot/* ${basedir}/bootp/
rm -rf ${basedir}/root/lib/firmware  # Remove /lib/firmware to copy linux firmware
rm -rf rpi-firmware

# Linux Firmware (copy to /lib)
echo "[+] Copying Linux Firmware to /lib"
cd ${basedir}/root/lib
git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git firmware
rm -rf ${basedir}/root/lib/firmware/.git

# Make nexmon and kernel
echo "*********************************************"
echo "
$(tput setaf 2)
------\
_____  \
     \  \
     |  |
     |  |
     |  |
     |  |
     |  |
  ___|  |_______
 /--------------\
 |              |
 |           .--|
 |  KERNEL   .##|
 |  BAKING   .##|
 |            --|  $(tput sgr0)Time to bake the kernel!$(tput setaf 1)
 |              |
 \______________/
  #            #
  $(tput sgr0)"
echo "*********************************************"
cd $TOPDIR/bcm-rpi3/
source setup_env.sh 
cd $TOPDIR/bcm-rpi3/firmware_patching/nexmon/
make

# Copy nexmon firmware and module to /root
echo "[+] Copying nexmon firmware and module"
cp brcmfmac43430-sdio.bin ${basedir}/root/root/
cp brcmfmac/brcmfmac.ko ${basedir}/root/root/

# Stick with original firmware so wifi works out of the box
cp $TOPDIR/nexmon/brcmfmac43430-sdio.orig.bin ${basedir}/root/lib/firmware/brcm/

echo "[+] Moving to kernel folder and making modules"
cd $TOPDIR/bcm-rpi3/kernel/
make modules_install INSTALL_MOD_PATH=${basedir}/root

echo "[+] Copying kernel"
# ARGH.  Device tree support requires we run this *sigh*
perl scripts/mkknlimg --dtok arch/arm/boot/zImage ${basedir}/bootp/kernel7.img
#cp arch/arm/boot/zImage ${basedir}/bootp/kernel7.img
cp arch/arm/boot/dts/*.dtb ${basedir}/bootp/
cp arch/arm/boot/dts/overlays/*.dtb* ${basedir}/bootp/overlays/
cp arch/arm/boot/dts/overlays/README ${basedir}/bootp/overlays/

echo "[+] Creating and copying modules"
make INSTALL_MOD_PATH=${basedir}/root firmware_install 
make mrproper
cp arch/arm/configs/re4son_pi2_defconfig .config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- re4son_pi2_defconfig
make modules_prepare


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

cat << EOF > $dir/boot/config.txt
# For more options and information see
# http://www.raspberrypi.org/documentation/configuration/config-txt.md
# Some settings may impact device functionality. See link above for details

# uncomment if you get no picture on HDMI for a default "safe" mode
#hdmi_safe=1

# uncomment this if your display has a black border of unused pixels visible
# and your display can output without overscan
#disable_overscan=1

# uncomment the following to adjust overscan. Use positive numbers if console
# goes off screen, and negative if there is too much border
#overscan_left=16
#overscan_right=16
#overscan_top=16
#overscan_bottom=16

# uncomment to force a console size. By default it will be display's size minus
# overscan.
#framebuffer_width=1280
#framebuffer_height=720

# uncomment if hdmi display is not detected and composite is being output
#hdmi_force_hotplug=1

# uncomment to force a specific HDMI mode (this will force VGA)
#hdmi_group=1
#hdmi_mode=1

# uncomment to force a HDMI mode rather than DVI. This can make audio work in
# DMT (computer monitor) modes
#hdmi_drive=2

# uncomment to increase signal to HDMI, if you have interference, blanking, or
# no display
#config_hdmi_boost=4

# uncomment for composite PAL
#sdtv_mode=2

#uncomment to overclock the arm. 700 MHz is the default.
#arm_freq=800

# Uncomment some or all of these to enable the optional hardware interfaces
#dtparam=i2c_arm=on
#dtparam=i2s=on
#dtparam=spi=on

# Uncomment this to enable the lirc-rpi module
#dtoverlay=lirc-rpi

# Additional overlays and parameters are documented /boot/overlays/README

# Enable audio (loads snd_bcm2835)
dtparam=audio=on
EOF

    # Copy firmware for nexmon
    echo "[+] Copying wifi firmware"
    mkdir -p $dir/lib/firmware/brcm/
    #cp -rf $TOPDIR/nexmon/brcmfmac43430-sdio.bin $dir/lib/firmware/brcm/   # This is copied in nexmon build now
    cp -rf $TOPDIR/misc/rpi3/brcmfmac43430-sdio.txt $dir/lib/firmware/brcm/

    echo "[+] Copying bt firmware"
    cp -f $TOPDIR/misc/bt/99-com.rules $dir/etc/udev/rules.d/99-com.rules
    cp -f $TOPDIR/misc/bt/BCM43430A1.hcd $dir/lib/firmware/brcm/BCM43430A1.hcd

    echo "[+] Creating backup wifi firmware in /root"
    cp -f $TOPDIR/nexmon/brcmfmac43430-sdio.orig.bin $dir/root
    #cp -f $TOPDIR/nexmon/brcmfmac43430-sdio.bin $dir/root
    #cp -f $TOPDIR/nexmon/brcmfmac.ko $dir/root
    #cp -f $TOPDIR/misc/rpi3/brcmfmac43430-sdio.txt $dir/root

    echo "[+] Copy Zram"
    cp -f $TOPDIR/misc/rpi3/zram $dir/etc/init.d/zram
    chmod +x $dir/etc/init.d/zram

    echo "[+] Setting up for future TFT build"
    wget https://raw.githubusercontent.com/Re4son/Re4son-Pi-TFT-Setup/rpts-4.4/adafruit-pitft-touch-cal -O $dir/root/adafruit-pitft-touch-cal
    wget https://raw.githubusercontent.com/Re4son/Re4son-Pi-TFT-Setup/rpts-4.4/re4son-pi-tft-setup -O $dir/root/re4son-pi-tft-setup
    chmod +x $dir/root/re4son-pi-tft-setup
    chmod +x $dir/root/adafruit-pitft-touch-cal

    if [ "${BUILD_TFT}" = true ] ; then
        # Set up TFT
        echo "[+] Setting up TFT settings for ${TFT_SIZE}"
        sudo chroot $dir /bin/bash -c "/root/re4son-pi-tft-setup -t ${TFT_SIZE} -u /root"
    fi

    echo "[+] Unmounting"
    sudo umount $dir/boot
    sudo umount -l $dir/proc
    sudo umount -l $dir/dev/
    sudo umount -l $dir/dev/pts
    sudo umount $dir
    rm -rf $dir

    # Generate sha1sum
    cd ${basedir}
    echo "Generating sha1sum for ${OUTPUTFILE}"
    sha1sum ${OUTPUTFILE} > ${OUTPUTFILE}.sha1sum

    # Compress output if true
    if [ "$COMPRESS" = true ] ; then
       echo "Compressing ${OUTPUTFILE}"
       xz -z ${OUTPUTFILE}
       echo "Generating sha1sum for kali-$VERSION-rpi2.img.xz"
       sha1sum ${OUTPUTFILE}.xz > ${OUTPUTFILE}.xz.sha1sum
    fi

    echo "[!] Finished!"
else
    echo "${OUTPUTFILE} NOT FOUND!!! SOMETHING WENT WRONG!?"
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
