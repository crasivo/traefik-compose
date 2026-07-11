---
name: 🐛 Bug Report
about: Report a bug or issue within the Traefik Compose deployment
title: '[BUG] '
labels: bug
assignees: ''
---

## 📝 Bug Description

A clear and concise description of what the bug is.

## 🛠 Environment & Deployment Mode

Please select the active configuration layout you are using (from the `docker/` path):

- [ ] `docker-compose.tcp-rootless.yml` (TCP, unprivileged traefik user)
- [ ] `docker-compose.tcp-root.yml` (TCP, root user)
- [ ] `docker-compose.socket-rootless.yml` (User-space UNIX socket)
- [ ] `docker-compose.socket-root.yml` (Standard host /var/run/docker.sock)

**Runtime Details:**

- Container Engine: [ ] Docker / [ ] Podman
- Docker/Podman version (`docker --version`):
- Host OS (Ubuntu 24.04, Arch, RHEL, etc.):
- CPU Architecture ([ ] x86_64 / [ ] ARM64)

## 🔍 Steps to Reproduce

1. Exact execution command used (e.g., `docker compose up -d --build`):
2. Target application labels (if applicable):
3. What went wrong?

## 📋 Traefik Container Logs

Paste the output logs from the container (`docker compose logs traefik`) showing the failure context:

```text
// Paste logs here
```

## 🔐 Is the issue related to SSL / PKI?

If the error targets the local certificate generation pipeline (`openssl-generate.sh`), please specify:

- What is the value assigned to your `VIRTUAL_HOST` environment variable?
- Does the error trip inside the browser or during container compilation?

## 💡 Expected Behavior

A clear and concise description of what you expected to happen.
