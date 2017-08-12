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
boldred=${Bold}${Red}
boldgreen=${Bold}${Green}
boldyellow=${Bold}${Yellow}
boldblue=${Bold}${Blue}
boldpurple=${Bold}${Purple}
boldcyan=${Bold}${Cyan}
boldwhite=${Bold}${white}
