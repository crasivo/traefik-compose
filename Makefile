# ==============================================================================
# Execution:     Repository Automation Pipeline (Makefile Wrapper)
# Description:   Provides unified shorthand command layers for docker orchestration,
#                system filesystem verification, environment setup, and trees.
# ==============================================================================

MAKEARGS = $(filter-out $@,$(MAKECMDGOALS))
MAKEDIR := ${CURDIR}
MAKEFLAGS += --silent

# Host environment mapping
HOST_GID = $(shell id -g)
HOST_UID = $(shell id -u)

# Orchestration layout constants
COMPOSE_FILE := ./docker/docker-compose.yml
COMPOSE_CMD  := docker compose -f $(COMPOSE_FILE)
SERVICE_NAME := traefik

.PHONY: help _docker_check_volumes _docker_check_yaml _docker_check \
        docker-build docker-up docker-down docker-start docker-stop \
        docker-restart docker-ps docker-logs docker-shell docker-root \
        tree tree-dump \
        git-clean git-sync git-status

# Default command target
help: ## Display this automated help breakdown panel
	@echo "Available management commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ----------------------------------------------------------------
# Infrastructure Checks (Internal Engines)
# ----------------------------------------------------------------

_docker_check_volumes:
	mkdir -p ./docker/volumes/traefik_config || true
	mkdir -p ./docker/volumes/traefik_certs || true

_docker_check_yaml:
	if [ ! -f $(COMPOSE_FILE) ]; then cp -f ./docker/docker-compose.socket-root.yml $(COMPOSE_FILE); fi

_docker_check: _docker_check_volumes _docker_check_yaml

# ----------------------------------------------------------------
# Docker Container Orchestration
# ----------------------------------------------------------------

docker-build: _docker_check_yaml ## Compile dynamic container image layouts natively without cache layers
	$(COMPOSE_CMD) build --build-arg "TRAEFIK_GID=$(HOST_GID)" --build-arg "TRAEFIK_UID=$(HOST_UID)" --no-cache

docker-up: _docker_check ## Initiate background infrastructure services tracking
	$(COMPOSE_CMD) up -d

docker-down: _docker_check_yaml ## Teardown routing architecture layers and stop tracking processes
	$(COMPOSE_CMD) down

docker-clean: _docker_check_yaml ## Teardown infrastructure and aggressively prune anonymous volumes
	$(COMPOSE_CMD) down -v --remove-orphans

docker-start: _docker_check_yaml ## Wake suspended container resources
	$(COMPOSE_CMD) start

docker-stop: _docker_check_yaml ## Suspend actively running daemon runtimes
	$(COMPOSE_CMD) stop

docker-restart: _docker_check_yaml ## Bounce running components sequence
	$(COMPOSE_CMD) restart

docker-ps: _docker_check_yaml ## Inspect isolated application layout status state trees
	$(COMPOSE_CMD) ps

docker-logs: _docker_check_yaml ## Attach telemetry output stream logs to stdout
	$(COMPOSE_CMD) logs -f

docker-config: _docker_check_yaml ## Validate and render the compiled Docker Compose syntax and environments
	$(COMPOSE_CMD) config

docker-events: _docker_check_yaml ## Stream real-time engine events from the orchestrated infrastructure
	$(COMPOSE_CMD) events

docker-prune: ## Globally clean unused system-wide docker caches, networks, and dangled layers
	docker system prune -a --volumes -f

# ----------------------------------------------------------------
# Runtime Shell Access Gateways
# ----------------------------------------------------------------

docker-shell: _docker_check_yaml ## Spawn standard unprivileged shell process inside the proxy container
	$(COMPOSE_CMD) exec $(SERVICE_NAME) sh

docker-root: _docker_check_yaml ## Spawn escalated root security session inside the proxy container
	$(COMPOSE_CMD) exec -u root $(SERVICE_NAME) sh

# ----------------------------------------------------------------
# Git Automation Utilities
# ----------------------------------------------------------------

git-clean: ## Aggressively prune local branches that do not exist on origin remote
	echo "Fetching latest remote state and pruning gone tracking references..."
	git fetch -p
	echo "Identifying and deleting abandoned local branches..."
	# Capture explicitly gone branches first
	git branch -vv | grep ': gone]' | awk '{print $$1}' | xargs -r git branch -D
	echo "Syncing structural branch list against actual remote tracking trees..."
	# Dynamic check: loops through all local branches and deletes if missing in origin
	for branch in $$(git branch | awk '{print $$1}' | grep -E -v "(^\*|master|main)"); do \
		if ! git show-ref --verify --quiet refs/remotes/origin/$$branch; then \
			echo "Removing un-tracked or deleted local asset: $$branch"; \
			git branch -D $$branch; \
		fi; \
	done

git-sync: git-clean ## Fetch remote updates and pull current branch changes cleanly
	echo "Syncing active branch with upstream..."
	git pull

git-status: ## Display a highly compressed, clean repository status overview
	git status -s -b

# ----------------------------------------------------------------
# System Utilities
# ----------------------------------------------------------------

tree: ## Map repository directory layout architecture nodes ignoring heavy untracked spaces
	tree -a -I '.git|.idea|volumes|tmp'

tree-dump: ## Export active tree mappings structurally into an isolated diagnostic asset file
	mkdir -p ./tmp
	tree -a -I '.git|.idea|volumes|tmp' > ./tmp/tree.txt

# Catch-all rule execution bypass to tolerate loose trailing parameters
%:
	@:
