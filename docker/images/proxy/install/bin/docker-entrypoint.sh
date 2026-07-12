#!/bin/sh

set -o nounset
set -o errexit

# ----------------------------------------------------------------
# Runtime
# ----------------------------------------------------------------

# Execute entrypoint scripts
if [ -d '/docker-entrypoint.d' ]; then
  for s in $(find '/docker-entrypoint.d' -maxdepth 1 -name '*.sh' | sort); do
    if [ -x "$s" ]; then
      echo "[INFO] Docker entrypoint: Executing script ${s##*/}"
      "$s" || true
    fi
  done
fi

# Execute CMD
echo "[INFO] Docker entrypoint: Execute command - $*"
exec "$@"
