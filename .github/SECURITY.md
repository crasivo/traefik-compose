# Security Policy

We take the security of the **Traefik Compose** stack seriously. Because this stack manages core traffic routing and requires
access to your containerization API (Docker/Podman), implementing a securely hardened environment configuration is of paramount
importance.

---

## 🛡️ Supported Versions

Security updates and vulnerability patches are delivered exclusively to the current active branch of the repository.

| Version              | Supported               |
|:---------------------|:------------------------|
| Active (Main / v3.x) | Supported (Recommended) |
| < 3.0                | ❌ Not Supported         |

---

## 🔒 Architectural Security: Critical Warnings

The project provides 4 distinct deployment modes offering varying levels of isolation. When selecting your environment layout,
please adhere strictly to the following security principles:

### 1. TCP-based Network Modes — `docker-compose.tcp-*.yml`

* **Threat:** Configuring your Docker daemon to listen on the public `0.0.0.0:2375` interface grants unauthenticated root access
  to your entire host system over the network.
* **Mitigation:** You **must** configure a host-level system firewall (such as UFW, firewalld, or nftables) so that incoming
  packets to port `2375` are dropped for all external network interfaces and explicitly permitted only for the local Docker bridge
  subnet (typically the `docker0` interface).

### 2. Socket-based Modes — `docker-compose.socket-*.yml`

* **Threat:** Mounting the standard host UNIX socket file `/var/run/docker.sock` in a `root` (0:0) capacity allows an attacker—if
  the Traefik container becomes compromised—to execute a container breakout onto the host system with full superuser privileges.
* **Mitigation:** For production environments, always opt for **Rootless modes** (TCP or Socket), where the proxy process runs
  inside the container under the unprivileged `traefik` user space (UID 1000).

---

## 🛠️ Local PKI Security (`openssl-generate.sh`)

The certificate generation engine executing inside the container's `ENTRYPOINT` provisions a private cryptographic key for your
custom local Root CA.

* **Never** commit or push generated keypairs from the `./docker/volumes/traefik_certs/` path into public Git repositories. The
  `volumes/` directory is excluded by default via `.gitignore`.
* Keep in mind that appending the **Crasivo Root CA** certificate to your operating system or browser's trusted root authority
  store empowers that local CA to sign certificates for any domain name on your local machine. Use it strictly for sandbox/offline
  development utilities.

---

## 🐛 Reporting a Vulnerability

If you discover a security flaw within the configuration layers, bootstrap macro-scripts, or base image structural choices of this
repository, please **do not open a public Issue**.

Instead, utilize one of the following secure communication channels:

1. **GitHub Security Advisories:** Navigate to the *Security* tab of this repository, select *Advisories*, and click *Report a
   vulnerability*. This allows us to safely discuss and patch the issue in a private workspace.
2. **Direct Contact:** Email a comprehensive vulnerability summary alongside a reproducible Proof of Concept (PoC) to the
   repository owner's email address (visible on the GitHub profile) or reach out via technical profile channels.

We commit to reviewing and coordinating an initial response to your disclosure within **48 hours**.

---

## 🛡️ Baseline Dependency Auditing

Since this deployment configuration relies on the upstream official Traefik binary and the Alpine Linux base layers, we recommend
performing regular maintenance pulling to keep image footprints secure:

```bash
# Rebuild the stack while forcing upstream layer updates
docker compose pull
docker compose build --no-cache
docker compose up -d
```
