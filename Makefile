.DEFAULT_GOAL := help

SHELL := /bin/sh

ENV ?= dev
ENV_FILE ?= .env
SERVICE ?=

BASE_COMPOSE := compose.yaml
DEV_COMPOSE := compose.override.yaml
PROD_COMPOSE := compose.prod.yaml

ifeq ($(ENV),prod)
COMPOSE_FILES := -f $(BASE_COMPOSE) -f $(PROD_COMPOSE)
else ifeq ($(ENV),dev)
COMPOSE_FILES := -f $(BASE_COMPOSE) -f $(DEV_COMPOSE)
else
$(error Entorno invalido ENV='$(ENV)'. Usa ENV=dev o ENV=prod)
endif

VALIDATE_ENV_FILE := $(if $(wildcard $(ENV_FILE)),$(ENV_FILE),.env.example)
COMPOSE := docker compose --env-file $(ENV_FILE) $(COMPOSE_FILES)

.PHONY: help init check-env up up-build down restart ps logs pull config validate lint clean

##@ General

help: ## Muestra esta ayuda
	@awk 'BEGIN {FS = ":.*##"; printf "\nUso:\n  make <target> [ENV=dev|prod] [SERVICE=<nombre>]\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  %-14s %s\n", $$1, $$2 } /^##@/ { printf "\n%s\n", substr($$0, 5) }' $(MAKEFILE_LIST)

init: ## Crea .env a partir de .env.example si no existe
	@if [ -f "$(ENV_FILE)" ]; then \
		echo "$(ENV_FILE) ya existe; no se sobrescribe."; \
	else \
		cp .env.example "$(ENV_FILE)"; \
		echo "Creado $(ENV_FILE) desde .env.example. Revisa sus valores antes de levantar el stack."; \
	fi

check-env:
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "Error: no existe $(ENV_FILE). Ejecuta 'make init' para crearlo desde .env.example." >&2; \
		exit 1; \
	fi

##@ Ciclo de vida

up: check-env ## Levanta el stack en segundo plano (ENV=dev|prod)
	$(COMPOSE) up -d --remove-orphans $(SERVICE)

up-build: check-env ## Construye imagenes y levanta el stack (ENV=dev|prod)
	$(COMPOSE) up -d --build --remove-orphans $(SERVICE)

down: check-env ## Detiene y elimina contenedores y redes (ENV=dev|prod)
	$(COMPOSE) down --remove-orphans

restart: check-env ## Reinicia todos los servicios o el indicado en SERVICE
	$(COMPOSE) restart $(SERVICE)

pull: check-env ## Descarga las ultimas imagenes configuradas
	$(COMPOSE) pull $(SERVICE)

clean: check-env ## Elimina contenedores, redes y volumenes (destructivo)
	$(COMPOSE) down -v --remove-orphans

##@ Observabilidad

ps: check-env ## Muestra el estado y healthchecks de los contenedores
	$(COMPOSE) ps -a

logs: check-env ## Sigue los logs en tiempo real (soporta SERVICE=<nombre>)
	$(COMPOSE) logs -f --tail=100 $(SERVICE)

config: check-env ## Imprime la configuracion Compose resuelta para ENV
	$(COMPOSE) config

##@ Validacion y calidad

validate: ## Valida compose.yaml, dev y prod con docker compose config
	docker compose --env-file $(VALIDATE_ENV_FILE) -f $(BASE_COMPOSE) config --quiet
	docker compose --env-file $(VALIDATE_ENV_FILE) -f $(BASE_COMPOSE) -f $(DEV_COMPOSE) config --quiet
	docker compose --env-file $(VALIDATE_ENV_FILE) -f $(BASE_COMPOSE) -f $(PROD_COMPOSE) config --quiet
	@echo "Validacion de Docker Compose completada correctamente."

lint: validate ## Ejecuta yamllint (si esta instalado) y validate
	@if command -v yamllint >/dev/null 2>&1; then \
		yamllint -c .yamllint.yaml .; \
	else \
		echo "Aviso: yamllint no esta instalado localmente; se omitio el lint YAML."; \
	fi
