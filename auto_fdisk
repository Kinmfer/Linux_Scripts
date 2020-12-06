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
LOCK=/var/log/spacepack_fdisk.log

tool_info() {
    echo -e "========================================================================================="
    echo -e "                              Auto fdisk tool for SpacePack                              "
    echo -e "          For more information please visit https://github.com/vtrois/spacepack          "
    echo -e "========================================================================================="
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

fdisk_centos() {
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
    if [ "${RELEASE}"=="centos" ];then
        yum -y install e4fsprogs >> ${LOCK} 2>&1
    fi
}

fdisk_mkfs() {
fdisk $1 << EOF
n
p
1
wq
EOF

sleep 3
partprobe
mkfs -t ext4 ${1}1
}

fdisk_mounted() {
while mount | grep "${DISK}" >> ${LOCK} 2>&1;do
    echo -e "\n${RGB_DANGER}This disk has been mounted:${RGB_END}"
    mount | grep "${DISK}"
    echo -en "\n${RGB_DANGER}Force Unloading the disk? [y/n]:${RGB_END}"
    while :; do
    read UMOUNT
    if [[ ! "${UMOUNT}" =~ ^[y,n,Y,N]$ ]]; then
        echo -en "${RGB_DANGER}Please try again [y/n]:${RGB_END}"
    else
        if [ "${UMOUNT}" == 'y' ] || [ "${UMOUNT}" == 'Y' ]; then
            echo -en "${RGB_WAIT}Unloading...${RGB_END}"
            for i in `mount | grep "${DISK}" | awk '{print $3}'`;do
                fuser -km $i >/dev/null
                umount $i >/dev/null
                TEMP=`echo ${DISK} | sed 's;/;\\\/;g'`
                sed -i -e "/^$TEMP/d" /etc/fstab
            done
            echo -e "\r${RGB_SUCCESS}Success, the disk is unloaded!${RGB_END}"
        else
            exit
        fi
        break
    fi
    done
    echo -en "\n${RGB_DANGER}Ready to format the disk? [y/n]:${RGB_END}"
    while :; do
    read CHOICE
    if [[ ! "${CHOICE}" =~ ^[y,n,Y,N]$ ]]; then
        echo -en "${RGB_DANGER}Please try again [y/n]:${RGB_END}"
    else
        if [ "${CHOICE}" == 'y' ] ||  "${CHOICE}" == 'Y' ]; then
            echo -en "${RGB_WAIT}Formatting...${RGB_END}"
            dd if=/dev/zero of=${DISK} bs=512 count=1 &>/dev/null
            sync
            echo -e "\r${RGB_SUCCESS}Success, the disk has been formatted!${RGB_END}"
        else
            exit
        fi
        break
    fi
    done
done
}

fdisk_main() {
    echo -e "\n${RGB_INFO}1/6 : Check and install the Ext4 module${RGB_END}"
    echo -en "${RGB_WAIT}Checking...${RGB_END}"
    fdisk_centos
    echo -e "\r${RGB_SUCCESS}Success, the script is ready to be installed!${RGB_END}\n"
    echo -e "${RGB_INFO}2/6 : Show all active disks${RGB_END}"
    fdisk -l 2>/dev/null | grep -o "Disk /dev/.*vd[b-z]"
    echo -en "\n${RGB_INFO}3/6 : Please choose the disk (e.g., /dev/vdb):${RGB_END}"
    while :; do
    read DISK
    if [ -z "`echo ${DISK} | grep '^/dev/.*vd[b-z]'`" ]; then
        echo -en "${RGB_DANGER}Please try again (e.g., /dev/vdb):${RGB_END}"
    else
        until fdisk -l 2>/dev/null | grep -o "Disk /dev/.*vd[b-z]" | grep "Disk ${DISK}" &>/dev/null;do
            echo -en "${RGB_DANGER}Please try again (e.g., /dev/vdb):${RGB_END}"
            read DISK
        done
        fdisk_mounted
        break
    fi
    done
    echo -e "\n${RGB_INFO}4/6 : Partitioning and formatting the disk${RGB_END}"
    echo -en "${RGB_WAIT}Partitioning and formatting...${RGB_END}"
    fdisk_mkfs ${DISK} >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Success, the disk has been partitioned and formatted!${RGB_END}\n"
    echo -en "${RGB_INFO}5/6 : Please enter a location to mount (Default directory: /data):${RGB_END}"
    while :; do
    read MOUNT
    MOUNT=${MOUNT:-"/data"}
    if [ -z "`echo ${MOUNT} | grep '^/'`" ]; then
        echo -en "${RGB_DANGER}The directory must begin with /, please try again (Default directory: /data):${RGB_END}"
    else
        echo -en "${RGB_WAIT}Mounting...${RGB_END}"
        mkdir ${MOUNT} >> ${LOCK} 2>&1
        mount ${DISK}1 ${MOUNT}
        echo -e "\r${RGB_SUCCESS}Success, the mount is completed!${RGB_END}"
        break
    fi
    done
    echo -e "\n${RGB_INFO}6/6 : Write the configuration to /etc/fstab and mount the device${RGB_END}"
    echo -en "${RGB_WAIT}Writing...${RGB_END}"
    if [ ! -z "${TENCENTCLOUD}" ]; then
    SDISK=$( echo ${DISK} | grep -o "/dev/.*vd[b-z]" | awk -F"/" '{print $(NF)}' )
    SOFTLINK=$( ls -l /dev/disk/by-id | grep "${SDISK}1" | awk -F" " '{print $(NF-2)}' )
    echo /dev/disk/by-id/${SOFTLINK} $MOUNT 'ext4 defaults 0 2' >> /etc/fstab
    else
    echo ${DISK}1 $MOUNT 'ext4 defaults 0 2' >> /etc/fstab
    fi
    echo -e "\r${RGB_SUCCESS}Success, the /etc/fstab has been written!${RGB_END}"
    echo -e "\n${RGB_WARNING}Show the amount of free disk space on the system${RGB_END}"
    df -Th
    echo -e "\n${RGB_WARNING}Show the configuration file for /etc/fstab${RGB_END}"
    cat /etc/fstab
}

clear
tool_info
check_root
check_lock
fdisk_main
