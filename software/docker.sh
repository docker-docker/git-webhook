#!/bin/bash
set -e
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
systemctl enable docker
echo "Docker installed, set mirror to aliyuncs, open the docker tcp connection for docker swarm!"
usermod -aG docker root

# 4.1 docker-compose
pip install docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

echo "Docker compose installed"
# 4.2 docker swarm
#docker swarm init