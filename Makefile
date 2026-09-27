include .env

COMPOSE = docker compose --env-file .env -f bootstrap/compose.yaml

.PHONY: minio-up minio-down

.env:
	printf 'MINIO_ROOT_USER=admin\nMINIO_ROOT_PASSWORD=%s\n' "$$(openssl rand -hex 16)" > $@

minio-up:
	$(COMPOSE) up -d --wait minio
	$(COMPOSE) run --rm bucket

minio-down:
	$(COMPOSE) down -v
