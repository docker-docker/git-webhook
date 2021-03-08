FROM python:3.10.0a6-slim
MAINTAINER "Walter Hu" <alterhu2020@gmail.com>

ENV TIMEZONE=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime && echo $TIMEZONE > /etc/timezone

VOLUME /opt/app
EXPOSE 5000

WORKDIR /opt/app
COPY . /opt/app
RUN pip install -r requirements.txt
CMD ["python", "webhooks.py"]
