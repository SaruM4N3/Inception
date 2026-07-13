# Developer Documentation

This document is for anyone setting up, building, or modifying the Inception project.

## Prerequisites

- A Linux virtual machine (this project must run inside a VM, not directly on bare metal or on the host).
- Docker Engine + the `docker compose` plugin.
- `make`.
- A user account on the VM whose login matches `LOGIN` in the [Makefile](Makefile) (`zsonie` by default) — the data volumes are bound to `/home/<LOGIN>/data`, so this must match an existing home directory.

## Repository layout

```
.
├── Makefile
├── secrets/                  # generated locally, gitignored
│   ├── credentials.txt       # WP admin password
│   ├── db_password.txt       # WP DB user password
│   ├── db_root_password.txt  # MariaDB root password
│   └── wp_user_password.txt  # second WP user password
└── srcs/
    ├── .env                  # generated locally, gitignored
    ├── docker-compose.yml
    └── requirements/
        ├── nginx/
        ├── mariadb/
        ├── wordpress/
        └── bonus/
            ├── redis/
            ├── adminer/
            └── static/
```

Each service directory contains its own `Dockerfile` and, where needed, a `conf/` (static config) and/or `tools/` (entrypoint scripts) subfolder.

## Setting up the environment from scratch

Nothing needs to be created by hand — `srcs/.env` and `secrets/*.txt` don't exist after a fresh clone (they're gitignored) and the Makefile generates them on the first build:

- `srcs/.env` is written from the `$(ENV_FILE)` rule in the [Makefile](Makefile): container name, `LOGIN`, `DOMAIN_NAME` (`<LOGIN>.42.fr`), DB name, WP usernames/emails.
- Each `secrets/*.txt` is generated with `openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20`, `chmod 600`.

If you need different values (e.g. a different `LOGIN`), either edit the `LOGIN` variable at the top of the Makefile before the first build, or delete `srcs/.env` and the relevant `secrets/*.txt` and re-run `make` — but note the database and WordPress install are only initialized once (on an empty volume), so changing credentials afterwards means wiping the volumes too (`make fclean`).

Also add the domain to `/etc/hosts` on whatever machine you're browsing from:

```sh
echo "127.0.0.1 zsonie.42.fr" | sudo tee -a /etc/hosts
```

## Building and launching

```sh
make            # = make up: generate secrets, build images, start containers
make build      # just build the images (no start)
make up         # build + docker compose up -d
make down       # docker compose down
make re         # fclean + all: full teardown and rebuild from scratch
```

`docker compose` is always invoked with the compose file and env file explicit, so you can also drive it directly for finer-grained control:

```sh
docker compose -f srcs/docker-compose.yml --env-file srcs/.env <command>
```

## Useful commands

```sh
make ps                                              # container status
make logs                                            # follow logs of every service
docker compose -f srcs/docker-compose.yml logs -f wordpress   # logs of one service
docker exec -it inception-wordpress bash             # shell into a container
docker exec -it inception-mariadb mysql -uroot -p$(cat secrets/db_root_password.txt)
docker volume ls                                     # list named volumes
docker network inspect srcs_inception                # inspect the internal network
```

To rebuild a single service after editing its `Dockerfile` or config:

```sh
docker compose -f srcs/docker-compose.yml --env-file srcs/.env build --no-cache <service>
docker compose -f srcs/docker-compose.yml --env-file srcs/.env up -d <service>
```

## Reaching each container

All containers are Debian-based, so `bash` is available in every one of them. Container names are `${CONTAINER_NAME}-<service>` (`inception-<service>` with the default `.env`).

```sh
docker exec -it inception-nginx bash
docker exec -it inception-mariadb bash
docker exec -it inception-wordpress bash
docker exec -it inception-redis bash
docker exec -it inception-adminer bash
docker exec -it inception-static bash
```

Once inside, the tool relevant to that service is already installed — you don't have to install anything extra:

| Container      | Useful command once inside                                                        |
|-----------------|-------------------------------------------------------------------------------------|
| `inception-nginx`     | `nginx -t` (check config), `cat /etc/nginx/nginx.conf`                        |
| `inception-mariadb`   | `mysql -uroot -p"$(cat /run/secrets/db_root_password)"`                       |
| `inception-wordpress` | `wp --info --path=/var/www/html/wordpress --allow-root` (wp-cli)              |
| `inception-redis`     | `redis-cli -h redis ping`                                                     |
| `inception-adminer`   | `php -v` (it's just a one-file PHP script served by the built-in PHP server)  |
| `inception-static`    | `nginx -t`, `ls /var/www/html/static`                                          |

You can skip the shell and run a single command directly, e.g.:

```sh
docker exec -it inception-mariadb mysql -uroot -p"$(cat secrets/db_root_password.txt)"
docker exec -it inception-wordpress wp user list --path=/var/www/html/wordpress --allow-root
docker exec -it inception-redis redis-cli -h redis ping
```

Note: `mariadb`, `wordpress`, and `redis` have no `ports:` entry in `docker-compose.yml`, so they're only reachable from inside the VM — either through `docker exec` or from another container on the `inception` network — never directly from outside. `adminer` and `static` do publish a port (`8081`, `8082`) since the subject allows bonus services to open extra ports.

## Data persistence

WordPress files and the MariaDB database are stored in two named volumes (`wordpress`, `mariadb`), declared in `srcs/docker-compose.yml` with `driver_opts` binding them to real paths on the host:

- `/home/<LOGIN>/data/wordpress` → mounted at `/var/www/html` in both the `nginx` and `wordpress` containers.
- `/home/<LOGIN>/data/mariadb` → mounted at `/var/lib/mysql` in the `mariadb` container.

Because they're named volumes (not bind mounts), they're visible to `docker volume ls`/`inspect` and get cleaned up by `make clean`/`make fclean`, but the data itself survives `make down`/`make up`/`make restart` and container recreation — only `make fclean` (which does `sudo rm -rf /home/<LOGIN>/data`) actually deletes it. `make clean` also runs `docker compose down --rmi all --volumes --remove-orphans`, which drops the Docker volume *objects*, but the underlying host directories are removed separately by `fclean`.

MariaDB and WordPress are only initialized on an **empty** volume (`srcs/requirements/mariadb/tools/init_db.sh` and `srcs/requirements/wordpress/tools/setup_wp.sh` both check for existing data before running install steps), so re-running `make up` on an existing volume just restarts the services without touching the data.
