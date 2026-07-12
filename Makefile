MAKEARGS = $(filter-out $@,$(MAKECMDGOALS))
MAKEDIR := ${CURDIR}
MAKEFLAGS += --silent

HOST_GID = $(shell id -g)
HOST_UID = $(shell id -u)

# Default command for 'make'
_list_commands:
	sh -c "echo 'List commands:'; $(MAKE) -p no_targets__ | awk -F':' '/^[a-zA-Z0-9][^\$$#\/\\t=]*:([^=]|$$)/ {split(\$$1,A,/ /);for(i in A)print A[i]}' | grep -v '__\$$' | grep -v 'Makefile'| sort"

# ----------------------------------------------------------------
# Docker
# ----------------------------------------------------------------

# Check
_docker_check_volumes:
	mkdir -p ./docker/volumes/traefik_config || true
	mkdir -p ./docker/volumes/traefik_certs || true
_docker_check_yaml:
	if [ ! -f ./docker/docker-compose.yml ]; then cp -f ./docker/docker-compose.socket-root.yml ./docker/docker-compose.yml; fi
_docker_check: \
	_docker_check_volumes \
	_docker_check_yaml

# General
docker-build: _docker_check_yaml
	docker compose -f ./docker/docker-compose.yml build --build-arg "TRAEFIK_GID=$(HOST_GID)" --build-arg "TRAEFIK_UID=$(HOST_UID)" --no-cache
docker-up: _docker_check
	docker compose -f ./docker/docker-compose.yml up -d
docker-down: _docker_check_yaml
	docker compose -f ./docker/docker-compose.yml down
docker-start: _docker_check_yaml
	docker compose -f ./docker/docker-compose.yml start
docker-stop: _docker_check_yaml
	docker compose -f ./docker/docker-compose.yml stop
docker-restart: _docker_check_yaml
	docker compose -f ./docker/docker-compose.yml restart
docker-ps: _docker_check_yaml
	docker compose -f ./docker/docker-compose.yml ps
docker-logs: _docker_check_yaml
	docker compose -f ./docker/docker-compose.yml logs -f

# Shell
docker-shell: _docker_check_yaml
	docker compose -f ./docker/docker-compose.yml exec server sh
docker-root: _docker_check_yaml
	docker compose -f ./docker/docker-compose.yml exec -u root server sh

# ----------------------------------------------------------------
# Utils
# ----------------------------------------------------------------

# Utils
tree:
	tree -I '.git|.idea|.vscode|build|dist|generated|node_modules'
tree-dump:
	mkdir -p ./tmp
	tree -I '.git|.idea|.vscode|build|dist|generated|node_modules' > ./tmp/tree.txt

# Fix arguments
%:
	@:
