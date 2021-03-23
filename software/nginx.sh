#!/bin/bash
set -eux
# nginx settings
WEBSIT_NAME="$1"
NGINX_VERSION="1.19.0"
PCRE_VERSION="8.44"
ZLIB_VERSION="1.2.11"
OPENSSL_VERSION="1.1.1g"
NGINX_SERVER_NAME="SeniorTesting"
NGINX_FOLDER="/tmp/nginx"
NGINX_MODULE_FOLDER="nginx-modules"

if [ -z "$1" ]; then
    echo -e "\nPlease call '$0 <website name>' to run this command!\n"
    exit 1
fi
sudo rm -rf /etc/nginx
sudo apt update && sudo apt upgrade -y
apt install build-essential -y

sudo mkdir -p ${NGINX_FOLDER}/${NGINX_MODULE_FOLDER}
# PCRE version,http://nginx.org/en/docs/configure.html --with-pcre=path :(version 4.4 — 8.44)
cd ${NGINX_FOLDER}/${NGINX_MODULE_FOLDER}
wget https://ftp.pcre.org/pub/pcre/pcre-${PCRE_VERSION}.tar.gz && tar xzvf pcre-${PCRE_VERSION}.tar.gz && cd pcre-${PCRE_VERSION} && ./configure && make && sudo make install

# zlib version http://nginx.org/en/docs/configure.html --with-zlib=path :(version 1.1.3 — 1.2.11)
cd ${NGINX_FOLDER}/${NGINX_MODULE_FOLDER}
wget http://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz && tar xzvf zlib-${ZLIB_VERSION}.tar.gz && cd zlib-${ZLIB_VERSION} && ./configure && make && sudo make install

# OpenSSL version 1.0.2 - 1.1.0
cd ${NGINX_FOLDER}/${NGINX_MODULE_FOLDER}
wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && tar xzvf openssl-${OPENSSL_VERSION}.tar.gz && cd openssl-${OPENSSL_VERSION} && ./Configure --prefix=/usr && make && sudo make install

# latest ngx_brotli
cd ${NGINX_FOLDER}/${NGINX_MODULE_FOLDER}
git clone https://github.com/google/ngx_brotli && cd ngx_brotli && git submodule update --init --recursive --progress

# nginx version
cd ${NGINX_FOLDER}
wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && tar zxf nginx-${NGINX_VERSION}.tar.gz
# modify nginx default settings
cd ${NGINX_FOLDER}
sed -i -r "s/Server: nginx/Server: ${NGINX_SERVER_NAME}/" nginx-${NGINX_VERSION}/src/http/ngx_http_header_filter_module.c
sed -i -r "s/nginx\//${NGINX_SERVER_NAME}\//" nginx-${NGINX_VERSION}/src/core/nginx.h
sed -i -r "s/<hr><center>nginx<\/center>/<hr><center>${NGINX_SERVER_NAME}<\/center>/" nginx-${NGINX_VERSION}/src/http/ngx_http_special_response.c
# build the source
cd nginx-${NGINX_VERSION}
./configure --prefix=/usr/share/nginx \
--sbin-path=/usr/sbin/nginx \
--modules-path=/usr/lib/nginx/modules \
--conf-path=/etc/nginx/nginx.conf \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--pid-path=/run/nginx.pid \
--lock-path=/var/lock/nginx.lock \
--user=www-data \
--group=www-data \
--http-client-body-temp-path=/var/lib/nginx/body \
--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
--http-proxy-temp-path=/var/lib/nginx/proxy \
--http-scgi-temp-path=/var/lib/nginx/scgi \
--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
--with-openssl=../nginx-modules/openssl-${OPENSSL_VERSION} \
--with-openssl-opt=enable-ec_nistp_64_gcc_128 \
--with-openssl-opt=no-nextprotoneg \
--with-openssl-opt=no-weak-ssl-ciphers \
--with-openssl-opt=no-ssl3 \
--with-pcre=../nginx-modules/pcre-${PCRE_VERSION} \
--with-pcre-jit \
--with-zlib=../nginx-modules/zlib-${ZLIB_VERSION} \
--with-compat \
--with-file-aio \
--with-threads \
--with-http_addition_module \
--with-http_auth_request_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_mp4_module \
--with-http_random_index_module \
--with-http_realip_module \
--with-http_slice_module \
--with-http_ssl_module \
--with-http_sub_module \
--with-http_stub_status_module \
--with-http_v2_module \
--with-http_secure_link_module \
--with-mail \
--with-mail_ssl_module \
--with-stream \
--with-stream_realip_module \
--with-stream_ssl_module \
--with-stream_ssl_preread_module \
--with-debug \
--with-cc-opt='-g -O2 -fPIE -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2' \
--with-ld-opt='-Wl,-Bsymbolic-functions -fPIE -pie -Wl,-z,relro -Wl,-z,now' \
--add-module=../nginx-modules/ngx_brotli
# compile the source
make
sudo make install

sudo mkdir -p /var/lib/nginx && sudo nginx -t

cat >/lib/systemd/system/nginx.service <<EOF
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStartPost=/bin/sleep 0.1
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target

EOF

sudo systemctl enable nginx.service && sudo systemctl start nginx.service

# clear files
sudo rm -rf ${NGINX_FOLDER}
sudo rm -rf /usr/local/nginx/*
#================================================
# copy the settings from nginxconfig.io
sudo mkdir -p /etc/nginx
cp -rf nginx/* /etc/nginx/
# init ssl
cd /etc/nginx
openssl dhparam -out /etc/nginx/dhparam.pem 2048
sudo mkdir -p /var/www/_letsencrypt
sudo chown www-data /var/www/_letsencrypt

FILE="/etc/nginx/sites-enabled/example.com.conf"
if [ -f "$FILE" ]; then
  sed -i "s/example.com/${WEBSIT_NAME}/g" "${FILE}"
  sed -i -r 's/(listen .*443)/\1;#/g; s/(ssl_(certificate|certificate_key|trusted_certificate) )/#;#\1/g' "${FILE}"
  mv "${FILE}" "/etc/nginx/sites-enabled/${WEBSIT_NAME}.conf"
fi

sudo nginx -t && sudo systemctl reload nginx

certbot certonly --webroot -d "$WEBSIT_NAME" -d "www.$WEBSIT_NAME" --email alterhu2020@gmail.com -w /var/www/_letsencrypt -n --agree-tos --force-renewal

sed -i -r 's/#?;#//g' "/etc/nginx/sites-enabled/${WEBSIT_NAME}.conf"

sudo nginx -t && sudo systemctl reload nginx
# Configure Certbot to reload NGINX when it successfully renews certificates:
echo -e '#!/bin/bash\nnginx -t && systemctl reload nginx' | sudo tee /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh
sudo chmod a+x /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh
sudo nginx -t && sudo systemctl reload nginx
