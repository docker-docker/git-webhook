# git-webhook

A slim base version image for git webhook,borrow from: <https://github.com/carlos-jenkins/python-github-webhooks>

## how to use `git-webhook`

Please refer page: <https://github.com/carlos-jenkins/python-github-webhooks> for detail info

Deploy steps:

```shell
$ cd /opt
$ git clone https://github.com/docker-docker/git-webhook.git
$ cd /opt/git-webhook
$ docker build -f Dockerfile -t seniortesting:githook .
$ docker run --name githook -d -p 5000:5000  -v /opt:/opt seniortesting:githook
```
