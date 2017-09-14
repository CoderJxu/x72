#!/usr/bin/env bash

# ##################################################
# 作者  : Jianrui Xu @ https://github.com/CoderJxu
# 许可声明：可以任意使用，如有任何风险，使用者自己承担

# ##################################################
# 版本号
# n.0.0 重大改进版， 1.n.0 稳定版， 1.0.n 测试版
# <major>.<minor>.<patch>
version="1.0.0"               # Sets version variable

# ##################################################

# 脚本路径
# ${var} 引用变量
# $(cmd) 执行命令
scriptPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 引用其他脚本
# utilsLocation="${scriptPath}/lib/utils.sh" # Update this path to find the utilities.
#
# if [ -f "${utilsLocation}" ]; then
#   source "${utilsLocation}"
# else
#   echo "请找到 utils.sh，并修改当前脚本以便能正确引用，正在退出当前脚本......"
#   exit 1
# fi
#

# ##################################################
txttitle="Arch Linux Install Script"
txtpresstocontinue="Press any key to continue, or press Ctrl+C to exit......"
txtinvalidoption="输入错误，请重新输入"

txtinfochkroot="Check user's authority......"
txtrootinfo="User root login."
txtrootwarning="Please login as root and try again."

txtinfochkconnection="Check network connection......"
txtconnectionwarning="Please connect to internet and try again."
txtconnectioninfo="Internet is connected"

txtinfochkbootmode="Check boot mode......"
txtuefi="UEFI"
txtbios="BIOS"

txtinfoupdatetime="Update system date and time."
txtinfosetupsys="Update system setting."

# ##################################################
countries_code=("AU" "CN")
countries_name=("Australia" "China")

# ##################################################
# tput 终端处理工具
# 获取终端的行数和列数
tCols=$(tput cols)
tLines=$(tput lines)
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

