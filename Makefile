include .env
export AWS_ACCESS_KEY_ID     = $(MINIO_ROOT_USER)
export AWS_SECRET_ACCESS_KEY = $(MINIO_ROOT_PASSWORD)

COMPOSE = docker compose --env-file .env -f bootstrap/compose.yaml

.PHONY: minio-up minio-down cluster-up

.env:
	printf 'MINIO_ROOT_USER=admin\nMINIO_ROOT_PASSWORD=%s\n' "$$(openssl rand -hex 16)" > $@

minio-up:
	$(COMPOSE) up -d --wait minio
	$(COMPOSE) run --rm bucket

minio-down:
	$(COMPOSE) down -v

cluster-up: minio-up
	tofu -chdir=stack/cluster init
	tofu -chdir=stack/cluster apply -auto-approve
