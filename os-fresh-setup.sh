#!/bin/bash
set -e
#================================================
# This is a OS fresh setup script
# firstly, run command: git clone https://github.com/docker-docker/git-webhook.git
#
#================================================
SSH_PORT="28379"
SSH_PASS="changeit"
HOSTNAME="st_manager"
WEBSIT_NAME="seniortesting.club"
CURRENT_FOLDER=$(pwd)
CODE_WORKSPACE="/opt/workspace"
# This is a fresh install script to setup the debian server environment
hostnamectl set-hostname "${HOSTNAME}"
echo "HostName changed to: ${HOSTNAME}"
#================================================
# 1. setup the host
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
source "${CURRENT_FOLDER}/software/maven.sh"
source "${CURRENT_FOLDER}/software/node.sh"
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
nohup python3 webhooks.py >>app.log 2>&1 &
echo "git webhook setup completed!"
# 3. install the docker
curl -sSL https://get.docker.com/ | sh

rm -rf /etc/docker/daemon.json
rm -f /var/run/docker.sock
echo "{" >/etc/docker/daemon.json &&
  echo "  \"registry-mirrors\": [\"https://jbj2tyqj.mirror.aliyuncs.com\"]" >>/etc/docker/daemon.json &&
  echo "}" >>/etc/docker/daemon.json

sed -i -r 's/(ExecStart*)/#\1/g' /lib/systemd/system/docker.service
sed -i -r '/^#ExecStart=.*/a ExecStart=/usr/bin/dockerd -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375' /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker
echo "Docker installed, set mirror to aliyuncs, open the docker tcp connection for docker swarm!"
usermod -aG docker root

# 3.1 docker-compose
curl -L --fail https://github.com/docker/compose/releases/download/1.28.5/run.sh -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
echo "Docker compose installed"
# 3.2 docker swarm
docker swarm init
#================================================
# 4 setup the nginx server quickly
docker pull nginx:latest
mkdir -p /opt/nginx
openssl dhparam -out /etc/nginx/dhparam.pem 2048
mkdir -p /var/www/_letsencrypt
chown www-data /var/www/_letsencrypt

sed -i "s/example.com/${WEBSIT_NAME}/g" "${CURRENT_FOLDER}/software/nginx/sites-enabled/example.com.conf"
sed -i -r 's/(listen .*443)/\1;#/g; s/(ssl_(certificate|certificate_key|trusted_certificate) )/#;#\1/g' "${CURRENT_FOLDER}/software/nginx/sites-enabled/example.com.conf"
mv "${CURRENT_FOLDER}/software/nginx/sites-enabled/example.com.conf" "${CURRENT_FOLDER}/software/nginx/sites-enabled/${WEBSIT_NAME}.conf"
# run the nginx
docker network create --driver overlay nginx-network
docker build -f "${CURRENT_FOLDER}/software/nginx/Dockerfile" -t custom/nginx:latest "${CURRENT_FOLDER}/software/nginx/"
#docker service create \
#        --network nginx-network \
#        --publish mode=host,published=80,target=80 \
#        --mount src=/etc/nginx,dst=/etc/nginx \
#        --mount src=/run/nginx.pid,dst=/run/nginx.pid \
#        --mount src=/var/log/nginx,dst=/var/log/nginx \
#        --mount src=/etc/letsencrypt,dst=/etc/letsencrypt \
#        --mount src=/var/www/_letsencrypt,dst=/var/www/_letsencrypt \
#        --mount src=/opt/workspace,dst=/opt/workspace \
#        --replicas=1 \
#        custom/nginx:latest
#
#certbot certonly --webroot -d "$WEBSIT_NAME" -d "www.$WEBSIT_NAME" --email alterhu2020@gmail.com -w /var/www/_letsencrypt -n --agree-tos --force-renewal
#
#sed -i -r 's/#?;#//g' /etc/nginx/sites-enabled/"$WEBSIT_NAME".conf
#docker service create --replicas=1 custom/nginx:latest
#
# rm -rf /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh
#echo -e '#!/bin/bash\nnginx -t && systemctl reload nginx' | sudo tee /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh
#sudo chmod a+x /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh
#docker service create --replicas=1 custom/nginx:latest
#================================================
# 5. sshd configuration
ssh-keygen -t rsa -N "$SSH_PASS" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >>~/.ssh/authorized_keys
chown -R root:root ~/.ssh
chmod -R 700 ~/.ssh
chmod -R 600 ~/.ssh/authorized_keys

sed -i -r 's/(Port*)/#\1/g' /etc/ssh/sshd_config
sed -i -r "/^#Port.*/a Port ${SSH_PORT}" /etc/ssh/sshd_config
echo "RSAAuthentication yes" >>/etc/ssh/sshd_config
echo "PubkeyAuthentication yes" >>/etc/ssh/sshd_config
echo "AuthorizedKeysFile .ssh/authorized_keys" >>/etc/ssh/sshd_config
echo "PasswordAuthentication yes" >>/etc/ssh/sshd_config
echo "SSH configuration finished, please download private key file in this location: ~/.ssh/id_rsa to login "
#================================================
# at last, clear the memory
sh -c "echo 3 > /proc/sys/vm/drop_caches"
