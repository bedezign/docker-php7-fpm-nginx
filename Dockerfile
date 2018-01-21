FROM php:7.2-fpm

MAINTAINER Steve <Steve@bedezign.com>

ARG RELEASE=stretch

ENV PHP_CONF /usr/local/etc/php-fpm.conf
ENV FPM_CONF /usr/local/etc/php-fpm.d/www.conf
ENV PHP_SETTINGS /usr/local/etc/php/conf.d/99-docker-settings.ini
ENV BASHRC /root/.bashrc
ENV NGINX_VERSION 1.13.7-1~$RELEASE
ENV NJS_VERSION   1.13.7.0.1.15-1~$RELEASE

# Performance optimization - see https://gist.github.com/jpetazzo/6127116
# this forces dpkg not to call sync() after package extraction and speeds up install
RUN echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup
# we don't need and apt cache in a container
RUN echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache
RUN echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/no-lang

RUN set -x \
	&& apt-get update && apt-get install -my wget gnupg \
	&& \
	NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
	apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
	&& dpkgArch="$(dpkg --print-architecture)" \
	&& nginxPackages=" \
		nginx=${NGINX_VERSION} \
		nginx-module-xslt=${NGINX_VERSION} \
		nginx-module-geoip=${NGINX_VERSION} \
		nginx-module-image-filter=${NGINX_VERSION} \
		nginx-module-njs=${NJS_VERSION} \
	" \
	&& case "$dpkgArch" in \
		amd64|i386) \
# arches officialy built by upstream
			echo "deb http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list \
			&& apt-get update \
			;; \
		*) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published source packages
			echo "deb-src http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list \
			\
# new directory for storing sources and .deb files
			&& tempDir="$(mktemp -d)" \
			&& chmod 777 "$tempDir" \
# (777 to ensure APT's "_apt" user can access it too)
			\
# save list of currently-installed packages so build dependencies can be cleanly removed later
			&& savedAptMark="$(apt-mark showmanual)" \
			\
