# git-webhook

A slim base version image for git webhook,borrow from: <https://github.com/carlos-jenkins/python-github-webhooks>

## What the script done

1. Change the hostname
2. Change the host's timezone
3. Change the debian install package's mirror
4. Change the max buffer file
5. Configure the SSH
6. Install JDK, Node, Docker
7. Configure the Docker's registry mirrors, open the tcp, docker-compose, docker-swarm
8. Run the git webhook server background
9. Run the nginx from docker service and setup the nginx

## how to use `git-webhook`

Please refer page: <https://github.com/carlos-jenkins/python-github-webhooks> for detail info

Run as following script:

```shell
$ apt install -y git
$ mkdir -p /opt/workspace
$ cd /opt/workspace
$ git clone https://github.com/docker-docker/git-webhook.git
$ cd git-webhook
$ chmod +x os-fresh-setup.sh software/* hooks/*
$ ./os-fresh-setup.sh

$ git fetch --all
$ git reset --hard origin/main
```
## renew nginx new domain name

```shell


```
