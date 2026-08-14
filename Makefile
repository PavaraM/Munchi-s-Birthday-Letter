SHELL := /bin/bash
.DEFAULT_GOAL := help

APP_IMAGE   ?= ghcr.io/pavaram/munchi-birthday
APP_VERSION ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
APP_PORT    ?= 8080
COMPOSE     ?= docker compose

.PHONY: help setup lint build test serve docker-build docker-run docker-stop \
        ci deploy rollback ssh status clean

help: ## list available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-15s\033[0m %s\n",$$1,$$2}'

setup: ## install dev tooling (node deps)
	npm install

lint: ## validate HTML with html-validate
	npx html-validate index.html

build: ## minify + precompress the site into dist/
	scripts/build.sh

test: build ## build then run local smoke tests against dist/
	scripts/smoke-test.sh $(APP_PORT)

serve: ## serve dist/ locally with a static server
	scripts/serve.sh $(APP_PORT)

docker-build: ## build the production container image
	docker build -t $(APP_IMAGE):$(APP_VERSION) -t $(APP_IMAGE):latest .

docker-run: docker-build ## build + run the container locally (http://localhost:8080)
	$(COMPOSE) up -d --build

docker-stop: ## stop local containers
	$(COMPOSE) down

ci: lint test ## everything CI runs for a static site

deploy: ## deploy latest image to the remote host (requires VM_* env vars)
	scripts/deploy.sh

rollback: ## roll the remote host back to the previous image (requires VM_* env vars)
	scripts/rollback.sh

ssh: ## open a shell on the remote host (requires VM_* env vars)
	ssh -p $${VM_SSH_PORT:-22} -i $${VM_SSH_KEY:-$$HOME/.ssh/id_ed25519} $${VM_USER:-opc}@$${VM_HOST}

status: ## show container status on the remote host
	ssh -p $${VM_SSH_PORT:-22} $${VM_USER:-opc}@$${VM_HOST} \
		"docker compose -f /opt/munchi-birthday/docker-compose.yml ps"

clean: ## remove build output and local containers
	rm -rf dist
	$(COMPOSE) down -v --remove-orphans 2>/dev/null || true
