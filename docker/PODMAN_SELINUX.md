🚧 Podman + Rootless + SELinux
===

When deploying in enterprise distributions, the standard out-of-the-box configuration is guaranteed to run into kernel security
restrictions. The main pitfalls and ways to resolve them are described below.

> ⚠️ **DISCLAIMER:** This material describes the basic limitations of the environment and ways to solve them "head-on" for the
> sake of a quick launch. By applying these instructions, you act at your own risk, fully aware of the consequences for system
> security.

### Typical Rootless Mode Pitfalls

* **Permission Denied on socket/volumes:** SELinux blocks the container's access to host paths, even if `ls -l` permissions are
  set to `777`. The presence of the `subuid/subgid` mechanism in rootless mode remaps the UID (the `traefik` user inside the
  container is not the same as UID `1000` for the host kernel).
* **Container death upon SSH exit:** By default, systemd kills all processes of a rootless user as soon as the terminal session is
  closed.
* **Ports 80 and 443 are blocked:** An unprivileged user cannot bind ports below `1024` by default.

## 🛠 The Path of Compromises (Quick Start "like on desktop")

If you need to deploy the stack quickly in a test/home environment, follow the steps below.

> 🚨 **RISKS:** Disabling SELinux entirely reduces host isolation. If the container is compromised, it will be significantly easier
> for an attacker to escape to the host OS. Opening privileged ports for rootless users theoretically allows any local script to
> occupy the host's web ports.

**Step 1. Disabling SELinux (resolves file/socket permission issues):**

```bash
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sudo reboot
```

**Step 2. Allowing rootless users to bind ports 80 and 443:**

By default, the limit is set to 1024. Let's lower it to 0:

```bash
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=0

# Make the configuration persistent:

echo "net.ipv4.ip_unprivileged_port_start=0" | sudo tee -a /etc/sysctl.d/99-rootless-ports.conf
```

**Step 3. Creating and running a user-level Systemd unit without extra packages:**

Podman can automatically generate the correct systemd wrapper from an already running container launched via compose.

```bash

# 1. Generate the unit file (the --new flag forces it to recreate the container on start)
mkdir -p ~/.config/systemd/user/
podman generate systemd --name traefik --files --new
mv container-traefik.service ~/.config/systemd/user/traefik.service
# 2. Activate the service (WITHOUT sudo!)
systemctl --user daemon-reload
systemctl --user enable --now traefik.service
# 3. CRITICAL: Allow user processes to persist after the SSH session is closed (Linger)
loginctl enable-linger $USER
```

---

## 💡 Alternatives and Common Sense

### 1. The Easy Way: Classic Docker (Root-mode)

If you need to deploy your infrastructure without the aforementioned "hassle" involving security contexts, UID mapping, and port
forwarding, use the **official Docker Engine** instead of Podman.

* The Docker daemon runs as `root`, so ports `80/443` bind out of the box.
* SELinux policies for Docker in standard repositories are configured more transparently and do not require disabling the entire
  host protection system for the sake of a single container.
* It is sufficient to install `docker-ce`, `docker-compose-plugin`, and use the classic `docker-compose.socket-root.yml` mode.

### 2. When Rootless + Podman + RHEL is Truly Required

If your company's or project's security policy **strictly demands** isolation based on Rootless Podman with SELinux enabled (in
`Enforcing` mode) in an enterprise environment:

* **Do not attempt to fix this with "crutches" and by disabling protective mechanisms.**
* Contact your system administrators or information security engineers (SecOps/DevSecOps).
* A proper production approach in this configuration requires fine-tuning SELinux policies via context types (`container_file_t`,
  `container_share_t`), manually compiling custom modules (`.pp`), configuring `seccomp` policies, and precise namespace tuning.
  Attempting to solve this "head-on" on production servers will result in either security vulnerabilities or unstable network
  behavior.
