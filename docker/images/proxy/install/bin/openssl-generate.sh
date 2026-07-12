#!/bin/sh

# ==============================================================================
# Script Name:  openssl-generate.sh
# Description:  Automates the generation of a self-signed local Public Key
#               Infrastructure (PKI). Generates a dedicated Root CA, a fallback
#               default certificate, and a dynamic Wildcard domain certificate
#               with appropriate Subject Alternative Name (SAN) extensions.
#               Ideal for containerized reverse proxies (e.g., Traefik, Nginx).
#
# Usage:        ./openssl-generate.sh [domain_name]
#               Examples:
#                 ./openssl-generate.sh                 # Uses default 'localhost'
#                 ./openssl-generate.sh example.local   # Generates for *.example.local
# ==============================================================================

set -o nounset
set -o errexit

# ----------------------------------------------------------------
# Environments
# ----------------------------------------------------------------

OPENSSL_CONFIG_FILEPATH=${OPENSSL_CONFIG_FILEPATH:-/opt/docker/etc/ssl/openssl.cnf}
OPENSSL_SHARE_DIR=${OPENSSL_SHARE_DIR:-/opt/docker/share/openssl}
OPENSSL_CERT_DAYS=${OPENSSL_CERT_DAYS:-3650}
OPENSSL_CERT_HOST=${OPENSSL_CERT_HOST:-localhost}
OPENSSL_ROOT_CN=${OPENSSL_ROOT_CN:-SelfSignedRootCA}
OPENSSL_ROOT_DAYS=${OPENSSL_ROOT_DAYS:-3650}

# ----------------------------------------------------------------
# Functions
# ----------------------------------------------------------------

##
# @description Generates the Root Certificate Authority (Root CA) private key
#              and x509 certificate if they do not already exist.
#
# @global OPENSSL_SHARE_DIR String Path to the base share directory.
# @global OPENSSL_CONFIG_FILEPATH String Path to the custom openssl.cnf file.
# @global OPENSSL_ROOT_DAYS Identity/String Validity period of Root CA in days.
# @global OPENSSL_ROOT_CN String Common Name (CN) for the Root CA.
#
# @return 0 If generation succeeds or files already exist.
# @return 1 If any OpenSSL generation command fails.
##
_openssl_gen_root() {
    output_dir="$OPENSSL_SHARE_DIR/root"
    mkdir -p "$output_dir"

    if [ -f "$output_dir/private_key.pem" ] && [ -f "$output_dir/certificate.pem" ]; then
        echo "ℹ️ Root CA private key and certificate already exist. Skipping..."
        return 0
    fi

    echo "ℹ️ Generating Root Certificate Authority (Root CA)..."

    config_opt=""
    if [ -f "$OPENSSL_CONFIG_FILEPATH" ]; then
        config_opt="-config $OPENSSL_CONFIG_FILEPATH"
    fi

    openssl req \
        -x509 \
        -new \
        -nodes \
        -sha512 \
        -days "$OPENSSL_ROOT_DAYS" \
        -newkey rsa:4096 \
        $config_opt \
        -extensions v3_ca \
        -subj "/O=Acme Inc./OU=DevOps/CN=$OPENSSL_ROOT_CN" \
        -keyout "$output_dir/private_key.pem" \
        -out "$output_dir/certificate.pem"
}

##
# @description Generates an RSA private key, a CSR, and signs a dynamic
#              Wildcard certificate using the local Root CA. Includes
#              Subject Alternative Name (SAN) extensions for both the base
#              domain and its first-level wildcards (*.domain).
#              Assembles the final certificate chain into fullchain.pem.
#
# @param 1 String The target domain name (e.g., "example.local").
#
# @global OPENSSL_SHARE_DIR String Path to the base share directory.
# @global OPENSSL_CERT_DAYS Identity/String Validity period of the domain certificate.
#
# @return 0 If the certificate chain is generated successfully.
# @return 1 If the Root CA components are missing or signing fails.
##
_openssl_gen_domain() {
    domain="$1"
    root_dir="$OPENSSL_SHARE_DIR/root"
    output_dir="$OPENSSL_SHARE_DIR/$domain"

    if [ ! -f "$root_dir/certificate.pem" ] || [ ! -f "$root_dir/private_key.pem" ]; then
        echo "🚨 Failed to locate Root CA certificate or private key."
        return 1
    fi

    mkdir -p "$output_dir"

    # 1. Generate the domain private key
    if [ ! -f "$output_dir/private_key.pem" ]; then
        echo "ℹ️ Generating private key for domain: $domain"
        openssl genrsa -out "$output_dir/private_key.pem" 4096
    fi

    # 2. Generate the Certificate Signing Request (CSR)
    if [ ! -f "$output_dir/signing_request.pem" ]; then
        echo "ℹ️ Generating CSR for domain: $domain"
        openssl req \
            -new \
            -nodes \
            -sha512 \
            -subj "/O=Acme Inc./OU=DevOps/CN=*.$domain" \
            -key "$output_dir/private_key.pem" \
            -out "$output_dir/signing_request.pem"
    fi

    # 3. Sign the domain certificate with Subject Alternative Name (SAN) extensions
    if [ ! -f "$output_dir/certificate.pem" ]; then
        echo "ℹ️ Generating Wildcard certificate from CSR for domain: $domain"

        ext_file="$output_dir/v3_ext.cnf"
        {
          echo "authorityKeyIdentifier=keyid,issuer"
          echo "basicConstraints=CA:FALSE"
          echo "keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment"
          echo "subjectAltName = DNS:$domain, DNS:*.$domain"
        } > "$ext_file"

        openssl x509 \
            -req \
            -days "$OPENSSL_CERT_DAYS" \
            -in "$output_dir/signing_request.pem" \
            -CA "$root_dir/certificate.pem" \
            -CAkey "$root_dir/private_key.pem" \
            -CAcreateserial \
            -extfile "$ext_file" \
            -out "$output_dir/certificate.pem"

        rm -f "$ext_file"
    fi

    # 4. Assemble the full certificate chain (fullchain)
    echo "ℹ️ Assembling certificate chain (fullchain) for domain: $domain"
    {
      cat "$output_dir/certificate.pem"
      cat "$root_dir/certificate.pem"
    } > "$output_dir/certificate_fullchain.pem"
}

##
# @description Generates a generic fallback default certificate signed
#              by the local Root CA, typically used by reverse proxies
#              when no matching dynamic domain block is found.
#
# @global OPENSSL_SHARE_DIR String Path to the base share directory.
# @global OPENSSL_CERT_DAYS Identity/String Validity period of the fallback certificate.
#
# @return 0 If the fallback certificate chain is generated successfully.
# @return 1 If the Root CA components are missing or signing fails.
##
_openssl_gen_default() {
    root_dir="$OPENSSL_SHARE_DIR/root"
    output_dir="$OPENSSL_SHARE_DIR/default"

    if [ ! -f "$root_dir/certificate.pem" ] || [ ! -f "$root_dir/private_key.pem" ]; then
        echo "🚨 Failed to locate Root CA certificate or private key."
        return 1
    fi

    mkdir -p "$output_dir"

    # 1. Generate the default private key
    if [ ! -f "$output_dir/private_key.pem" ]; then
        echo "ℹ️ Generating private key for the default certificate"
        openssl genrsa -out "$output_dir/private_key.pem" 4096
    fi

    # 2. Generate the Certificate Signing Request (CSR)
    if [ ! -f "$output_dir/signing_request.pem" ]; then
        echo "ℹ️ Generating CSR for the default certificate"
        openssl req \
            -new \
            -nodes \
            -sha512 \
            -subj "/O=Acme Inc./OU=DevOps/CN=Server Default" \
            -key "$output_dir/private_key.pem" \
            -out "$output_dir/signing_request.pem"
    fi

    # 3. Sign the default certificate
    if [ ! -f "$output_dir/certificate.pem" ]; then
        ext_file="$output_dir/v3_ext.cnf"
        {
          echo "authorityKeyIdentifier=keyid,issuer"
          echo "basicConstraints=CA:FALSE"
          echo "keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment"
        } > "$ext_file"

        echo "ℹ️ Generating the default certificate"
        openssl x509 \
            -req \
            -days "$OPENSSL_CERT_DAYS" \
            -in "$output_dir/signing_request.pem" \
            -CA "$root_dir/certificate.pem" \
            -CAkey "$root_dir/private_key.pem" \
            -CAcreateserial \
            -extfile "$ext_file" \
            -out "$output_dir/certificate.pem"

        rm -f "$ext_file"
    fi

    # 4. Assemble the full certificate chain (fullchain)
    echo "ℹ️ Assembling certificate chain (fullchain) for default certificate."
    {
      cat "$output_dir/certificate.pem"
      cat "$root_dir/certificate.pem"
    } > "$output_dir/certificate_fullchain.pem"
}

# ----------------------------------------------------------------
# Runtime
# ----------------------------------------------------------------

if [ ! -f "$OPENSSL_CONFIG_FILEPATH" ]; then
    echo "⚠️ Configuration file '$OPENSSL_CONFIG_FILEPATH' not found. Falling back to default '/etc/ssl/openssl.cnf'"
    OPENSSL_CONFIG_FILEPATH='/etc/ssl/openssl.cnf'
fi
if [ "$#" -ge 1 ]; then
    echo "ℹ️ Target domain set to: $1"
    OPENSSL_CERT_HOST="$1"
elif [ -n "${VIRTUAL_HOST:-}" ]; then
    echo "ℹ️ Target domain set to: $VIRTUAL_HOST"
    OPENSSL_CERT_HOST="$VIRTUAL_HOST"
fi

# 1. Ensure the Root CA is present
_openssl_gen_root

# 2. Generate the default fallback certificate
_openssl_gen_default

# 3. Generate certificate for localhost
_openssl_gen_domain "localhost"

# 3. Parse OPENSSL_CERT_HOST by comma and generate Wildcard certificates in a loop
# Using a clean POSIX-compliant way to loop over a comma-separated string
echo "$OPENSSL_CERT_HOST" | tr ',' '\n' | while read -r raw_domain; do
    # Strip any accidental leading/trailing spaces around the domain name
    domain=$(echo "$raw_domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip empty items if there were trailing or double commas
    if [ -z "$domain" ] || [ "$domain" = localhost ]; then
        continue
    fi

    _openssl_gen_domain "$domain"
done

echo "🎉 Done! Certificate generation completed successfully."
