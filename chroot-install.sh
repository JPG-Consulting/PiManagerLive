#!/bin/bash

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
uname -r > /root/kernel_version

# Clean up our Debian environment before leaving. 
rm -f /var/lib/dbus/machine-id
apt-get clean
rm -rf /tmp/*
rm /etc/resolv.conf
umount -lf /proc
umount -lf /sys
umount -lf /dev/pts
