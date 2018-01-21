#!/bin/bash

# Lets Encrypt
if [ -z "$EMAIL" ] || [ -z "$HOST_DOMAIN" ] || [ -z "$HOST_IP" ]; then
 echo "You need to set the \$EMAIL, \$HOST_IP and the \$HOST_DOMAIN variables"
else
    certbot certonly --webroot -w $WEBROOT -d $HOST_DOMAIN --email $EMAIL --agree-tos --quiet
    ln -s /etc/nginx/sites-available/default-ssl.conf /etc/nginx/sites-enabled/

    # change nginx for webroot and domain name
    if [ "$WEBROOT" == "" ]; then
        WEBROOT=/app/public
    fi

    if [ "$BOOTSTRAP_SCRIPT" == "" ]; then
        BOOTSTRAP_SCRIPT=index.php
    fi

    sed -i -e "s|##WEBROOT##|$WEBROOT|g" \
           -e "s|##DOMAIN##|$HOST_DOMAIN|g" \
           -e "s|##HOST_IP##|$HOST_IP|g" \
           -e "s|##BOOTSTRAP_SCRIPT##|$BOOTSTRAP_SCRIPT|g" \
         /etc/nginx/sites-available/default-ssl.conf

    supervisorctl restart nginx
fi