# Teachy

Infrastructure Technical Challenge - Kubernetes & Observability

## Prerequisites

- GNU Make (v4.4)
- OpenSSL 3
- Docker 29 (with Compose v2)

## Running

```sh
# Start MinIO and create the tfstate bucket
# MinIO COnsole: http://localhost:9001 (credentials in .env)
make minio-up

# Stop MinIO and remove its volume (terraform states are deleted)
make minio-down
```

> `.env` is auto generated on the first run, if it does not exist. Copy
`.env.example` to create it yourself and fill in the values.
