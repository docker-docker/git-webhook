#!/bin/bash
set -e
#================================================
# This is a OS fresh setup script
# firstly, run command: git clone https://github.com/docker-docker/git-webhook.git
#
#================================================
SSH_PORT="28379"
SSH_PASS="changeit"
HOST_NAME="st-manager"
WEBSIT_NAME="seniortesting.club"
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
  apt-get -y install ca-certificates curl wget gnupg dirmngr xz-utils libatomic1 --no-install-recommends apt-utils git unzip screen certbot
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
sudo chmod +x software/* hooks/*
source "${CURRENT_FOLDER}/software/maven.sh"
source "${CURRENT_FOLDER}/software/node.sh"
source "${CURRENT_FOLDER}/software/nginx.sh ${WEBSIT_NAME}"
#================================================
# 2. setup the git webhook in current manager machine
wget -O get-pip.py https://github.com/pypa/get-pip/raw/b60e2320d9e8d02348525bd74e871e466afdf77c/get-pip.py
python3 get-pip.py \
  --disable-pip-version-check \
  --no-cache-dir
pip --version
find /usr/local -depth \
  \( \
  \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
  -o \
  \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
  \) -exec rm -rf '{}' +
rm -f get-pip.py

cd "${CURRENT_FOLDER}"
pip install -r requirements.txt
# nohup python3 webhooks.py >>app.log 2>&1 &
echo "git webhook setup completed!"
cat >/lib/systemd/system/githook.service <<EOF
[Unit]
Description=A Git webhook to integration git pull event
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
# Our service will notify systemd once it is up and running
Type=simple
ExecStart=/usr/bin/python3 /opt/workspace/git-webhook/webhooks.py
StandardInput=tty-force
# Disable Python's buffering of STDOUT and STDERR, so that output from the
# service shows up immediately in systemd's logs
Environment=PYTHONUNBUFFERED=1
# Automatically restart the service if it crashes
Restart=on-failure

[Install]
# Tell systemd to automatically start this service when the system boots
# (assuming the service is enabled)
WantedBy=multi-user.target

EOF

sudo systemctl daemon-reload && sudo systemctl enable githook.service && sudo systemctl start githook.service
#================================================
# 3. sshd configuration
ssh-keygen -t rsa -b 4096 -C "alterhu2020@gmail.com" -N "$SSH_PASS" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
chown -R root:root ~/.ssh
chmod -R 700 ~/.ssh
chmod -R 600 ~/.ssh/authorized_keys
# add the key into github page: https://github.com/settings/keys
# "Key is invalid. You must supply a key in OpenSSH public key format" if this error please use cat to copied into console
# cat ~/.ssh/id_rsa.pub

sed -i -r 's/(Port*)/#\1/g' /etc/ssh/sshd_config
sed -i -r "/^#Port.*/a Port ${SSH_PORT}" /etc/ssh/sshd_config
echo "RSAAuthentication yes" >>/etc/ssh/sshd_config
echo "PubkeyAuthentication yes" >>/etc/ssh/sshd_config
echo "AuthorizedKeysFile .ssh/authorized_keys" >>/etc/ssh/sshd_config
echo "PasswordAuthentication yes" >>/etc/ssh/sshd_config
echo "SSH configuration finished, please download private key file in this location: ~/.ssh/id_rsa to login "
#================================================
# 4. install the docker
curl -sSL https://get.docker.com/ | sh

rm -rf /etc/docker/daemon.json
rm -f /var/run/docker.sock
echo "{" >/etc/docker/daemon.json &&
  echo "  \"registry-mirrors\": [\"https://jbj2tyqj.mirror.aliyuncs.com\"]" >>/etc/docker/daemon.json &&
  echo "}" >>/etc/docker/daemon.json

sed -i -r 's/(ExecStart*)/#\1/g' /lib/systemd/system/docker.service
sed -i -r '/^#ExecStart=.*/a ExecStart=/usr/bin/dockerd -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2857' /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker
echo "Docker installed, set mirror to aliyuncs, open the docker tcp connection for docker swarm!"
usermod -aG docker root

# 4.1 docker-compose
curl -L --fail https://github.com/docker/compose/releases/download/1.28.5/run.sh -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
echo "Docker compose installed"
# 4.2 docker swarm
#docker swarm init
#================================================
# at last, clear the memory
sh -c "echo 3 > /proc/sys/vm/drop_caches"
