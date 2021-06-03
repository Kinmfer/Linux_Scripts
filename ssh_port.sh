#!/usr/bin/env bash
#
# Author:       Seaton Jiang <seaton@vtrois.com>
# Github URL:   https://github.com/vtrois/spacepack
# License:      MIT
# Date:         2020-08-13

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

RGB_DANGER='\033[31;1m'
RGB_WAIT='\033[37;2m'
RGB_SUCCESS='\033[32m'
RGB_WARNING='\033[33;1m'
RGB_INFO='\033[36;1m'
RGB_END='\033[0m'

TENCENTCLOUD=$( wget -qO- -t1 -T2 metadata.tencentyun.com )
ALICLOUD=$( wget -qO- -t1 -T2 100.100.100.200 )

LOCK=/var/log/spacepack_port.log

tool_info() {
    echo -e "========================================================================================="
    echo -e "                           Revise SSH port tool for SpacePack                            "
    echo -e "          For more information please visit https://github.com/vtrois/spacepack          "
    echo -e "========================================================================================="
}

show_help() {
    version
    echo -e "\nUsage: $0 [OPTION]"
    echo -e "\nOption:"
    echo -e "  -p,  --port             revise the SSH port."
    echo -e "  -v,  --version          show the version info."
    echo -e "  -h,  --help             print this help."
    echo -e "\nMail bug reports and suggestions to <support@vtrois.com>."
}

version() {
  echo "Revise SSH port tool version 1.3"
}

check_root(){
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RGB_DANGER}This script must be run as root!${RGB_END}"
       exit 1
    fi
}

check_lock() {
    if [ ! -f "$LOCK" ];then
    touch $LOCK
    fi
}

check_os() {
    if [ -f /etc/redhat-release ]; then
        RELEASE="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        RELEASE="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        RELEASE="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        RELEASE="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        RELEASE="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        RELEASE="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        RELEASE="centos"
    else
        RELEASE="unknown"
    fi
    if [ "${RELEASE}" != "centos" ];then
        /etc/init.d/ssh restart >> ${LOCK} 2>&1
    else
        CENTOSVERSION=$( rpm -q centos-release | cut -d- -f3 )
        if [ "${CENTOSVERSION}" == "7" ];then
            systemctl restart sshd >> ${LOCK} 2>&1
        else
            service sshd restart >> ${LOCK} 2>&1
        fi
    fi
}

ssh_port() {
    local PORT=$( cat /etc/ssh/sshd_config | grep ^Port | awk '{print $2}' )
    [ ! -z ${PORT} ] && echo ${PORT} || echo 22
}

change_port() {
    if [ -e "/etc/ssh/sshd_config" ]; then
        SSHPORT=$( ssh_port )
        echo -en "\n${RGB_INFO}1/2 : Please enter SSH port (Range of 1024 to 65535, current is ${SSHPORT}):${RGB_END}"
        while :; do
        read NPORT
        NPTSTATUS=$( netstat -lnp|grep ${NPORT} )
        if [ -n "${NPTSTATUS}" ];then
            echo -en "${RGB_DANGER}The port is already occupied, Please try again (Range of 1024 to 65535):${RGB_END}"
        elif [ "${NPORT}" -lt 1024 ] || [ "${NPORT}" -gt 65535 ];then
            echo -en "${RGB_DANGER}Please try again (Range of 1024 to 65535):${RGB_END}"
        else
            break
        fi
        done
        echo -en "${RGB_WAIT}Checking...${RGB_END}"
        if [ "${SSHPORT}" -ne "22" ]; then
            sed -i "s@^Port.*@Port ${NPORT}@" /etc/ssh/sshd_config
        else
            sed -i "s@^#Port.*@&\nPort ${NPORT}@" /etc/ssh/sshd_config
        fi
        echo -e "\r${RGB_SUCCESS}Success, the SSH port modification completed!${RGB_END}\n"
        echo -e "${RGB_INFO}2/2 : Restart the service to take effect${RGB_END}"
        echo -en "${RGB_WAIT}Checking...${RGB_END}"
        check_os
        echo -e "\r${RGB_SUCCESS}Success, the SSH service restart completed!${RGB_END}\n"
        echo -e "${RGB_WARNING}Please enable [TCP:${NPORT}] for firewalld/iptables manually set if necessary!${RGB_END}\n"
        if [ ! -z "${TENCENTCLOUD}" ]; then
        echo -e "${RGB_WARNING}Detects that you are using Tencent Cloud, please enable [TCP:${NPORT}] in the security group!${RGB_END}\n"
        echo -e "${RGB_WARNING}Tencent Cloud Console URL:${RGB_END} https://console.cloud.tencent.com/cvm/securitygroup\n"
        elif [ ! -z "${ALICLOUD}" ]; then
        echo -e "${RGB_WARNING}Detects that you are using AliCloud, please enable [TCP:${NPORT}] in the security group!${RGB_END}\n"
        echo -e "${RGB_WARNING}AliCloud Console URL:${RGB_END} https://ecs.console.aliyun.com/#/securityGroup/region/\n"
        else
        echo -e "${RGB_WARNING}If you use elastic compute service, please enable [TCP:${NPORT}] for the security group!${RGB_END}"
        fi
    else
        echo -e "${RGB_DANGER}Can't find sshd config file!${RGB_END}"
        exit 1
    fi
}

port_main() {
    clear
    tool_info
    check_root
    check_lock
    change_port
}

ACTION=$1
[ -z $1 ] && ACTION=port
case ${ACTION} in
    port)
        port_main
        ;;
    -p|--port)
        port_main
        ;;
    -v|--version)
        version
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo -e "Unknown option: $1"
        echo -e "\nUsage: [-p,--port] [-v,--version] [-h,--help]"
        exit
        ;;
esac
