*This project has been created as part of the 42 curriculum by zsonie.*

# Inception

## Description

Inception is a system administration project: a small web infrastructure built entirely with Docker, running inside a dedicated virtual machine. The goal is to serve a WordPress website through NGINX over TLS, backed by a MariaDB database, with every service isolated in its own container instead of relying on a monolithic install or ready-made Docker images.

The stack is orchestrated with `docker compose` and driven by a `Makefile` at the root of the repository. Each service has its own `Dockerfile` under `srcs/requirements/`:

- **nginx** — the single entrypoint of the infrastructure, listening on port 443 with TLSv1.2/TLSv1.3 only, reverse-proxying PHP requests to WordPress.
- **mariadb** — the database engine, initialized on first boot with the WordPress database and users, storing its data in a named volume.
- **wordpress** — WordPress installed and configured via WP-CLI, served by php-fpm (no web server bundled), storing site files in a named volume shared with nginx.
- **redis** (bonus) — object cache backend for WordPress.
- **adminer** (bonus) — lightweight web UI to inspect the MariaDB database.
- **static** (bonus) — a plain HTML/CSS page about *saru onsen* (the Japanese snow monkeys of Jigokudani that bathe in hot springs), served by its own nginx instance on port 8082, with no PHP involved.

Non-sensitive configuration (domain name, database name, usernames, container name) lives in `srcs/.env`. Passwords are never hardcoded and never stored in `.env`; they live in `secrets/*.txt`, mounted into containers as Docker secrets and read from `/run/secrets/`. Both `.env` and `secrets/*.txt` are gitignored — running `make` regenerates them locally on first build.

### Design choices

- **Virtual Machine vs Docker** — the whole project runs inside one VM, which gives full OS-level isolation from the host (its own kernel, its own network stack) at the cost of being heavier and slower to provision. Docker is used *inside* that VM to split the infrastructure into independent, lightweight containers that share the VM's kernel but stay isolated from each other in their own filesystem, process and network namespace. This gives the isolation-per-service the subject asks for without the overhead of one VM per service.
- **Secrets vs Environment variables** — environment variables (`.env`, `env_file`) are convenient but end up readable via `docker inspect` or `/proc/<pid>/environ` inside the container, so they are only used here for non-sensitive values (domain name, DB name, usernames, emails). Docker secrets are mounted read-only as individual files under `/run/secrets/<name>` inside the container's filesystem, aren't exposed through `docker inspect`, and are used for every password (MariaDB root/user password, WordPress admin/user password).
- **Docker network vs Host network** — `network: host`/`--link` are forbidden by the subject and were never used. All containers join a single dedicated bridge network (`inception`), resolve each other by service name through Docker's internal DNS (e.g. nginx talks to `wordpress:9000`, wordpress talks to `mariadb:3306` and `redis:6379`), and only nginx publishes a port to the host (443). This keeps every internal service unreachable from outside the VM.
- **Docker volumes vs Bind mounts** — bind mounts hardcode an arbitrary host path directly in `docker-compose.yml` with no lifecycle management by Docker. The subject requires named volumes, so `wordpress` and `mariadb` are declared as named volumes but configured with `driver_opts` (`type: none`, `o: bind`) pointing at `/home/zsonie/data/wordpress` and `/home/zsonie/data/mariadb`. This satisfies both constraints at once: the volumes are managed through Docker's volume API (`docker volume ls/inspect`, cleaned up by `make clean`) while their data physically lives at the required host path.

## Instructions

Prerequisites: a Linux virtual machine with Docker Engine and the `docker compose` plugin installed, and `make`.

```sh
git clone <this-repo>
cd Inception
make
```

`make` will, in order:
1. Generate `srcs/.env` and the `secrets/*.txt` files if they don't already exist (random passwords via `openssl`).
2. Create the host data directories (`/home/zsonie/data/wordpress`, `/home/zsonie/data/mariadb`).
3. Build every image and start the stack in the background (`docker compose up -d`).

Add the domain to `/etc/hosts` so it resolves locally:

```sh
echo "127.0.0.1 zsonie.42.fr" | sudo tee -a /etc/hosts
```

Then visit `https://zsonie.42.fr`. See [USER_DOC.md](USER_DOC.md) for day-to-day usage and [DEV_DOC.md](DEV_DOC.md) for a full developer setup / command reference.

To connect to the MariaDB database with the `mysql` client:

```sh
docker exec -it inception-mariadb mysql -uroot -p"$(cat secrets/db_root_password.txt)"
docker exec -it inception-mariadb mysql -uwp_user -p"$(cat secrets/db_password.txt)" wordpress
```

## Resources

- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Docker secrets](https://docs.docker.com/engine/swarm/secrets/) and [Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [WP-CLI documentation](https://wp-cli.org/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- [Redis Object Cache plugin](https://wordpress.org/plugins/redis-cache/)
- 42's Inception subject (`en.subject.pdf`)

**AI usage** — Claude Code (Anthropic) was used as a support tool during this project, mainly for debugging help and to write this documentation (`README.md`, `USER_DOC.md`, `DEV_DOC.md`). Every suggestion was reviewed and understood before being applied.
