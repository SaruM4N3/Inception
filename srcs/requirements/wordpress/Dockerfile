FROM debian:bookworm

RUN apt-get update && apt-get install -y \
	php-fpm \
	php-mysql \
	php-curl \
	php-gd \
	php-mbstring \
	php-xml \
	php-zip \
	php-redis \
	mariadb-client \
	redis-tools \
	curl \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -o /usr/local/bin/wp -L \
	https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x /usr/local/bin/wp

# listen on TCP so nginx (another container) can reach php-fpm via fastcgi_pass wordpress:9000
RUN PHP_FPM_CONF=$(find /etc/php -name www.conf) \
	&& sed -i "s/^listen = .*/listen = 0.0.0.0:9000/" "$PHP_FPM_CONF"

COPY tools/setup_wp.sh /usr/local/bin/setup_wp.sh
RUN chmod +x /usr/local/bin/setup_wp.sh

EXPOSE 9000

CMD ["setup_wp.sh"]
