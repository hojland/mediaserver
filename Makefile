COMPOSE = docker compose -f docker-compose-plex.yml

down:
	$(COMPOSE) down

up:
	$(COMPOSE) up -d

full:
	make down
	sleep 10
	make up
