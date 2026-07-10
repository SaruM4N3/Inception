# Inception — Roadmap

Suivi de ce qu'il reste à faire pour finir la partie obligatoire, dans l'ordre conseillé.
Coche au fur et à mesure.

## 0. État actuel

- [x] `Makefile` (build/up/down/clean/fclean via docker compose)
- [x] `srcs/docker-compose.yml` : service `nginx` seul, port `443:443`, volume `wordpress` bindé sur `/home/${LOGIN}/data/wordpress`
- [x] `srcs/requirements/nginx/` : Dockerfile + conf TLS 1.2/1.3 fonctionnels
- [x] `.gitignore` : `.env` et `secrets/*.txt` ignorés
- [ ] `srcs/requirements/mariadb/Dockerfile` — vide
- [ ] `srcs/requirements/wordpress/Dockerfile` — vide
- [ ] secrets Docker (`secrets/*.txt` sont vides)
- [ ] `README.md`, `USER_DOC.md`, `DEV_DOC.md`

---

## 1. MariaDB

**But** : conteneur MariaDB seul (pas de nginx dedans), avec un volume nommé pour la base, healthy sans mot de passe en dur dans le Dockerfile.

1. `srcs/requirements/mariadb/Dockerfile` :
   - `FROM debian:bookworm` (ou alpine, même choix que nginx idéalement)
   - `RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*`
   - Copier un script d'entrypoint (`tools/init_db.sh`) qui, **au premier démarrage seulement** (teste si `/var/lib/mysql/mysql` existe déjà) :
     - lance `mysql_install_db`
     - démarre `mariadbd` en arrière-plan le temps de l'init
     - crée la base `wordpress`, un user WordPress normal + l'**administrateur** (attention : le login admin ne doit **pas** contenir `admin`/`administrator`, cf. sujet), lit les mots de passe depuis `/run/secrets/db_password` et `/run/secrets/db_root_password` (Docker secrets, pas de variable en clair)
   - `CMD` doit lancer `mariadbd` **au premier plan** (`exec mariadbd`), pas de `tail -f`/boucle infinie. C'est ça le vrai process PID 1.
   - `EXPOSE 3306`
2. Créer `srcs/requirements/mariadb/tools/init_db.sh` (le script décrit ci-dessus).
3. Dans `docker-compose.yml`, ajouter le service :
   ```yaml
   mariadb:
     container_name: ${CONTAINER_NAME}-mariadb
     build: ./requirements/mariadb
     env_file: .env
     secrets:
       - db_password
       - db_root_password
     restart: unless-stopped
     volumes:
       - mariadb:/var/lib/mysql
     networks:
       - inception
   ```
4. Ajouter le volume `mariadb` avec `driver_opts.device: /home/${LOGIN}/data/mariadb` (même schéma que `wordpress`).
5. **Tester isolément** : `docker compose up -d mariadb`, puis
   `docker exec -it inception-mariadb mysql -uroot -p$(cat secrets/db_root_password.txt) -e "SHOW DATABASES;"`

---

## 2. WordPress + php-fpm

**But** : conteneur avec WordPress installé et configuré, php-fpm qui écoute sur le port 9000, **sans nginx dedans**.

1. `srcs/requirements/wordpress/Dockerfile` :
   - `FROM debian:bookworm`
   - installer `php-fpm`, `php-mysql`, `curl` et **wp-cli** (télécharger le phar officiel, ou compiler depuis les sources autorisées — pas de `docker pull wordpress`)
   - `COPY` un script d'entrypoint (`tools/setup_wp.sh`)
   - `CMD ["php-fpm8.2", "-F"]` (ou la version dispo sur bookworm) — mode foreground, PID 1 propre
2. `tools/setup_wp.sh`, exécuté avant le `CMD` (ou en `ENTRYPOINT` qui `exec`ute php-fpm à la fin) :
   - attend que MariaDB soit joignable (petit `while ! mysqladmin ping ...; do sleep 1; done` — ce n'est **pas** une boucle infinie interdite, c'est une attente bornée de dépendance au démarrage, pratique standard)
   - si `/var/www/html/wordpress/wp-config.php` n'existe pas :
     - `wp core download --path=/var/www/html/wordpress`
     - `wp config create` avec les infos DB lues depuis `.env` + secrets (`DB_NAME`, `DB_USER`, mot de passe lu dans `/run/secrets/db_password`, `DB_HOST=mariadb`)
     - `wp core install` avec l'admin (login ≠ admin/administrator) et un 2e user WordPress simple
   - `exec php-fpm8.2 -F`
