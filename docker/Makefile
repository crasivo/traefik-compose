MAKEARGS = $(filter-out $@,$(MAKECMDGOALS))
MAKEFLAGS += --silent

# Docker context
DOCKER_MAKEFILE = $(abspath $(lastword $(MAKEFILE_LIST)))
DOCKER_DIR = $(patsubst %/,%,$(dir $(DOCKER_MAKEFILE)))

# Traefik network
TRAEFIK_NETWORK_NAME = traefik_public
TRAEFIK_NETWORK_UID = $(shell docker network ls -f name=$(TRAEFIK_NETWORK_NAME) -q)

# Default command for 'make'
_list_docker_commands:
	sh -c "echo 'Available commands:'; $(MAKE) -p no_targets__ | awk -F':' '/^[a-zA-Z0-9][^\$$#\/\\t=]*:([^=]|$$)/ {split(\$$1,A,/ /);for(i in A)print A[i]}' | grep -v '__\$$' | grep -v 'Makefile'| sort"

# ----------------------------------------------------------------
# Docker: Compose
# ----------------------------------------------------------------

_docker_check_yaml:
	if [ ! -f $(DOCKER_DIR)/docker-compose.yml ]; then ln -sf $(DOCKER_DIR)/docker-compose.example.yml $(DOCKER_DIR)/docker-compose.yml; fi
_docker_check_network:
	if [ -z "$(TRAEFIK_NETWORK_UID)" ]; then docker network create -d bridge $(TRAEFIK_NETWORK_NAME); fi
_docker_check: \
	_docker_check_network \
	_docker_check_yaml

docker-build: _docker_check_yaml
	docker compose -f $(DOCKER_DIR)/docker-compose.yml build --no-cache
docker-up: _docker_check
	docker compose -f $(DOCKER_DIR)/docker-compose.yml up -d
docker-down: _docker_check
	docker compose -f $(DOCKER_DIR)/docker-compose.yml down
docker-start: _docker_check
	docker compose -f $(DOCKER_DIR)/docker-compose.yml start
docker-stop: _docker_check
	docker compose -f $(MAKEFILE_PATH)/docker-compose.yml stop
docker-rm: _docker_check
	docker compose -f $(MAKEFILE_PATH)/docker-compose.yml rm --force --stop

# Final
docker-run: \
	docker-build \
	docker-up

# Fix arguments
%:
	@:
