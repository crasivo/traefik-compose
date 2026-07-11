---
name: 🔀 Pull Request
about: Template for submitting configuration updates to Traefik Compose
---

## 📝 Description of Changes

Provide a brief summary of the changes introduced by this PR and the specific problem they address.

## 🎯 Type of Change

Check the options that apply:

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] 🚀 New feature or global middleware (Enhancement)
- [ ] 🔒 Security hardening or isolation improvement
- [ ] 📚 Documentation update

## 🛠 Affected Components & Modes

Which environment configurations from the `docker/` path does this PR impact?

- [ ] `docker-compose.tcp-rootless.yml`
- [ ] `docker-compose.tcp-root.yml`
- [ ] `docker-compose.socket-rootless.yml`
- [ ] `docker-compose.socket-root.yml`
- [ ] PKI/SSL generation scripts (`openssl-generate.sh`)
- [ ] Dynamic provider definitions (`http.yml` / `traefik.yml`)

## 🧪 How Was This Tested?

Please describe the tests you ran to verify your changes:

1. What runtime environment was used (Docker / Podman, Host OS)?
2. Does the container successfully init under the unprivileged `traefik` user (UID 1000) when validating Rootless layouts?
3. Did the command `docker compose up -d --build` complete with zero errors?

## 📋 Checklist

- [ ] My changes do not break backward compatibility for existing stack deployments.
- [ ] Volume or mount path hooks (`volumes/`) are correctly declared and do not leak into Git index tracking.
- [ ] Relevant documentation (`README.md` / `README_RU.md`) has been updated or amended accordingly.
