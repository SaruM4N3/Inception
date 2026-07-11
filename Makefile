# Inception - build and run the whole infrastructure via docker compose

NAME		= inception

SRCS_DIR	= srcs
COMPOSE_FILE	= $(SRCS_DIR)/docker-compose.yml
ENV_FILE	= $(SRCS_DIR)/.env

# LOGIN must match the one used in docker-compose.yml's volume driver_opts
LOGIN		= zsonie
DATA_DIR	= /home/$(LOGIN)/data

COMPOSE		= docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE)

.PHONY: all build up down start stop restart logs ps clean fclean re

all: up

build: $(ENV_FILE)
	mkdir -p $(DATA_DIR)/wordpress $(DATA_DIR)/mariadb
	$(COMPOSE) build

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
	$(error $(ENV_FILE) not found. Create it with your environment variables (see subject example))

clean: down
	$(COMPOSE) down --rmi all --volumes --remove-orphans

fclean: clean
	sudo rm -rf $(DATA_DIR)

re: fclean all

.DEFAULT_GOAL = all
