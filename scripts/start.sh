#! /usr/bin/env bash

# set -x

PHP_SETTINGS=/usr/local/etc/php/conf.d/99-docker-settings.ini

# Disable Strict Host checking
mkdir -p -m 0700 /root/.ssh
echo -e "Host *\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config

if [ ! -z "$SSH_KEY" ]; then
 echo $SSH_KEY > /root/.ssh/id_rsa.base64
 base64 -d /root/.ssh/id_rsa.base64 > /root/.ssh/id_rsa
 chmod 600 /root/.ssh/id_rsa
fi

# Set custom webroot
if [ -z "$WEBROOT" ]; then
    WEBROOT=/app/public
    if ! grep -q WEBROOT ~/.bashrc ; then
        echo WEBROOT=$WEBROOT >> ~/.bashrc
        echo export WEBROOT >> ~/.bashrc
    fi
fi
export WEBROOT

if [ -z "$BOOTSTRAP_SCRIPT" ]; then
    BOOTSTRAP_SCRIPT=index.php
fi

if [ -z "$HOST_IP" ]; then
    HOST_IP=`/bin/hostname -I`
fi

# Verify the original files
if [ -f /etc/nginx/sites-available/default.conf.orig ]; then
    # Original exists, reset config
    cp -f /etc/nginx/sites-available/default.conf.orig /etc/nginx/sites-available/default.conf
    cp -f /usr/local/etc/php/conf.d/00-xdebug.ini.orig /usr/local/etc/php/conf.d/00-xdebug.ini
else
    # First time we run this, create backup files
    cp -f /etc/nginx/sites-available/default.conf /etc/nginx/sites-available/default.conf.orig
    cp -f /usr/local/etc/php/conf.d/00-xdebug.ini /usr/local/etc/php/conf.d/00-xdebug.ini.orig
fi

sed -i  -e "s|##WEBROOT##|$WEBROOT|g" \
        -e "s|##HOST_DOMAIN##|$HOST_DOMAIN|g" \
        -e "s|##HOST_IP##|$HOST_IP|g" \
        -e "s|##BOOTSTRAP_SCRIPT##|$BOOTSTRAP_SCRIPT|g" \
         /etc/nginx/sites-available/default.conf

if [ ! -z "$XDEBUG_HOST_IP" ]; then
    sed -i "s|##HOST_IP##|$XDEBUG_HOST_IP|g" /usr/local/etc/php/conf.d/00-xdebug.ini
fi

echo $HOST_IP $HOST_DOMAIN >> /etc/hosts

# Display PHP error's or not
if [[ "$ERRORS" == "0" ]] ; then
    echo php_flag[display_errors] = off >> /usr/local/etc/php-fpm.conf
else
    echo php_flag[display_errors] = on >> /usr/local/etc/php-fpm.conf
fi

# Display Version Details or not
#if [[ "$HIDE_NGINX_HEADERS" == "0" ]] ; then
# sed -i "s/server_tokens off;/server_tokens on;/g" /etc/nginx/nginx.conf
#else
# sed -i "s/expose_php = On/expose_php = Off/g" /usr/local/etc/php-fpm.conf
#fi

# Pass real-ip to logs when behind ELB, etc
#if [[ "$REAL_IP_HEADER" == "1" ]] ; then
# sed -i "s/#real_ip_header X-Forwarded-For;/real_ip_header X-Forwarded-For;/" /etc/nginx/sites-available/default.conf
# sed -i "s/#set_real_ip_from/set_real_ip_from/" /etc/nginx/sites-available/default.conf
# if [ ! -z "$REAL_IP_FROM" ]; then
#  sed -i "s#172.16.0.0/12#$REAL_IP_FROM#" /etc/nginx/sites-available/default.conf
# fi
#fi
## Do the same for SSL sites
#if [ -f /etc/nginx/sites-available/default-ssl.conf ]; then
# if [[ "$REAL_IP_HEADER" == "1" ]] ; then
#  sed -i "s/#real_ip_header X-Forwarded-For;/real_ip_header X-Forwarded-For;/" /etc/nginx/sites-available/default-ssl.conf
#  sed -i "s/#set_real_ip_from/set_real_ip_from/" /etc/nginx/sites-available/default-ssl.conf
#  if [ ! -z "$REAL_IP_FROM" ]; then
#   sed -i "s#172.16.0.0/12#$REAL_IP_FROM#" /etc/nginx/sites-available/default-ssl.conf
#  fi
# fi
#fi

# Increase the memory_limit
if [ ! -z "$PHP_MEM_LIMIT" ]; then
 sed -i "s/memory_limit = .*/memory_limit = ${PHP_MEM_LIMIT}M/g" $PHP_SETTINGS
fi

# Increase the post_max_size
if [ ! -z "$PHP_POST_MAX_SIZE" ]; then
 sed -i "s/post_max_size = .*M/post_max_size = ${PHP_POST_MAX_SIZE}M/g" $PHP_SETTINGS
fi

# Increase the upload_max_filesize
if [ ! -z "$PHP_UPLOAD_MAX_FILESIZE" ]; then
 sed -i "s/upload_max_filesize = .*/upload_max_filesize= ${PHP_UPLOAD_MAX_FILESIZE}M/g" $PHP_SETTINGS
fi

# if [ ! -z "$PUID" ]; then
#   if [ -z "$PGID" ]; then
#     PGID=${PUID}
#   fi
#   deluser nginx
#   addgroup -g ${PGID} nginx
#   adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx -u ${PUID} nginx
# else
#   chown -Rf nginx.nginx /var/www/html
# fi

# Run custom scripts
# if [[ "$RUN_SCRIPTS" == "1" ]] ; then
#   if [ -d "/var/www/html/scripts/" ]; then
#     # make scripts executable incase they aren't
#     chmod -Rf 750 /var/www/html/scripts/*
#     # run scripts in number order
#     for i in `ls /var/www/html/scripts/`; do /var/www/html/scripts/$i ; done
#   else
#     echo "Can't find script directory"
#   fi
# fi

# Start supervisord and services
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
