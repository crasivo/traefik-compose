# Deployment Options and Network Modes for Traefik Proxy

This repository supports **4 architectural execution modes** depending on your infrastructure security requirements (Root vs
Rootless) and the mechanism used to communicate with the container daemon (UNIX Socket vs TCP Port).

By default, the `docker-compose.yml` symbolic link points to the most secure and isolated setup:
`docker-compose.tcp-rootless.yml`.

---

## 🛠 Mode Compatibility Matrix

| Configuration File                       | Daemon (Host)   | Container        | Communication Method        | Security Level | Features / Notes                                                               |
|:-----------------------------------------|:----------------|:-----------------|:----------------------------|:---------------|:-------------------------------------------------------------------------------|
| **`docker-compose.socket-root.yml`**     | Root Docker     | `root` (0:0)     | `/var/run/docker.sock`      | ⚠️ Low         | Classical mode. Convenient for local testing, dangerous in production.         |
| **`docker-compose.socket-rootless.yml`** | Rootless Docker | `traefik` (1000) | `.../user/1000/docker.sock` | 🔒 High        | Forwards the host's user-space socket without root privileges.                 |
| **`docker-compose.tcp-root.yml`**        | Root Docker     | `root` (0:0)     | TCP Port (`2375`)           | 🛡 Medium      | Complete isolation from the host filesystem. Requires Firewall/TLS protection. |
| **`docker-compose.tcp-rootless.yml`**    | Rootless/Root   | `traefik` (1000) | TCP Port (`2375`)           | 🛑 Maximum     | **Hardened Mode**. No root privileges, no direct access to socket files.       |

---

## 📑 Detailed Mode Breakdown & Configuration

### 1. Socket-based Modes

Interaction with the Docker API happens via a standard UNIX socket file. This guarantees maximum performance but introduces
specific permission constraints.

#### A. Standard Root Mode (`docker-compose.socket-root.yml`)

The container runs as `root` and mounts the socket directly from the host system:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

> ⚠️ **WARNING:** If an attacker compromises the Traefik container, having access to the root socket allows them to break out onto
> the host system with full root privileges. It is highly recommended to use this mode only in isolated development environments.

#### B. User-space Rootless Mode (`docker-compose.socket-rootless.yml`)

When Docker is configured in Rootless mode on the host, the standard `/var/run/docker.sock` file does not exist. The daemon spins
up a socket inside the user space (UID 1000).
The configuration maps this user-specific socket:

```yaml
volumes:
  - /run/user/1000/docker.sock:/var/run/docker.sock:ro
```

* **Access Permissions:** The container runs under the `user: traefik` directive. Since the host user UID and the container user
  UID match (1000), Traefik has legitimate read/write permissions for the socket without requiring hacks like `group_add`.

---

### 2. TCP-based Network Modes

These configurations allow you to completely isolate the container from the host filesystem. Connection to the Docker API is
established via TCP over port `2375`. This eliminates any risks associated with mounting raw socket files.

#### 🚨 CRITICAL: Host Systemd Pre-configuration

By default, the Docker daemon listens exclusively to the local UNIX socket. Trying to bind the TCP port strictly to `127.0.0.1`
will cause containers running in virtual bridge networks (e.g., `172.17.0.1`) to fail when connecting to the host, as the Linux
kernel drops cross-interface loopback traffic.

To make it work seamlessly, Docker must be configured to listen on the `0.0.0.0` interface, heavily backed by firewall rules.

**Step-by-Step Guide:**

1. Open the service override file:
   ```bash
   sudo systemctl edit docker.service
   ```
2. Paste the following configuration block, resetting default execution flags:
   ```ini
   [Service]
   ExecStart=
   ExecStart=/usr/bin/dockerd -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375 --containerd=/run/containerd/containerd.sock
   ```
3. Stop and disable the built-in systemd socket activator to avoid initialization locks on the socket file:
   ```bash
   sudo systemctl stop docker.socket
   ```
4. Reload systemd configurations and restart the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart docker
   ```

> 🔒 **SECURITY NOTE (CRITICAL):** Since port `2375` is now bound to `0.0.0.0`, it is exposed to all interfaces. If your server has
> a public IP address, you **must** drop incoming external packets to this port via a firewall!
> * For **UFW** (Ubuntu default): `sudo ufw deny 2375/tcp` (UFW allows internal bridge traffic via `docker0` out of the box,
    letting Traefik connect while blocking external attacks).
> * For **nftables / firewalld**: Ensure that port `2375` is explicitly allowed only for the `docker0` zone.

Once the host is ready, the `host-gateway` macro in `docker-compose.tcp-*.yml` files will automatically resolve the correct host
bridge IP inside the container:

```yaml
environment:
  - "TRAEFIK_PROVIDERS_DOCKER_ENDPOINT=[http://host.docker.internal:2375](http://host.docker.internal:2375)"
extra_hosts:
  - "host.docker.internal:host-gateway"
```

---

## 🦫 Working with Podman

If you choose **Podman** as your container engine instead of Docker, interacting with rootless sockets is natively simplified but
introduces distinct environment quirks.

### Activating the Podman Socket Service

Podman operates without a persistent background daemon. To expose an API socket for Traefik, you must activate the user-space
socket service:

```bash
# Start the socket service in user space (Rootless)
systemctl --user enable --now podman.socket

# Verify the runtime socket path
echo $XDG_RUNTIME_DIR/podman/podman.sock
```

### Adjusting `docker-compose.yml` for Podman:

1. Select the `docker-compose.socket-rootless.yml` template.
2. Point the host volume mount path to your active Podman socket:
   ```yaml
   volumes:
     - /run/user/1000/podman/podman.sock:/var/run/docker.sock:ro
   ```
3. **SELinux Security Contexts:** If you are running on RHEL/Fedora/CentOS, append the `:z` or `:Z` flag to your configuration and
   socket volume declarations so Podman can automatically adjust SELinux label contexts.
4. The environment variable `TRAEFIK_PROVIDERS_DOCKER_ENDPOINT=/var/run/docker.sock` remains intact, as Podman fully emulates the
   Docker API standard.

---

## 🚀 Quick Start

1. Choose your preferred environment mode (e.g., TCP Rootless) and update the symbolic link:
   ```bash
   ln -sf docker-compose.tcp-rootless.yml docker-compose.yml
   ```
2. Make sure your external public bridge network is provisioned:
   ```bash
   docker network create traefik_public
   ```
3. Boot up the stack:
   ```bash
   docker compose up -d --build
   ```
