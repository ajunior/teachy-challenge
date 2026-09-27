include .env
export AWS_ACCESS_KEY_ID     = $(MINIO_ROOT_USER)
export AWS_SECRET_ACCESS_KEY = $(MINIO_ROOT_PASSWORD)

COMPOSE = docker compose --env-file .env -f bootstrap/compose.yaml

.PHONY: minio-up minio-down cluster-up cluster-down platform-up platform-down

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

platform-down:
	tofu -chdir=stack/platform destroy -auto-approve

cluster-down: platform-down
	tofu -chdir=stack/cluster destroy -auto-approve

platform-up: cluster-up
	tofu -chdir=stack/platform init
	tofu -chdir=stack/platform apply -auto-approve
