#!/bin/sh
set -e
# This is a fresh install script to setup the debian server environment
HOSTNAME="dd_manager"
hostnamectl set-hostname "dd_manager"
echo "HostName changed to: ${HOSTNAME}"
#================================================
# 1. setup the host
# 1.1 host name
TIMEZONE="Asia/Shanghai"
ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime && echo $TIMEZONE >/etc/timezone
echo "TimeZone changed to ${TIMEZONE}"
#================================================
# 1.2 Customize sources for apt-get: https://cloud.tencent.com/developer/article/1590080
echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free" >/etc/apt/sources.list &&
  echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free" >>/etc/apt/sources.list &&
  echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free" >>/etc/apt/sources.list &&
  echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian-security/ buster/updates main contrib non-free" >>/etc/apt/sources.list &&
  echo "deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster main contrib non-free" >>/etc/apt/sources.list &&
  echo "deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-updates main contrib non-free" >>/etc/apt/sources.list &&
  echo "deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ buster-backports main contrib non-free" >>/etc/apt/sources.list &&
  echo "deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security/ buster/updates main contrib non-free" >>/etc/apt/sources.list

apt-get update &&
  apt-get -y install git &&
  apt-get -y install screen &&
  apt-get -y install unzip
echo "Update the apt package mirror completed!"
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
# 1.4 sshd configuration

# 2. install the docker
curl -sSL https://get.docker.com/ | sh

echo "{\n" >/etc/docker/daemon.json &&
  echo "  \"registry-mirrors\": [\"https://jbj2tyqj.mirror.aliyuncs.com\"]" >>/etc/docker/daemon.json &&
  echo "}" >>/etc/docker/daemon.json

sed -i -r 's/(ExecStart*)/#\1/g' /lib/systemd/system/docker.service
sed -i -r '/^#ExecStart=.*/a ExecStart=/usr/bin/dockerd -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375' /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker
echo "Docker installed, set mirror to aliyuncs, open the docker tcp connection for docker swarm!"

# 2.1 docker-compose
curl -L --fail https://github.com/docker/compose/releases/download/1.28.5/run.sh -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
echo "Docker compose installed"
# 2.5 docker swarm
# docker swarm init

# 3. setup the git webhook
cd /opt
git clone https://github.com/docker-docker/git-webhook.git
cd /opt/git-webhook
docker build -f Dockerfile -t seniortesting:githook .
docker run --name githook -d -p 2345:5000  -v /opt:/opt seniortesting:githook
# at last, clear the memory
sh -c "echo 3 > /proc/sys/vm/drop_caches"