# 常用颜色
black=$(tput setaf 0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
purple=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
# 加粗
boldred=${bold}${Red}
boldgreen=${bold}${Green}
boldyellow=${bold}${Yellow}
boldblue=${bold}${Blue}
boldpurple=${bold}${Purple}
boldcyan=${bold}${Cyan}
boldwhite=${bold}${white}

# ##################################################
# 信息提示
print_line(){
  # printf 格式化并输出结果到标准输出
  # tr 可以对来自标准输入的字符进行替换、压缩和删除
  # 输出终端列数的空格并换行，将 ' ' 转换 '-'
  printf "%${tCols}s\n" | tr ' ' '-'
}

print_title(){
  # clear 用于清除当前屏幕终端上的任何信息
  # clear
  print_line
  # echo -e：激活转义字符
  echo -e "# ${bold} $1 ${reset}"
  print_line
  # echo ""
}

print_info(){
  # echo -e 激活转义字符
  # fold -s 以空格字符作为换列点; -w 设置每列的最大行数
  # sed s 用一个字符串替换另一个字符串; /^/ 匹配所有行
  # $(( exp )) 扩展计算,整数型的计算，不支持浮点型.若是逻辑判断，表达式exp为真则为1,假则为0
  echo -e "#${bold} $1 ${reset}" | fold -sw $(( $tCols - 1 )) | sed 's/^#/[xarchci-info]/'
  sleep 0.1
}

print_warning(){
  # echo -e 激活转义字符
  # fold -s 以空格字符作为换列点; -w 设置每列的最大行数
  # sed s 用一个字符串替换另一个字符串; /^/ 匹配所有行
  # $(( exp )) 扩展计算,整数型的计算，不支持浮点型.若是逻辑判断，表达式exp为真则为1,假则为0
  echo -e "#${boldyellow} $1 ${reset}" | fold -sw $(( $tCols - 1 )) | sed 's/^#/[xarchci-warning]/'
}

print_danger(){
  # echo -e 激活转义字符
  # fold -s 以空格字符作为换列点; -w 设置每列的最大行数
  # sed s 用一个字符串替换另一个字符串; /^/ 匹配所有行
  # $(( exp )) 扩展计算,整数型的计算，不支持浮点型.若是逻辑判断，表达式exp为真则为1,假则为0
  echo -e "#${boldred} $1 ${reset}" | fold -sw $(( $tCols - 1 )) | sed 's/^#/[xarchci-danger]/'
}

# ------------------------------------------------------------------------------

presstocontinue(){
  print_line
  # -p 指定读取值时的提示符
  # -s 关闭回显
  # -n 计数输入的字符，当输入的字符数目达到预定数目时，自动退出，并将输入的数据赋值给变量
  # -e 在交互式shell命令行中启用编辑器
  read -e -sn 1 -p "${txtpresstocontinue}"
}

invalid_option(){
  print_line
  echo $txtinvalidoption
  # presstocontinue
}

read_input_text() {
  read -p "$1 [y/N]: " OPTION
  echo ""
  # tr [:upper:]：大写字母；[:lower:]；小写字母
  OPTION=`echo "$OPTION" | tr '[:upper:]' '[:lower:]'`
}

contains_element() {
  # "${@:2}" 第二个参数列表的字符串
  # 检查 第一个参数 是否 在第二个参数列表中
  # [[ exp ]] 条件表达式，做逻辑判断
  for e in "${@:2}"; do [[ $e == $1 ]] && break; done;
}
# ------------------------------------------------------------------------------
# 设置语言
txtsetlang="设置语言"

set_lang(){
  print_info $txtsetlang

  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
  echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
  locale-gen >/dev/null 2>&1
  export LANG="en_US.UTF-8"
}

# 验证权限
chk_root(){
  print_info $txtinfochkroot
  # `cmd` 执行命令cmd
  if [[ "`whoami`" = "root" ]]; then
    print_info $txtrootinfo
  else
    print_warning $txtrootwarning
    sleep 2
    exit 1
  fi
}

# 验证网络连接
chk_connetion(){
  print_info $txtinfochkconnection
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

  # ip link 显示网络设备的运行状态
  # sed '1!d' 保留第1行，其他行删除
  WIRED_DEV=`ip link | grep "ens\|eno\|enp" | awk '{print $2}'| sed 's/://' | sed '1!d'`
  WIRELESS_DEV=`ip link | grep wlp | awk '{print $2}'| sed 's/://' | sed '1!d'`

  if connection_test; then
    print_warning $txtconnectionwarning
    sleep 2
    exit 1
  else
    print_info $txtconnectioninfo
  fi

}

# 验证启动模式
chk_bootmode(){
  print_info $txtinfochkbootmode
  # [] 判断表达式，返回逻辑值
  # -d dir 文件比较运算符，如果 dir 为目录，则为真
  if [[ -d "/sys/firmware/efi/" ]]; then
    bootflag=$txtuefi
  else
    bootflag=$txtbios
  fi
  print_info "当前系统的启动模式为 ${bootflag}"
}

upd_time(){
  print_info $txtinfoupdatetime
  # 更新系统时间
  timedatectl set-ntp true
}

# 系统设置
setup_sys(){
  print_info $txtinfosetupsys
  #
  # 中文本地化
  # set_lang
  #
}

country_list(){
  PS3="输入选项："
  echo "选择国家地域："

  select country_name in "${countries_name[@]}"; do
    if contains_element "$country_name" "${countries_name[@]}"; then
      country_code=${countries_code[$(( $REPLY - 1 ))]}
      break
    else
      invalid_option
    fi
  done
}

#
cfg_mirrorlist(){
  print_title "MIRRORLIST - https://wiki.archlinux.org/index.php/Mirrors"
  print_info "选择镜像"

  OPTION=n
  while [[ $OPTION != y ]]; do
    country_list
    read_input_text "Confirm country: $country_name"
  done

  url="https://www.archlinux.org/mirrorlist/?country=${country_code}&use_mirror_status=on"
  tmpfile=$(mktemp --suffix=-mirrorlist)

  # Get latest mirror list and save to tmpfile
  curl -so ${tmpfile} ${url}
  sed -i 's/^#Server/Server/g' ${tmpfile}

  # Backup and replace current mirrorlist file (if new file is non-zero)
  if [[ -s ${tmpfile} ]]; then
   { echo " Backing up the original mirrorlist..."
     mv -i /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig; } &&
   { echo " Rotating the new list into place..."
     mv -i ${tmpfile} /etc/pacman.d/mirrorlist; }
  else
    echo " Unable to update, could not download list."
  fi
  # better repo should go first
  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.tmp
  rankmirrors /etc/pacman.d/mirrorlist.tmp > /etc/pacman.d/mirrorlist
  rm /etc/pacman.d/mirrorlist.tmp
  # allow global read access (required for non-root yaourt execution)
  chmod +r /etc/pacman.d/mirrorlist
  vim /etc/pacman.d/mirrorlist
}

cfg_partition(){
  device=$(lsblk -d -p -n -l -o NAME -e 7,11)

  # 引导方式有
  #   BIOS+MBR 最传统的，系统都会支持；唯一的缺点就是不支持容量大于2T的硬盘
  #   BIOS+GPT 2TB 容量以上；64位系统
  #   UEFI+MBR 需要把UEFI设置成Legacy模式（传统模式）让其支持传统MBR启动；效果同BIOS+MBR
  #   UEFI+GPT 2TB 容量以上；64位系统
  #

  # BIOS 基本输入输出系统 功能由两部分组成 POST和Runtime服务 POST阶段完成后它将从存储器中
  # 被清除，而Runtime服务会被一直保留，用于目标操作系统的启动
  #   1. 上电自检POST(Power-on self test)，主要负责检测系统外围关键设备（如：CPU、内存、
  #   显卡、I/O、键盘鼠标等）是否正常。例如，最常见的是内存松动的情况，BIOS自检阶段会报错，
  #   系统就无法启动起来
  #   2. 步骤1成功后，便会执行一段小程序用来枚举本地设备并对其初始化。这一步主要是根据我们在
  #   BIOS中设置的系统启动顺序来搜索用于启动系统的驱动器，如硬盘、光盘、U盘、软盘和网络等。我
  #   们以硬盘启动为例，BIOS此时去读取硬盘驱动器的第一个扇区(MBR，512字节)，然后执行里面的
  #   代码。实际上这里BIOS并不关心启动设备第一个扇区中是什么内容，它只是负责读取该扇区内容、
  #   并执行。
  # 至此，BIOS的任务就完成了，此后将系统启动的控制权移交到MBR部分的代码。
  #

  # 单系统
  parted $device mklabel gpt


  # BIOS+GPT
  if [[ bootflag == "BIOS" ]]
  then
      # BIOS 启动分区 (BIOS boot partition) 是在数据存储设备上的一个分区，它是被
      #   GNU GRUB 用于在传统BIOS主板的个人电脑上启动操作系统，而被启动的存储设备则需要包含
      #   一个 GPT 分区表。所以这种分区布局设计又被称为 BIOS/GPT 启动
      # 第一个分区 设置 bios_grub 代码 EF02
      parted $device mkpart primary 1MiB 2MiB

  else # UEFI+GPT
      # 创建一个新的 ESP 分区
      parted $device mkpart ESP fat32 1MiB 513MiB
      parted $device set 1 boot on
      parted $device mkpart primary ext3 513MiB 20.5GiB
      parted $device mkpart primary linux-swap 20.5GiB 24.5GiB
      parted $device mkpart primary ext3 24.5GiB 100%
  fi

  # 双系统
  # 多系统

  echo "${txtautopartcreate//%1/BIOS boot}"
  sgdisk $device -n=1:0:+31M -t=1:ef02
  echo "${txtautopartcreate//%1/boot}"
  sgdisk $device -n=2:0:+512M
  echo "${txtautopartcreate//%1/swap}"
  swapsize=$(cat /proc/meminfo | grep MemTotal | awk '{ print $2 }')
  swapsize=$(($swapsize/1000))"M"
  sgdisk $device -n=3:0:+$swapsize -t=3:8200
  echo "${txtautopartcreate//%1/root}"
  sgdisk $device -n=4:0:0
  echo ""
  pressanykey
  bootdev=$device"2"
  swapdev=$device"3"
  rootdev=$device"4"
  efimode="0"
}

set_rootpw() {

}

ins_utls() {
  # intel-ucode是intel的微码工具
  pacman -S intel-ucode

  pacman -S zsh
  sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
}
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

function mainScript() {
############## Begin Script Here ###################
####################################################

print_title "${txttitle}"
presstocontinue

# set_lang
# chk_root
chk_connetion
chk_bootmode
upd_time

print_info "更新系统......"
pacman -Sy

# set_keymap
# set_editor
# set_sys
cfg_mirrorlist
cfg_partition
ins_system
cfg_fstab
cfg_hostname
cfg_timezone
cfg_hwclock
cfg_locale
# cfg_mkinitcpio
# ins_bootloader
# set_rootpw
# ins_utls

echo -n

####################################################
############### End Script Here ####################
}

# ##################################################
# Run your script
mainScript

# Exit cleanlyd
safeExit
