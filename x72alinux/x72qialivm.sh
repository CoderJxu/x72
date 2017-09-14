#!/usr/bin/env bash

#----------------------------------------------------------
# Preparation
# confirm you can access the internet
if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
  echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
  read
fi

timedatectl set-ntp true

#----------------------------------------------------------
### Partitioning

# make partitions on the disk.
# MBR partition table
parted -s /dev/sda mktable msdos
# /boot - 512m
parted -s /dev/sda mkpart primary 0% 512m
# / (root) - 20g
parted -s /dev/sda mkpart primary 512m 20992m
# swap - 2g
parted -s /dev/sda mkpart primary linux-swap 20992m 22016m
# /home - the rest
parted -s /dev/sda mkpart primary 22016m 100%

# make filesystems
# /boot
mkfs.fat -F32 /dev/sda1
# /
mkfs.ext4 /dev/sda2
# swap
mkswap /dev/sda3
swapon /dev/sda3
# /home
mkfs.ext4 /dev/sda4

# set up /mnt
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir /mnt/home
mount /dev/sda4 /mnt/home

#----------------------------------------------------------
# rankmirrors to make this faster (though it takes a while)
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
rankmirrors -n 6 /etc/pacman.d/mirrorlist.orig >/etc/pacman.d/mirrorlist
pacman -Syy

#----------------------------------------------------------
### Installation
# install base packages (take a coffee break if you have slow internet)
pacstrap /mnt base base-devel

# generate fstab
genfstab -U -p /mnt >>/mnt/etc/fstab

# copy ranked mirrorlist over
cp /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d

# chroot
arch-chroot /mnt /bin/bash <<EOF
# set initial timezone to Australia/Sydney
ln -s /usr/share/zoneinfo/Australia/Sydney /etc/localtime
# adjust the time skew, and set the time standard to UTC
hwclock --systohc --utc

# set initial locale
sed -i '/en_US.UTF-8/{s/#//}' /etc/locale.gen
sed -i '/zh_CN.GB18030/{s/#//}' /etc/locale.gen
sed -i '/zh_CN.GB2312/{s/#//}' /etc/locale.gen
sed -i '/zh_CN.GBK/{s/#//}' /etc/locale.gen
sed -i '/zh_CN.UTF-8/{s/#//}' /etc/locale.gen
sed -i '/zh_TW.UTF-8/{s/#//}' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

# Network configuration
# set initial hostname
echo "x72al-$(date +"%Y%W")" >/etc/hostname
echo "127.0.1.1\tx72al-$(date +"%Y%W").localdomain\tx72al-$(date +"%Y%W")" >> /etc/hosts

pacman -S networkmanager iw wpa_supplicant dialog
systemctl enable NetworkManager.service

# no modifications to mkinitcpio.conf should be needed
mkinitcpio -p linux

pacman -S intel-ucode

pacman -S grub os-prober
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# set root password to "root"
echo root:root | chpasswd

# end section sent to chroot
EOF

# unmount
umount /mnt/{boot,}

echo "Done! Unmount the CD image from the VM, then type 'reboot'."
