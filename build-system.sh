#!/bin/bash

KERNEL_VERSION=""
LIVE_ARCH="i386"
LIVE_DISTRO="jessie"
WORKING_DIR="/usr/src/live_boot"

# Install applications we need to build the environment.
apt-get --yes install debootstrap syslinux isolinux squashfs-tools genisoimage xorriso memtest86+ rsync
apt-get --yes install wget ca-certificates

# Use a separate directory for the live environment
if [ ! -d "$WORKING_DIR" ]; then
  mkdir -p $WORKING_DIR 
fi

cd $WORKING_DIR

# Setup the base Debian environment
debootstrap --arch=$LIVE_ARCH --variant=minbase $LIVE_DISTRO chroot http://ftp.us.debian.org/debian/

# A couple of important steps before we chroot
mount -o bind /dev chroot/dev && cp /etc/resolv.conf chroot/etc/resolv.conf

# Get the setup script
if [ -f $WORKING_DIR/chroot/root/chroot-install.sh ]; then
  rm -rf $WORKING_DIR/chroot/root/chroot-install.sh
fi

wget https://raw.githubusercontent.com/JPG-Consulting/PiManagerLive/development/chroot-install.sh -O $WORKING_DIR/chroot/root/chroot-install.sh
chown root:root $WORKING_DIR/chroot/root/chroot-install.sh
chmod +x $WORKING_DIR/chroot/root/chroot-install.sh

# Chroot to our Debian environment and install
chroot $WORKING_DIR/chroot /bin/bash -x <<'EOF'
/root/chroot-install.sh
# Save kernel version
uname -r > /root/kernel_version
exit
EOF

# Get kernel version
KERNEL_VERSION=$(</root/kernel_version)

# Delete the setup script and kernel version
rm -f $WORKING_DIR/chroot/root/chroot-install.sh
rm -f $WORKING_DIR/chroot/root/kernel_version

# Unmount dev from the chroot
umount -lf $WORKING_DIR/chroot/dev

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
