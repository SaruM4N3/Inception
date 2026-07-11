FROM debian:bookworm

RUN apt-get update && apt-get install -y \
	php-cli \
	php-mysqli \
	curl \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/www/html \
	&& curl -o /var/www/html/adminer.php -L \
	https://www.adminer.org/latest.php

WORKDIR /var/www/html

EXPOSE 8080

CMD ["php", "-S", "0.0.0.0:8080", "adminer.php"]
