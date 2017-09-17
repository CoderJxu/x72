#!/usr/bin/env bash

# to dawnload this script
# curl -L http://bit.ly/2x0Wons >x72alinstall.sh

# ------------------------------------------------------------------------------
# safeExit
# -----------------------------------
# Non destructive exit for when script exits naturally.
# Usage: Add this function at the end of every script.
# -----------------------------------
function safeExit() {
  trap - INT TERM EXIT
  exit
}

f_ptc(){
  read -e -sn 1 -p "Press any key to continue..."
}

#----------------------------------------------------------
# Preparation

#----------------------------------------------------------

PreInsBM(){
  echo "Pre-installation - Verify the boot mode"
  if [[ -d "/sys/firmware/efi/" ]]; then
    echo "The system is booted in UEFI mode"
  else
    echo "The system is booted in BIOS or CSM mode"
  fi
}

#----------------------------------------------------------

PreInsInt(){
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
  fi
}

PreInsRootChk(){
  if [[ "`whoami`" = "root" ]]; then
    echo "The current user is root."
  else
    echo "The current user is not root. Please login as root and try again."
    read -e -sn 1
    safeExit
  fi
}

#----------------------------------------------------------

PreInsClk(){
  echo "Pre-installation - Update the system clock"
  timedatectl set-ntp true
  timedatectl status
}


#----------------------------------------------------------

PreInsBiosGptGrub(){
  #----------------------------------------------------------
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
  sleep 1

  #----------------------------------------------------------
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
  sleep 1

  #----------------------------------------------------------
  echo "Pre-installation - Mount the file systems"
  # set up /mnt
  mount /dev/sda4 /mnt
  mkdir -p /mnt/boot
  mount /dev/sda2 /mnt/boot

  f_ptc
}

PreInsDiskChk(){
  echo "Pre-installation - Result check"
  lsblk
  f_ptc
}

#----------------------------------------------------------
### Installation
# rankmirrors to make this faster (though it takes a while)
InsMirrorList(){
  echo "Installation - Select the mirrors"
  pacman -Syy

  # mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
  # rankmirrors -n 6 /etc/pacman.d/mirrorlist.orig >/etc/pacman.d/mirrorlist

  pacman -S --noconfirm reflector rsync
  mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
  reflector --verbose --country 'Australia' -l 5 --sort rate --save /etc/pacman.d/mirrorlist

}

#----------------------------------------------------------
# install base packages (take a coffee break if you have slow internet)
InsBase(){
  echo "Installation - Install the base packages"
  dirmngr </dev/null
  pacman-key --populate archlinux
  pacman-key --refresh-keys
  pacstrap /mnt base base-devel
}

#----------------------------------------------------------
### Configure the system
# generate fstab
CfgFstab(){
  echo "Configure the system - Fstab"
  genfstab -U -p /mnt >>/mnt/etc/fstab
  cat /mnt/etc/fstab
}


CfgMirrorList(){
  echo "Configure - Select the mirrors"

arch-chroot /mnt /bin/bash <<EOF
pacman -Syy
pacman -S --noconfirm reflector rsync
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector --verbose --country 'Australia' -l 5 --sort rate --save /etc/pacman.d/mirrorlist
EOF

}


CfgTimeZ(){
  echo "Configure the system - chroot - Time zone"

arch-chroot /mnt /bin/bash <<EOF
# set initial timezone to Australia/Sydney
ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
# adjust the time skew, and set the time standard to UTC
hwclock --systohc --utc
EOF

}

CfgLocale(){
  echo "Configure the system - chroot - Locale"

arch-chroot /mnt /bin/bash <<EOF
# set initial locale
sed -i '/en_US/{s/#//}' /etc/locale.gen
sed -i '/zh_CN/{s/#//}' /etc/locale.gen
sed -i '/zh_TW/{s/#//}' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
EOF

}

CfgHost(){
  echo "Configure the system - chroot - Hostname"

arch-chroot /mnt /bin/bash <<EOF
# Network configuration
# set initial hostname
echo "x72al-$(date +"%Y%W")" >/etc/hostname
echo "127.0.1.1\tx72al-$(date +"%Y%W").localdomain\tx72al-$(date +"%Y%W")" >> /etc/hosts
EOF

}

CfgNetwork(){
  echo "Configure the system - chroot - Network configuration"

arch-chroot /mnt /bin/bash <<EOF
pacman -S --noconfirm networkmanager iw wpa_supplicant dialog
systemctl enable NetworkManager.service
EOF

}

CfgInitramfs(){
  echo "Configure the system - chroot - Initramfs"

arch-chroot /mnt /bin/bash <<EOF
# no modifications to mkinitcpio.conf should be needed
mkinitcpio -p linux
EOF

}

CfgRootPw(){
  echo "Configure the system - chroot - Root password"

arch-chroot /mnt /bin/bash <<EOF
# set root password to "root"
echo root:root | chpasswd
EOF

}

CfgIntelCPU(){
  echo "Configure the system - chroot - intel-ucode"

  if [[ $(less /proc/cpuinfo | grep GenuineIntel | awk '{print $3}') == "GenuineIntel" ]]; then

arch-chroot /mnt /bin/bash <<EOF
pacman -S --noconfirm intel-ucode
EOF

  fi
}

CfgBootLoader(){
  echo "Configure the system - chroot - Boot loader"

arch-chroot /mnt /bin/bash <<EOF
pacman -S --noconfirm grub os-prober
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
EOF

}

CfgPkgIns(){
  echo "Configure the system - chroot - packages installation"

arch-chroot /mnt /bin/bash <<EOF
pacman -S --noconfirm screen screenfetch wpa_actiond ifplugd sudo zsh
EOF

}
# end section sent to chroot

# unmount
UnmountAll(){
  umount -R /mnt
  echo "Done! Unmount the CD image from the VM, then type 'reboot'."
}

function mainScript() {
############## Begin Script Here ###################
####################################################

PreInsBM
PreInsInt
PreInsRootChk
PreInsClk

echo -ne "Whether to partition the disk and format? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  PreInsBiosGptGrub
fi

PreInsDiskChk

echo -ne "Whether to rank the mirror list of live system? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  InsMirrorList
fi

echo -ne "Whether to install the packages of system base? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  InsBase
fi

echo -ne "Whether to configure the fstab? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgFstab
fi

echo -ne "Whether to rank the mirror list of the new system? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgMirrorList
fi

echo -ne "Whether to configure the time zone? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgTimeZ
fi

echo -ne "Whether to configure the locale? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgLocale
fi

echo -ne "Whether to configure the host? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgHost
fi

echo -ne "Whether to configure the network? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgNetwork
fi

echo -ne "Whether to configure the Initramfs? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgInitramfs
fi

echo -ne "Whether to configure the root password? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgRootPw
fi

echo -ne "Whether to configure the intel-ucode? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgIntelCPU
fi

echo -ne "Whether to configure the boot loader? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgBootLoader
fi

echo -ne "Whether to install common packages? \nY(default)/N"
read -e -sn 1 key
if [[ $key != "N" || $key != "n" ]]; then
  CfgPkgIns
fi

echo "Unmount all directories in /mnt"
UnmountAll

echo -n
####################################################
############### End Script Here ####################
}

# ##################################################
# Run your script
mainScript

# Exit cleanlyd
safeExit
