FROM nginx:latest

ENV TIMEZONE=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime && echo $TIMEZONE > /etc/timezone

COPY nginx.conf /etc/nginx/
COPY nginxconfig.io /etc/nginx/
COPY sites-enabled /etc/nginx/

