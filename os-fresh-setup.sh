#!/bin/bash
set -e
#================================================
# This is a OS fresh setup script
# firstly, run command: git clone https://github.com/docker-docker/git-webhook.git
#
#================================================
HOST_NAME="st-manager"
CURRENT_FOLDER=$(pwd)
CODE_WORKSPACE="/opt/workspace"
#================================================
apt-get install sudo -y
usermod -aG sudo root
# 1. setup the host /etc/hostname , etc/hosts
hostnamectl set-hostname "${HOST_NAME}"
echo "HostName changed to: ${HOST_NAME}"
echo "127.0.0.1 ${HOST_NAME}" >>/etc/hosts
# 1.1 host name
TIMEZONE="Asia/Shanghai"
ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime && echo $TIMEZONE >/etc/timezone
echo "TimeZone changed to ${TIMEZONE}"
#================================================
# 1.2 For China User, customize sources for apt-get: https://cloud.tencent.com/developer/article/1590080
#echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free" >/etc/apt/sources.list &&
#  echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free" >>/etc/apt/sources.list &&
#  echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free" >>/etc/apt/sources.list &&
#  echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian-security/ buster/updates main contrib non-free" >>/etc/apt/sources.list &&
#  echo "deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free" >>/etc/apt/sources.list &&
#  echo "deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free" >>/etc/apt/sources.list &&
#  echo "deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free" >>/etc/apt/sources.list &&
#  echo "deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security/ buster/updates main contrib non-free" >>/etc/apt/sources.list

apt-get update &&
  apt-get -y install ca-certificates curl wget gnupg dirmngr xz-utils libatomic1 --no-install-recommends apt-utils locales git unzip screen certbot
rm -rf /var/lib/apt/lists/*
echo "Update the apt package mirror completed!"
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen en_US.UTF-8
# 1.3 /etc/sysctl.conf
echo "fs.file-max = 2147483584" >>/etc/sysctl.conf
echo "* soft nofile 60000" >>/etc/security/limits.conf
echo "* soft noproc 60000" >>/etc/security/limits.conf
echo "* hard nofile 60000" >>/etc/security/limits.conf
echo "* hard noproc 60000" >>/etc/security/limits.conf
echo "root soft nofile 60000" >>/etc/security/limits.conf
echo "root hard nofile 60000" >>/etc/security/limits.conf
echo "session required pam_limits.so" >>/etc/pam.d/common-session
# after above command, run `ulimit -n` and `ulimit -Hn` to see the changes
echo "Updated the file-max limits value"
sudo chmod +x software/*
source "${CURRENT_FOLDER}/software/maven.sh"
source "${CURRENT_FOLDER}/software/node.sh"
source "${CURRENT_FOLDER}/software/nginx.sh"
source "${CURRENT_FOLDER}/software/docker.sh"
source "${CURRENT_FOLDER}/software/webhooks.sh"
#================================================
# 3. sshd configuration
# SSH_PORT="28379"
# SSH_PASS="changeit"
# ssh-keygen -t rsa -b 4096 -C "alterhu2020@gmail.com" -N "$SSH_PASS" -f ~/.ssh/id_rsa
# cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
# chown -R root:root ~/.ssh
# chmod -R 700 ~/.ssh
# chmod -R 600 ~/.ssh/authorized_keys
# add the key into github page: https://github.com/settings/keys
# "Key is invalid. You must supply a key in OpenSSH public key format" if this error please use cat to copied into console
# cat ~/.ssh/id_rsa.pub

# sed -i -r 's/(Port*)/#\1/g' /etc/ssh/sshd_config
# sed -i -r "/^#Port.*/a Port ${SSH_PORT}" /etc/ssh/sshd_config
# echo "RSAAuthentication yes" >>/etc/ssh/sshd_config
# echo "PubkeyAuthentication yes" >>/etc/ssh/sshd_config
# echo "AuthorizedKeysFile .ssh/authorized_keys" >>/etc/ssh/sshd_config
# echo "PasswordAuthentication yes" >>/etc/ssh/sshd_config
# echo "SSH configuration finished, please download private key file in this location: ~/.ssh/id_rsa to login "
#================================================
# at last, clear the memory
sh -c "echo 3 > /proc/sys/vm/drop_caches"
