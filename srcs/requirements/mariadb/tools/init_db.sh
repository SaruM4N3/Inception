#!/bin/bash
set -e

DATADIR=/var/lib/mysql

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

if [ ! -d "$DATADIR/mysql" ]; then
	mysql_install_db --user=mysql --datadir="$DATADIR" > /dev/null

	# temporary local instance to run the setup queries against
	mariadbd --user=mysql --datadir="$DATADIR" &
	pid="$!"

	until mysqladmin ping --silent; do
		sleep 1
	done

	DB_PASSWORD=$(cat /run/secrets/db_password)
	DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

	mysql -u root <<-EOSQL
		DELETE FROM mysql.user WHERE User='';
		DROP DATABASE IF EXISTS test;
		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
		CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
		GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
		ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
		FLUSH PRIVILEGES;
	EOSQL

	mysqladmin -u root -p"${DB_ROOT_PASSWORD}" shutdown
	wait "$pid" 2>/dev/null || true
fi

exec mariadbd --user=mysql --datadir="$DATADIR" --bind-address=0.0.0.0
