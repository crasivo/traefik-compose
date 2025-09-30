MAKEARGS = $(filter-out $@,$(MAKECMDGOALS))
MAKEFLAGS += --silent

# Default command for 'make'
_list_commands:
	sh -c "echo 'Available commands:'; $(MAKE) -p no_targets__ | awk -F':' '/^[a-zA-Z0-9][^\$$#\/\\t=]*:([^=]|$$)/ {split(\$$1,A,/ /);for(i in A)print A[i]}' | grep -v '__\$$' | grep -v 'Makefile'| sort"

# Docker commands
include ./docker/Makefile

# Fix arguments
%:
	@:
