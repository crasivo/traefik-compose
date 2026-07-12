🚢 Traefik Compose
===

<p align="left">
  <a href="https://github.com/crasivo/traefik-compose/actions/workflows/build_alpine.yml">
    <img src="https://github.com/crasivo/traefik-compose/actions/workflows/build_alpine.yml/badge.svg" alt="Build Status">
  </a>
  <img src="https://img.shields.io/badge/Traefik-v3.x-blue?logo=traefik" alt="Traefik Version">
  <a href="https://github.com/crasivo/traefik-compose/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
  </a>
  <img src="https://img.shields.io/badge/Architecture-Rootless%2FTCP%2FSocket-orange" alt="Architecture">
</p>

A production-ready, security-hardened [Traefik Proxy](https://traefik.io/traefik) stack tailored for local development and web
application deployment in Docker and Podman environments.

This stack is powered by a **hardened, rootless Alpine Linux base image** featuring automated local PKI/OpenSSL generation and
built-in configuration macro bootstrapping.

---

## 🛠 Deployment Options & Network Modes

Depending on your infrastructure security constraints and container daemon setup, the repository natively supports **4
architectural running modes**:

1. **TCP Rootless (`docker-compose.tcp-rootless.yml`)** — *Default Mode*. Maximum isolation: the container runs under the
   unprivileged `traefik` user (UID 1000) and communicates with the Docker API over the network via TCP port `2375`, removing any
   need for mounting raw socket files.
2. **TCP Root (`docker-compose.tcp-root.yml`)** — The container runs as `root` but maintains strict filesystem isolation from the
   host by communicating exclusively via TCP.
3. **Socket Rootless (`docker-compose.socket-rootless.yml`)** — A secure setup that forwards the host's unprivileged user-space
   UNIX socket (`/run/user/1000/docker.sock`).
4. **Socket Root (`docker-compose.socket-root.yml`)** — The classical approach mounting the standard host `/var/run/docker.sock`
   path.

> 💡 *For a comprehensive technical breakdown of each mode, Podman compatibility tricks, and mandatory Systemd/Firewall host
adjustments for TCP setups, check out the dedicated documentation: [**docker/README.md**](docker/README.md).*

---

## 🚀 Quick Start

### Step 1: Provision the External Network

To allow your application containers to securely communicate with the proxy, you must first provision a shared external bridge
network named `traefik_public`:

```shell
$ docker network create \
  --driver=bridge \
  --subnet=172.30.100.0/24 \
  --ip-range=172.30.100.0/24 \
  --gateway=172.30.100.1 \
  traefik_public
```

Additionally, ensure that ports `80` and `443` are free on your host system (stop any local instances of Nginx, Apache, or Caddy).

### Step 2: Choose a Mode and Boot the Stack

Navigate to the `docker/` directory, create a symbolic link targeting your desired configuration, and spin up the container:

```shell
$ cd docker

# Select your preferred layout (e.g., tcp-rootless)
$ ln -sf docker-compose.tcp-rootless.yml docker-compose.yml

# Build and start the stack
$ docker compose up -d --build
```

Once up and running, the Traefik API/Dashboard will become available at:

* http://localhost *(Direct access without DNS mapping)*
* http://traefik.docker *(Requires DNS/hosts mapping)*

---

## 🕹️ Operations Guide

If you are new to Traefik, it is highly recommended to look over
the [official Traefik Docker Provider documentation](https://doc.traefik.io/traefik/master/expose/docker/) first.

### 🔐 SSL Certificates (Local PKI)

This stack completely discards Traefik's standard default fallback certificates. Instead, every time the container starts up, the
custom macro-script `openssl-generate.sh` is automatically executed within the `ENTRYPOINT` pipeline.

This script spins up a full-fledged local Public Key Infrastructure (PKI) and generates valid SSL certificates on the fly for the
following targets:

* **Crasivo Root CA** — Your own private trusted Root Certificate Authority (the generator of the trust chain).
* **Localhost** — Covering the standalone `localhost` domain.
* **Default / Fallback** — A global universal fallback certificate for incoming requests matching no specific host.
* **Dynamic Host** — A dedicated wildcard certificate automatically provisioned for the domain name passed via the `VIRTUAL_HOST`
  environment variable (defaults to `*.traefik.docker`).

#### 📥 How to Retrieve and Trust the Root Certificate

Thanks to the automated directory mapping declared in the compose files, the freshly minted root certificate can easily be pulled
straight from the host-mounted volume:
👉 Host Path: `./docker/volumes/traefik_certs/root/certificate.pem`

To prevent your operating system, command-line utilities (like curl, wget), and internal application containers from throwing
annoying security alerts or SSL Handshake errors, register the **Crasivo Root CA** certificate inside your system store:

```shell
# Alpine Linux
$ sudo apk add ca-certificates$ sudo cp -f ./docker/volumes/traefik_certs/root/certificate.pem /etc/ssl/certs/Crasivo_Root_CA.crt
$ sudo update-ca-certificates

# Debian / Ubuntu
$ sudo apt-get install -y ca-certificates$ sudo cp -f ./docker/volumes/traefik_certs/root/certificate.pem /usr/local/share/ca-certificates/Crasivo_Root_CA.crt
$ sudo update-ca-certificates

# CentOS / Fedora / RHEL
$ sudo yum install ca-certificates$ sudo cp -f ./docker/volumes/traefik_certs/root/certificate.pem /etc/pki/ca-trust/source/anchors/Crasivo_Root_CA.crt
$ sudo update-ca-trust
```

#### Importing to Browsers and Graphical GUIs:

* **Apple macOS:** Double-click the `certificate.pem` file, add it to the *System* keychain using *Keychain Access*, and change
  its trust permissions explicitly to *«Always Trust»*.
* **Microsoft Windows:** Open the certificate file -> Click *«Install Certificate»* -> Select *Local Machine* -> Place the
  certificate strictly into the *«Trusted Root Certification Authorities»* store.
* **Browsers (Google Chrome, Firefox, etc.):** Modern, fully-featured browsers often deliberately bypass Linux system-wide CA
  stores. To secure the highly-coveted "green lock" icon, navigate to your browser's internal security settings, locate the
  *«Certificates -> Authorities»* tab, and manually import the `certificate.pem` file there.

Example of automatically baking and trusting your local root CA authority inside a custom `Dockerfile` (Alpine-based) for the
downstream applications you build:

```dockerfile
FROM alpine
# Copy the generated root CA file from the build context
ADD ./docker/volumes/traefik_certs/root/certificate.pem /etc/ssl/certs/traefik_root_ca.crt
RUN set -eux \
    && apk add ca-certificates \
    && update-ca-certificates
```

#### Importing to Browsers and Other Operating Systems:

* **macOS:** Open *Keychain Access*, drag and drop the root certificate into the System keychain, and toggle its trust settings to
  *«Always Trust»*.
* **Windows:** Double-click the `*.pem` file -> Install Certificate -> Place all certificates in the *«Trusted Root Certification
  Authorities»* store.
* **Browsers (Chrome/Firefox):** If your browser bypasses system-level anchors, import the certificate manually through the
  browser security preferences under *«Certificates -> Authorities»*.

Example of incorporating the trusted root CA directly into a custom Alpine-based `Dockerfile` layout:

```dockerfile
FROM alpine
ADD /path/to/root/certificate.pem /etc/ssl/certs/traefik_root_ca.crt
RUN set -eux \
    && apk add ca-certificates \
    && update-ca-certificates
```

### 🌐 DNS Mapping

To reach custom local routing zones (`*.docker`, `*.local`) in your browser, your host machine must know how to properly resolve
those domains.

1. **Recommended Method (Infrastructure-level):** Set up a lightweight local DNS forwarding server like `dnsmasq` to catch all
   queries belonging to these top-level domains and route them straight to `127.0.0.1`.
2. **Simple Method (Manual):** Add explicit static entries directly to your host's system `hosts` file (`/etc/hosts` on Unix
   systems or `C:\Windows\System32\drivers\etc\hosts` on Windows platforms):

```text
127.0.0.1 localhost
127.0.0.1 traefik.docker
127.0.0.1 subdomain.traefik.docker
127.0.0.1 custom.docker
```

---

## 📜 License

This project is distributed under the terms of the [MIT License](https://en.wikipedia.org/wiki/MIT_License). The complete license
text is available in the [LICENSE](LICENSE) file located at the root of this repository.