3. **Important — alignement avec nginx.conf** : ton `nginx.conf` a `root /var/www/html/wordpress;`. Le volume `wordpress` est monté sur `/var/www/html` des deux côtés (nginx et wordpress). Donc WordPress doit être installé dans `/var/www/html/wordpress/` (pas directement `/var/www/html/`) pour que ça matche. Vérifie ce chemin dans ton script `wp core download --path=...`.
4. Dans `docker-compose.yml` :
   ```yaml
   wordpress:
     container_name: ${CONTAINER_NAME}-wordpress
     build: ./requirements/wordpress
     env_file: .env
     secrets:
       - db_password
     restart: unless-stopped
     volumes:
       - wordpress:/var/www/html
     networks:
       - inception
     depends_on:
       - mariadb
   ```
5. **Tester isolément** avant de rebrancher nginx :
   `docker compose up -d mariadb wordpress`
   `docker exec -it inception-wordpress wp core is-installed --path=/var/www/html/wordpress --allow-root`

---

## 3. Secrets Docker

1. Remplir (localement, jamais commit) :
   - `secrets/db_password.txt` → mot de passe user WordPress
   - `secrets/db_root_password.txt` → mot de passe root MariaDB
   - `secrets/credentials.txt` → si besoin pour d'autres identifiants (WP admin par ex.)
2. Déclarer en bas de `docker-compose.yml` :
   ```yaml
   secrets:
     db_password:
       file: ../secrets/db_password.txt
     db_root_password:
       file: ../secrets/db_root_password.txt
   ```
3. Dans les conteneurs, les secrets apparaissent en lecture seule sous `/run/secrets/<nom>` — c'est ça qu'il faut lire dans les scripts d'init, **jamais** une variable d'env en clair pour un mot de passe.

---

## 4. Compléter `.env`

Actuellement `srcs/.env` a `DOMAIN_NAME`, `LOGIN`, `CONTAINER_NAME`. Ajouter (valeurs non sensibles seulement — les mots de passe restent dans `secrets/`) :
```
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
WP_ADMIN_USER=zsonie_boss      # PAS admin/administrator
WP_ADMIN_EMAIL=you@example.com
WP_USER=second_user
WP_USER_EMAIL=second@example.com
```

---

## 5. Rebrancher nginx

1. Remettre `depends_on: [wordpress]` sur le service `nginx`.
2. Relancer toute la stack : `make re`
3. Reprendre les tests TLS déjà validés, puis vérifier que `https://zsonie.42.fr/` affiche vraiment WordPress (plus un 404).
4. Ajouter l'entrée dans `/etc/hosts` de la VM (ou du poste qui teste) : `127.0.0.1 zsonie.42.fr`.

---

## 6. Documentation obligatoire

- [ ] `README.md` — 1ère ligne en italique : *This project has been created as part of the 42 curriculum by zsonie.* + sections **Description** (incluant VM vs Docker, Secrets vs env vars, Docker network vs host, volumes vs bind mounts), **Instructions**, **Resources** (dont usage de l'IA).
- [ ] `USER_DOC.md` — comment démarrer/arrêter, accéder au site + `/wp-admin`, retrouver les identifiants, vérifier que ça tourne.
- [ ] `DEV_DOC.md` — setup depuis zéro, build/lancement via Makefile, commandes utiles (`make logs`, `docker exec`...), où sont stockées les données.

---

## 7. Checklist finale avant défense

- [ ] Aucun `latest` tag, aucune image pull toute faite (sauf debian/alpine de base)
- [ ] Aucun mot de passe en dur dans un Dockerfile ou committé dans git
- [ ] Chaque service = 1 conteneur = 1 Dockerfile, redémarre après crash (`restart: unless-stopped` partout)
- [ ] Pas de `tail -f`, `sleep infinity`, `while true`, ni `network: host` / `--link`
- [ ] Volumes nommés réellement stockés dans `/home/<login>/data`
- [ ] Un seul point d'entrée : nginx sur 443 en TLS 1.2/1.3
- [ ] 2 users WordPress dont un admin au login conforme
- [ ] `git status` propre : pas de secret traîné dans l'historique

---

## 8. Bonus (seulement si le mandatoire est 100% clean)

- [ ] redis (cache WordPress)
- [ ] FTP server sur le volume wordpress
- [ ] site statique perso (pas de PHP)
- [ ] Adminer
- [ ] un service de ton choix (à justifier en soutenance)