# build .deb files from upstream's source packages (which are verified by apt-get)
			&& apt-get update \
			&& apt-get build-dep -y $nginxPackages \
			&& ( \
				cd "$tempDir" \
				&& DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" \
					apt-get source --compile $nginxPackages \
			) \
# we don't remove APT lists here because they get re-downloaded and removed later
			\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
# (which is done after we install the built packages so we don't have to redownload any overlapping dependencies)
			&& apt-mark showmanual | xargs apt-mark auto > /dev/null \
			&& { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
			\
# create a temporary local APT repo to install from (so that dependency resolution can be handled by APT, as it should be)
			&& ls -lAFh "$tempDir" \
			&& ( cd "$tempDir" && dpkg-scanpackages . > Packages ) \
			&& grep '^Package: ' "$tempDir/Packages" \
			&& echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list \
# work around the following APT issue by using "Acquire::GzipIndexes=false" (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
#   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
#   ...
#   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
			&& apt-get -o Acquire::GzipIndexes=false update \
			;; \
	esac \
	\
	&& apt-get install --no-install-recommends --no-install-suggests -y \
						$nginxPackages \
						gettext-base \
	&& rm -rf /var/lib/apt/lists/* \
	\
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
	&& if [ -n "$tempDir" ]; then \
		apt-get purge -y --auto-remove \
		&& rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
	fi

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

# Add NodeJS repo
RUN curl -sL https://deb.nodesource.com/setup_7.x | bash -

# Add mongodb repo
# RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv A15703C6
# RUN echo "deb http://repo.mongodb.org/apt/debian "$RELEASE"/mongodb-org/3.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list

RUN apt-get upgrade -qy \
&& apt-get install --no-install-recommends --no-install-suggests -y \
    ca-certificates \
    gettext-base \
    libpq-dev \
    # postgresql-client \
    mysql-client \
    curl \
    wget \
    openssh-client \
    htop \
    less \
    groff \
    jq \
    nano \
    sed \
    telnet \
    net-tools \
    kmod \
    sshfs \
    vim \
    pv \
    supervisor \
    git \
    git-flow \
    git-svn \
    # XSL
    libxslt-dev \
    nodejs \
    # GD
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev \
    # intl
    libicu-dev \
    # mcrypt
    # libmcrypt-dev \
    # imap
    libc-client-dev libkrb5-dev \
    # Python / PIP / letsencrypt
    python3-dev \
    python3-setuptools \
    python3-pip \
    libffi-dev \
    sudo \
    # canvg (html2canvas svg helper)
    libcairo2-dev libjpeg-dev libgif-dev

RUN pip3 install --upgrade pip && \
    pip3 install --upgrade packaging && \
    pip3 install --upgrade setuptools && \
    pip3 install --upgrade appdirs 
# && \
#    pip3 install --upgrade certbot && \
#    mkdir -p /etc/letsencrypt/webrootauth

RUN docker-php-ext-install bcmath gd intl soap sockets xml xmlrpc xsl zip
RUN docker-php-ext-install pcntl pdo_pgsql pdo_mysql
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl && docker-php-ext-install imap

RUN pecl channel-update pecl.php.net
RUN pecl install -o xdebug-beta hrtime mongodb

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

RUN mkdir -p /var/log/supervisor && \
    mkdir -p /run/nginx && \
    mkdir -p /etc/nginx

ADD configs/supervisor/supervisord.conf /etc/supervisord.conf

# Install generic aliases/extra stuff
RUN echo export LS_OPTIONS=\'--color=auto\' >> ${BASHRC} && \
    echo eval \"\`dircolors --sh\`\" >> ${BASHRC} && \
    echo alias ll=\'ls \$LS_OPTIONS -lA\' >> ${BASHRC} && \
    # Load XDebug Zend extension with php command
    echo alias php=\"php -dzend_extension=xdebug.so\" >> ${BASHRC} && \
    # PHPUnit needs xdebug for coverage. In this case, just make an alias with php command prefix.
    echo alias phpunit=\"php /app/vendor/bin/phpunit\" >> ~/.bashrc && \
    # PHPSpec alias via PHP (with XDebug)
    echo alias phpspec=\"php /app/vendor/bin/phpspec\" >> ~/.bashrc

# Install composer and make it available in the path
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer && \
    # Use github over HTTPS
    composer config -g github-protocols https && \
    # Packagist over HTTPS
    composer config -g repo.packagist composer https://packagist.org

ADD configs/php/00-xdebug.ini configs/php/20-mongodb.ini /usr/local/etc/php/conf.d/
ADD configs/php/php-www.ini /usr/local/etc/php/fpm.ini

# Setup nginx
RUN mkdir -p /etc/nginx/sites-available/ && \
    mkdir -p /etc/nginx/sites-enabled/ && \
    mkdir -p /etc/nginx/ssl/ && \
    rm -Rf /var/www/*

# Copy our nginx config
RUN rm -Rf /etc/nginx/nginx.conf
ADD configs/nginx/nginx.conf /etc/nginx/nginx.conf

ADD configs/nginx/site.conf /etc/nginx/sites-available/default.conf
ADD configs/nginx/site-ssl.conf /etc/nginx/sites-available/default-ssl.conf
RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf
# SSL variant is added by running the letsencrypt script

RUN echo "cgi.fix_pathinfo=0" > ${PHP_SETTINGS} && \
    echo "upload_max_filesize = 100M"  >> ${PHP_SETTINGS} && \
    echo "post_max_size = 100M"  >> ${PHP_SETTINGS} && \
    echo "variables_order = \"EGPCS\""  >> ${PHP_SETTINGS} && \
    echo "memory_limit = 512M"  >> ${PHP_SETTINGS} && \
    sed -i \
        -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
        -e "s/pm.max_children = 5/pm.max_children = 4/g" \
        -e "s/pm.start_servers = 2/pm.start_servers = 3/g" \
        -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" \
        -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" \
        -e "s/;pm.max_requests = 500/pm.max_requests = 200/g" \
        -e "s/user = www-data/user = nginx/g" \
        -e "s/group = www-data/group = nginx/g" \
        -e "s/;listen.mode = 0660/listen.mode = 0666/g" \
        -e "s/;listen.owner = www-data/listen.owner = nginx/g" \
        -e "s/;listen.group = www-data/listen.group = nginx/g" \
        -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        ${FPM_CONF}

ADD scripts/start.sh /start.sh
ADD scripts/letsencrypt-setup.sh /usr/bin/letsencrypt-setup
ADD scripts/letsencrypt-renew.sh /usr/bin/letsencrypt-renew
RUN chmod 755 /start.sh /usr/bin/letsencrypt-setup /usr/bin/letsencrypt-renew

# Clean apt caches
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set the WORKDIR to /app so all following commands run in /app
WORKDIR /app

EXPOSE 80 443

CMD ["/start.sh"]