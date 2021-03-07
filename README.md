# git-webhook

A slim base version image for git webhook

# How to use this `Dockerfile`

```shell

$ docker build -f Dockerfile -t test:githook .
$ docker run --name test -d -p 5000:5000 -v $PWD:/opt/app test:githook

```