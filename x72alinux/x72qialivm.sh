#!/usr/bin/env bash

# to dawnload this script
# curl -L http://bit.ly/2x0Wons >x72alinstall.sh

f_ptc(){
  sleep 2
  read -e -sn 1 -p "Press any key to continue..."
}

#----------------------------------------------------------
# Preparation

#----------------------------------------------------------
clear
echo "Pre-installation - Verify the boot mode"
if [[ -d "/sys/firmware/efi/" ]]; then
  echo "The system is booted in UEFI mode"
else
  echo "The system is booted in BIOS or CSM mode"
fi
f_ptc

#----------------------------------------------------------
clear
echo "Pre-installation - Connect to the Internet"
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
  echo "Internet seems broken. Press any key to abort."
  read -e -sn 1
  safeExit
else
  echo "Internet is connected."
  f_ptc
fi

#----------------------------------------------------------
clear
echo "Pre-installation - Update the system clock"
timedatectl set-ntp true
timedatectl status
f_ptc

#----------------------------------------------------------
clear
echo "Pre-installation - Partition the disks"
# /(bootloader) - 2m
# /boot - 512m
# swap - 2g
# /(root) - the rest
parted /dev/sda mklabel gpt
parted /dev/sda mkpart primary 1MiB 3MiB
parted /dev/sda set 1 bios_grub on
parted /dev/sda mkpart primary ext3 3MiB 515MiB
parted /dev/sda mkpart primary linux-swap 515MiB 2GiB
parted /dev/sda mkpart primary ext3 2GiB 100%
f_ptc

#----------------------------------------------------------
clear
echo "Pre-installation - Format the partitions"
# make filesystems
# /(bootloader) - 2m
# /boot - 512m
# swap - 2g
# /(root) - the rest
mkfs.vfat /dev/sda1
mkfs.ext4 /dev/sda2
mkswap /dev/sda3
swapon /dev/sda3
mkfs.ext4 /dev/sda4
f_ptc

#----------------------------------------------------------
clear
echo "Pre-installation - Mount the file systems"
# set up /mnt
mount /dev/sda4 /mnt
mkdir -p /mnt/boot
mount /dev/sda2 /mnt/boot

echo "Pre-installation - Result check"
lsblk
f_ptc

#----------------------------------------------------------
### Installation
# rankmirrors to make this faster (though it takes a while)
clear
echo "Installation - Select the mirrors"
# mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
# rankmirrors -n 6 /etc/pacman.d/mirrorlist.orig >/etc/pacman.d/mirrorlist

pacman -S reflector rsync
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector --verbose --country 'Australia' -l 5 --sort rate --save /etc/pacman.d/mirrorlist

pacman -Syy
f_ptc

#----------------------------------------------------------
# install base packages (take a coffee break if you have slow internet)
clear
echo "Installation - Install the base packages"
dirmngr </dev/null
pacman-key --populate archlinux
pacman-key --refresh-keys
pacstrap /mnt base base-devel
f_ptc

#----------------------------------------------------------
### Configure the system
# generate fstab
clear
echo "Configure the system - Fstab"
genfstab -U -p /mnt >>/mnt/etc/fstab
cat /mnt/etc/fstab
f_ptc

# copy ranked mirrorlist over
cp /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d

# chroot
clear
echo "Configure the system - chroot - Time zone"
arch-chroot /mnt /bin/bash <<EOF
# set initial timezone to Australia/Sydney
ln -s /usr/share/zoneinfo/Australia/Sydney /etc/localtime
# adjust the time skew, and set the time standard to UTC
hwclock --systohc --utc
EOF

echo "Configure the system - chroot - Locale"
arch-chroot /mnt /bin/bash <<EOF
# set initial locale
sed -i '/en_US/{s/#//}' /etc/locale.gen
sed -i '/zh_CN/{s/#//}' /etc/locale.gen
sed -i '/zh_TW/{s/#//}' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
EOF

echo "Configure the system - chroot - Hostname"
arch-chroot /mnt /bin/bash <<EOF
# Network configuration
# set initial hostname
echo "x72al-$(date +"%Y%W")" >/etc/hostname
echo "127.0.1.1\tx72al-$(date +"%Y%W").localdomain\tx72al-$(date +"%Y%W")" >> /etc/hosts
EOF

echo "Configure the system - chroot - Network configuration"
arch-chroot /mnt /bin/bash <<EOF
pacman -S networkmanager iw wpa_supplicant dialog
systemctl enable NetworkManager.service
EOF

echo "Configure the system - chroot - Initramfs"
arch-chroot /mnt /bin/bash <<EOF
# no modifications to mkinitcpio.conf should be needed
mkinitcpio -p linux
EOF

echo "Configure the system - chroot - Root password"
arch-chroot /mnt /bin/bash <<EOF
# set root password to "root"
echo root:root | chpasswd
EOF

echo "Configure the system - chroot - intel-ucode"
if [[ $(less /proc/cpuinfo | grep GenuineIntel | awk '{print $3}') = "GenuineIntel" ]]; then
arch-chroot /mnt /bin/bash <<EOF
pacman -S intel-ucode
EOF
fi

echo "Configure the system - chroot - Boot loader"
arch-chroot /mnt /bin/bash <<EOF
pacman -S grub os-prober
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
EOF

echo "Configure the system - chroot - packages installation"
arch-chroot /mnt /bin/bash <<EOF
pacman -S screen screenfetch wpa_actiond ifplugd sudo zsh
EOF

# end section sent to chroot

# unmount
umount -R /mnt

echo "Done! Unmount the CD image from the VM, then type 'reboot'."
