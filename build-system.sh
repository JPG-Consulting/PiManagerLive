#!/bin/bash

KERNEL_VERSION=""
LIVE_ARCH="i386"
LIVE_DISTRO="jessie"
WORKING_DIR="/usr/src/live_boot"

# Install applications we need to build the environment.
apt-get --yes install debootstrap syslinux isolinux squashfs-tools genisoimage xorriso memtest86+ rsync

# Use a separate directory for the live environment
if [ ! -d "$WORKING_DIR" ]; then
  mkdir -p $WORKING_DIR 
fi

cd $WORKING_DIR

# Setup the base Debian environment
debootstrap --arch=$LIVE_ARCH --variant=minbase $LIVE_DISTRO chroot http://ftp.us.debian.org/debian/

# A couple of important steps before we chroot
mount -o bind /dev chroot/dev && cp /etc/resolv.conf chroot/etc/resolv.conf

# Chroot to our Debian environment.
chroot $WORKING_DIR/chroot

#Set a few required variables and system settings in our Debian environment
mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C
apt-get update
apt-get install dialog dbus --yes --force-yes
dbus-uuidgen > /var/lib/dbus/machine-id

# Choose your kernel
kernel_pkgs=($(apt-cache search --names-only '^linux-image-' | awk '{print $1}'))

while true; do
  echo "Available kernel images"
  echo "======================="
  echo ""

  index=1
  for i in "${kernel_pkgs[@]}"; do
    echo "$index) $i"
    index=$(( $index + 1 ))
  done

  echo ""
  read -p "Enter selection [1-$(( $index - 1 ))]: " kernel_index

  if [[ $kernel_index =~ ^[0-9]+$ ]]; then
    if [[ $kernel_index > 0 ]]; then
      KERNEL_IMAGE=${kernel_pkgs[$(( kernel_index - 1))]}
      if [ -n "$KERNEL_IMAGE" ]; then
        break
      fi
    fi
  fi
done

# Install basic package
apt-get --no-install-recommends --yes install $KERNEL_IMAGE live-boot

apt-get --no-install-recommends --yes install wget ca-certificates

apt-get --no-install-recommends --yes install dosfstools parted openssh-client

# Development
apt-get --yes install git-core make gcc

# sudo
apt-get --yes install sudo 

# Personal option ;)
apt-get --no-install-recommends --yes install nano

# Add a user
useradd pi
adduser pi sudo
echo -e "raspberry\nraspberry" | (passwd --stdin pi)

# set root password
echo -e "raspberry\nraspberry" | (passwd --stdin root)

# Save kernel version
KERNEL_VERSION=$( uname -r )

# Clean up our Debian environment before leaving. 
rm -f /var/lib/dbus/machine-id
apt-get clean
rm -rf /tmp/*
rm /etc/resolv.conf
umount -lf /proc
umount -lf /sys
umount -lf /dev/pts

exit

# Unmount dev from the chroot
sudo umount -lf $WORKING_DIR/chroot/dev

# Make directories that will be copied to our bootable medium.
mkdir -p $WORKING_DIR/image/{live,isolinux}

# Compress the chroot environment into a Squash filesystem.
mksquashfs $WORKING_DIR/chroot $WORKING_DIR/image/live/filesystem.squashfs -e boot

# Prepare our USB/CD bootloader. 
cp $WORKING_DIR/chroot/boot/vmlinuz-$KERNEL_VERSION $WORKING_DIR/image/live/vmlinuz
cp $WORKING_DIR/chroot/boot/initrd.img-$KERNEL_VERSION $WORKING_DIR/image/live/initrd

echo "UI menu.c32" > $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "prompt 0" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "menu title Debian Live" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "timeout 300" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "label live-debian" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "  menu label ^Debian Live" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "  menu default" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "  kernel /live/vmlinuz" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "  append initrd=/live/initrd boot=live persistence quiet" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "label live-debian-failsafe" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "  menu label ^Debian Live (failsafe)" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "  kernel /live/vmlinuz" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "  append initrd=/live/initrd boot=live persistence config memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash vga=normal" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "" >> $WORKING_DIR/image/isolinux/isolinux.cfg 
echo "endtext" >> $WORKING_DIR/image/isolinux/isolinux.cfg 

cp /usr/lib/ISOLINUX/isolinux.bin $WORKING_DIR/image/isolinux/
cp /usr/lib/syslinux/modules/bios/hdt.c32 $WORKING_DIR/image/isolinux/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 $WORKING_DIR/image/isolinux/
cp /usr/lib/syslinux/modules/bios/libcom32.c32 $WORKING_DIR/image/isolinux/
cp /usr/lib/syslinux/modules/bios/libutil.c32 $WORKING_DIR/image/isolinux/
cp /usr/lib/syslinux/modules/bios/menu.c32 $WORKING_DIR/image/isolinux/

# Build CD
cd $WORKING_DIR/image
genisoimage -rational-rock -volid "Debian Live" -cache-inodes -joliet -full-iso9660-filenames -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -output ../debian-live.iso . && cd ..
# xorriso -as mkisofs -r -J -joliet-long -l -cache-inodes -isohybrid-mbr /usr/lib/syslinux/isohdpfx.bin -partition_offset 16 -A "Debian Live"  -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../debian-live.iso binary

echo ""
echo "Done."
echo ""
