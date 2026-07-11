#!/bin/bash
set -e

WP_PATH=/var/www/html/wordpress
DB_PASSWORD=$(cat /run/secrets/db_password)

until mysqladmin ping -h mariadb -u"${MYSQL_USER}" -p"${DB_PASSWORD}" --silent; do
	sleep 1
done

if [ ! -f "$WP_PATH/wp-config.php" ]; then
	mkdir -p "$WP_PATH"

	wp core download --path="$WP_PATH" --allow-root

	wp config create \
		--path="$WP_PATH" \
		--dbname="${MYSQL_DATABASE}" \
		--dbuser="${MYSQL_USER}" \
		--dbpass="${DB_PASSWORD}" \
		--dbhost=mariadb \
		--allow-root

	wp core install \
		--path="$WP_PATH" \
		--url="https://${DOMAIN_NAME}" \
		--title="Inception" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="$(cat /run/secrets/credentials)" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email \
		--allow-root

	wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
		--path="$WP_PATH" \
		--role=author \
		--user_pass="$(cat /run/secrets/wp_user_password)" \
		--allow-root
fi

until redis-cli -h redis ping 2>/dev/null | grep -q PONG; do
	sleep 1
done

wp config set WP_REDIS_HOST redis --path="$WP_PATH" --allow-root
wp plugin install redis-cache --activate --path="$WP_PATH" --allow-root
wp redis enable --path="$WP_PATH" --allow-root

chown -R www-data:www-data "$WP_PATH"

PHP_FPM_BIN=$(find /usr/sbin -name 'php-fpm*' | head -1)
exec "$PHP_FPM_BIN" -F
