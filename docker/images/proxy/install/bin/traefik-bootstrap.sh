#!/bin/sh

# ==============================================================================
# Script Name:  traefik-bootstrap.sh
# Description:  Bootstraps the Traefik configuration directory by ensuring
#               required files exist and dynamically interpolates environment
#               variables into YAML configurations using a %VAR% macro template.
#
# Usage:        ./traefik-bootstrap.sh
# ==============================================================================

set -o nounset
set -o errexit

# ----------------------------------------------------------------
# Environments
# ----------------------------------------------------------------

TARGET_CONF_DIR="/etc/traefik"
SOURCE_CONF_DIR="/opt/docker/etc/traefik"

# ----------------------------------------------------------------
# Functions
# ----------------------------------------------------------------

##
# @description Ensures that the core configuration file (traefik.yml) and the
#              dynamic configuration directory (conf.d) exist in the target
#              path. Copies them from the source directory if missing.
#
# @global TARGET_CONF_DIR String Path to the active Traefik configuration.
# @global SOURCE_CONF_DIR String Path to the fallback template configuration.
#
# @return 0 If the files are present or successfully copied.
##
_traefik_copy_configs() {
    # 1. Ensure target base directory exists
    mkdir -p "$TARGET_CONF_DIR"

    # 2. Copy dynamic configurations directory properly without nested folder bug
    if [ ! -d "$TARGET_CONF_DIR/conf.d" ]; then
        echo "ℹ️ Dynamic configuration folder missing. Copying to $TARGET_CONF_DIR/conf.d"
        cp -ar "$SOURCE_CONF_DIR/conf.d" "$TARGET_CONF_DIR/"
    fi

    # 3. Check and copy main configuration file
    if [ ! -f "$TARGET_CONF_DIR/traefik.yml" ]; then
        echo "ℹ️ Main configuration file missing. Copying to $TARGET_CONF_DIR/traefik.yml"
        cp -f "$SOURCE_CONF_DIR/traefik.yml" "$TARGET_CONF_DIR/traefik.yml"
    fi
}

##
# @description Iterates over all active environment variables, detects their
#              keys and values, and replaces occurrences of %KEY% inside all
#              YAML files located within the target configuration directory.
#
# @global TARGET_CONF_DIR String Path to the target directory containing YAMLs.
#
# @return 0 If token replacement completes without errors.
##
_traefik_replace_env_macros() {
    echo "ℹ️ Starting dynamic template interpolation for YAML files..."

    # Extract all exported environment variables using the 'env' command.
    env | while IFS= read -r env_var; do
        # Safely split the environment variable into Key and Value
        key="${env_var%%=*}"
        val="${env_var#*=}"

        # Skip processing if the variable key is empty
        if [ -z "$key" ]; then
            continue
        fi

        # Find all .yaml and .yml files recursively in the target directory
        find "$TARGET_CONF_DIR" -type f \( -name "*.yaml" -o -name "*.yml" \) | while read -r yaml_file; do
            # Escape value for sed (handles slashes, backslashes, and ampersands)
            escaped_val=$(echo "$val" | sed 's/[\/&]/\\&/g')

            # Perform inline substitution using a temporary file for POSIX sh compliance
            sed "s/%${key}%/${escaped_val}/g" "$yaml_file" > "${yaml_file}.tmp"
            mv -f "${yaml_file}.tmp" "$yaml_file"
        done
    done

    echo "🎉 Configuration template interpolation completed successfully."
}

# ----------------------------------------------------------------
# Runtime
# ----------------------------------------------------------------

# 1. Check & copy configs
_traefik_copy_configs

# 2. Interpolate macros from environment variables
_traefik_replace_env_macros
