# User Documentation

This document is for anyone who just wants to run the Inception stack, use the WordPress site, and manage it day-to-day — no Docker knowledge required.

## What's running

The stack is made of five containers, all managed together:

| Service    | Role                                                        |
|------------|-------------------------------------------------------------|
| `nginx`    | The only entrypoint. Serves the site over HTTPS on port 443 |
| `wordpress`| Runs the WordPress site (php-fpm)                            |
| `mariadb`  | Stores the WordPress database                                |
| `redis`    | Caches WordPress data to speed up the site (bonus)            |
| `adminer`  | Web UI to browse the database, on port 8081 (bonus)            |
| `static`   | Static page about saru onsen (Japanese snow monkeys), on port 8082 (bonus) |

## Starting and stopping

From the root of the repository:

```sh
make up        # build (if needed) and start everything in the background
make down      # stop and remove the containers
make stop      # stop the containers without removing them
make start     # restart previously stopped containers
make restart   # down then up
make ps        # see the status of every container
make logs      # follow the logs of every container
```

Running `make` with no target is the same as `make up`.

## Accessing the site

- Website: `https://zsonie.42.fr`
- WordPress admin panel: `https://zsonie.42.fr/wp-admin`
- Adminer (database UI, bonus): `https://zsonie.42.fr/adminer/` (or directly on `http://<vm-ip>:8081`)
- Static landing page (bonus): `https://zsonie.42.fr/static/` (or directly on `http://<vm-ip>:8082`)

Adminer and the static page are reachable two ways: proxied through nginx under `zsonie.42.fr` (so everything goes through the same TLS entrypoint), or directly on their own port if you'd rather bypass nginx.

The TLS certificate is self-signed (generated at image build time), so your browser will show a security warning on first visit — this is expected, accept/continue.

If the domain doesn't resolve, make sure your machine (or the VM) has this line in `/etc/hosts`:

```
127.0.0.1 zsonie.42.fr
```

## Credentials

Nothing is hardcoded — every password lives in a local file, generated the first time you run `make` and never committed to git:

| File                              | What it is                          |
|------------------------------------|--------------------------------------|
| `srcs/.env`                        | Usernames, emails, domain, DB name (not a password) |
| `secrets/db_password.txt`          | Password for the WordPress DB user (`wp_user`) |
| `secrets/db_root_password.txt`     | MariaDB root password                |
| `secrets/credentials.txt`          | WordPress admin (`superviseur`) password |
| `secrets/wp_user_password.txt`     | Password for the second WordPress user (`editor`) |

Usernames are set in `srcs/.env` (`WP_ADMIN_USER`, `WP_USER`, `MYSQL_USER`); the matching passwords are in the files above.

## Checking everything is running correctly

```sh
make ps
```

All five containers should show as `Up`/`running` (and `unless-stopped`, so they come back automatically after a crash or VM reboot). If one keeps restarting, check its logs:

```sh
docker compose -f srcs/docker-compose.yml logs <service-name>
```

Then confirm the site itself responds:

```sh
curl -Ik https://zsonie.42.fr
```

A `200 OK` (or a WordPress redirect) means the whole chain — nginx → wordpress → mariadb — is working.
