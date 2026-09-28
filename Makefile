include .env
export AWS_ACCESS_KEY_ID     = $(MINIO_ROOT_USER)
export AWS_SECRET_ACCESS_KEY = $(MINIO_ROOT_PASSWORD)

COMPOSE = docker compose --env-file .env -f bootstrap/compose.yaml
TAG := $(shell git rev-parse --short HEAD)
TF ?= tofu

.PHONY: minio-up minio-down cluster-up cluster-down platform-up platform-down build-images apps-up apps-down up down

.env:
	printf 'MINIO_ROOT_USER=admin\nMINIO_ROOT_PASSWORD=%s\n' "$$(openssl rand -hex 16)" > $@

minio-up:
	$(COMPOSE) up -d --wait minio
	$(COMPOSE) run --rm bucket

minio-down:
	$(COMPOSE) down -v

cluster-up: minio-up
	$(TF) -chdir=stack/cluster init
	$(TF) -chdir=stack/cluster apply -auto-approve

platform-down: apps-down
	$(TF) -chdir=stack/platform destroy -auto-approve

cluster-down: platform-down
	$(TF) -chdir=stack/cluster destroy -auto-approve

platform-up: cluster-up
	$(TF) -chdir=stack/platform init
	$(TF) -chdir=stack/platform apply -auto-approve

build-images:
	for s in api orders; do \
	    docker build -t $$s:$(TAG) --build-arg SVC=$$s services || exit 1; \
		kind load docker-image $$s:$(TAG) --name teachy || exit 1; \
    done

apps-up: platform-up build-images
	$(TF) -chdir=stack/apps init
	$(TF) -chdir=stack/apps apply -auto-approve -var image_tag=$(TAG)

apps-down:
	$(TF) -chdir=stack/apps destroy -auto-approve -var image_tag=$(TAG)

up: apps-up

down: cluster-down minio-down
