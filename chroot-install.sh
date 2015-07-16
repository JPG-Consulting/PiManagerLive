#!/bin/bash
KERNEL_IMAGE="linux-image-3.16.0-4-586"

#Set a few required variables and system settings in our Debian environment
mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C
apt-get update
apt-get install dialog dbus --yes --force-yes
dbus-uuidgen > /var/lib/dbus/machine-id

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

# Clean up our Debian environment before leaving. 
rm -f /var/lib/dbus/machine-id
apt-get clean
rm -rf /tmp/*
rm /etc/resolv.conf
umount -lf /proc
umount -lf /sys
umount -lf /dev/pts
