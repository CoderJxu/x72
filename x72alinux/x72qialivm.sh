#!/usr/bin/env bash

# to dawnload this script
# curl -L http://bit.ly/2x0Wons >x72alinstall.sh

f_ptc(){
  read -e -sn 1 -p "Press any key to continue..."
}

#----------------------------------------------------------
# Preparation
# confirm you can access the internet
connection_test() {
  # `cmd` 执行命令cmd
  # ip route 显示路由表
  # grep 使用正则表达式搜索文本，并把匹配的行打印出来
  # awk 一种编程语言，用于对文本和数据进行处理
  #   ‘script’ 表示要执行的脚本script
  #   ‘NR’ 表示记录数，在执行过程中对应于当前的行号
  #   {print} 组行逐行扫描文件并重复执行print
  #   $n 表示当前记录的第n个字段
  # ping 用以测试网络的连通性
  #   -q 不显示指令执行过程，开头和结尾的相关信息除外
  #   -c <完成次数> 设置完成要求回应的次数
  #   -w 设置等待应答时间
  # &> file 命令执行后，输出和错误都定向到file中
  ping -q -w 1 -c 1 `ip route | grep default | awk 'NR==1 {print $3}'` &> /dev/null && return 1 || return 0
}

if [[ ! connection_test  ]]; then
  clear
  echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
  read
fi

clear
echo "To make sure system clock is accurate"
timedatectl set-ntp true
timedatectl status
f_ptc

#----------------------------------------------------------
### Partitioning

clear
echo "Start Partitioning!"
# make partitions on the disk.
# MBR partition table
parted /dev/sda mklabel msdos
# /boot - 512m
parted /dev/sda mkpart primary ext3 1MiB 513MiB
parted /dev/sda set 1 boot on
# / (root) - 20g
parted /dev/sda mkpart primary ext3 513MiB 20GiB
# swap - 2g
parted /dev/sda mkpart primary linux-swap 20GiB 22GiB
# /home - the rest
parted /dev/sda mkpart primary ext3 22GiB 100%

echo "Partition Finished!"
f_ptc

clear
echo "Start Formatting"
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

echo "Format Finished!"
f_ptc

clear
echo "Start Mounting the partitions"
# set up /mnt
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir /mnt/home
mount /dev/sda4 /mnt/home

echo "Mount Finished!"
f_ptc

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
