# Inception - build and run the whole infrastructure via docker compose

NAME		= inception

SRCS_DIR	= srcs
COMPOSE_FILE	= $(SRCS_DIR)/docker-compose.yml
ENV_FILE	= $(SRCS_DIR)/.env

# LOGIN must match the one used in docker-compose.yml's volume driver_opts
LOGIN		= zsonie
DATA_DIR	= /home/$(LOGIN)/data

SECRETS_DIR	= secrets
SECRET_FILES	= $(SECRETS_DIR)/db_password.txt \
		  $(SECRETS_DIR)/db_root_password.txt \
		  $(SECRETS_DIR)/credentials.txt \
		  $(SECRETS_DIR)/wp_user_password.txt

COMPOSE		= docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE)

.PHONY: all build up down start stop restart logs ps clean fclean re secrets

all: up

build: secrets
	mkdir -p $(DATA_DIR)/wordpress $(DATA_DIR)/mariadb
	for s in mariadb redis adminer wordpress nginx; do \
		$(COMPOSE) build $$s || exit 1; \
	done

up: build
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

restart: down up

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

$(ENV_FILE):
	mkdir -p $(SRCS_DIR)
	{ \
		echo "CONTAINER_NAME=inception"; \
		echo "LOGIN=$(LOGIN)"; \
		echo "DOMAIN_NAME=$(LOGIN).42.fr"; \
		echo "MYSQL_DATABASE=wordpress"; \
		echo "MYSQL_USER=wp_user"; \
		echo "WP_ADMIN_USER=superviseur"; \
		echo "WP_ADMIN_EMAIL=admin@$(LOGIN).42.fr"; \
		echo "WP_USER=editor"; \
		echo "WP_USER_EMAIL=editor@$(LOGIN).42.fr"; \
	} > $@
	chmod 600 $@

$(SECRETS_DIR)/%.txt:
	mkdir -p $(SECRETS_DIR)
	openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20 > $@
	chmod 600 $@

secrets: $(ENV_FILE) $(SECRET_FILES)

clean: down
	$(COMPOSE) down --rmi all --volumes --remove-orphans

fclean: clean
	sudo rm -rf $(DATA_DIR)

re: fclean all

.DEFAULT_GOAL = all
