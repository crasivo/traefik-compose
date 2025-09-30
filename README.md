🚢 Traefik Compose
===

Ready-made assembly of [Traefik Proxy](https://traefik.io/traefik) for developing Web applications in a Docker/Podman environment.

## 🚀 Quick Start

First of all, you need to create a public _(external)_ network for Traefik.
Below is an example command to create a public (external) network `traefik_public`.
You can specify any name and IP address subnet.

```shell
$ docker network create \
  --driver=bridge \
  --subnet=172.30.100.0/24 \
  --ip-range=172.30.100.0/24 \
  --gateway=172.30.100.1 \
  traefik_public
```

Also, for the service to work correctly, open ports `80` and `443` are required.
If you have another web server (nginx/apache/caddy) running that may be using them, you need to turn it off.

Example command to start the service:

```shell
$ cp -f ./docker-compose.example.yml ./docker-compose.yml
$ docker compose up -d
```

After successful startup and initialization, you can go to the control panel at one of the URLs:

- http://localhost _(without DNS)_
- http://traefik.docker

## 🕹️ Operation

If you are using Traefik for the first time, it is recommended that you study the [official documentation](https://doc.traefik.io/traefik/master/expose/docker/) before starting work.
This section is intended for experienced users and describes some features of working with the service.

### 🔐 SSL certificates

For secure HTTPS/SSL connections, Traefik uses its own `Default` certificate,
which is not related to the domain in any way (one for all).
This can be a problem, because most applications during the initialization of a secure connection check for properties such as "issued by" and "issued to".
All universal (without a domain) and unknown certificates are immediately blocked (red flag) at the system or client level.

For such cases, the assembly already contains several pre-generated (self-signed) SSL certificates,
which are great for <u>local development</u>.

List of pre-installed certificates:

- `Localhost` — a simple certificate for the local domain `localhost`
- `Traefik Internal` — wildcard certificate for all service domains `traefik.internal` and `*.traefik.internal`
- `Traefik Docker` — wildcard certificate for all service domains `traefik.docker` and `*.traefik.docker`
- `Traefik Local` — wildcard certificate for all service domains `traefik.local` and `*.traefik.local`
- `Traefik Default` — universal, for other cases _(without host)_

> [!NOTICE]
> The last certificate is used by default, for example, when it was not possible to match the domain name (host-cert).
> Let me remind you that no application or client will consider it 100% valid (trusted).

For correct operation of HTTP/Socket clients with your services, you need to register the root certificate _(Crasivo Root CA)_
at the host or other container level.

Example command to register a certificate in popular UNIX/Linux systems:

```shell
# Alpine
$ sudo apk add ca-certificates
$ sudo cp -f ./docker/layouts/ssl.d/root/certificate.pem /etc/ssl/certs/Crasivo_Root_CA.crt
$ sudo update-ca-certificates
# Debian/Ubuntu/Gentoo etc
$ sudo apt-get install -y ca-certificates
$ sudo cp -f ./docker/layouts/ssl.d/root/certificate.pem /usr/local/share/ca-certificates/Crasivo_Root_CA.crt
$ sudo update-ca-certificates
# CentOS/Fedora/RHEL etc
$ sudo yum install ca-certificates
$ sudo cp -f ./docker/layouts/ssl.d/root/certificate.pem /etc/pki/ca-trust/source/anchors/Crasivo_Root_CA.crt
$ sudo update-ca-trust
```

> [!NOTE]
> The path to the directory where the certificates are located may differ depending on the version of your distribution,
> therefore, it is recommended to additionally clarify the information on the official website of your OS.

For other operating systems:

- Apple MacOS: Control is carried out through [Keychain Access](https://support.apple.com/guide/keychain-access/welcome/mac)
- Microsoft Windows: Open the `*.pem` certificate file > Click the "Import" button

You can check the correctness of the work through the `curl` command:

```shell
$ curl -I https://localhost
# HTTP/2 405
```

Some browsers use their own trusted SSL certificate stores,
i.e. do not take into account system ones (see above).
For the correct display of the site in the application (green bar), it is recommended
check and, if necessary, additionally register the root certificate _(Crasivo Root CA)_ through the settings.

- Google Chrome (Opera/Edge/etc): [chrome://certificate-manager/](chrome://certificate-manager/)
- Mozilla Firefox: Privacy & Security > Certificates > View Certificates > Import

Example of registering a root certificate in `Dockerfile` (alpine) of your custom image.

```dockerfile
FROM alpine
ADD /path/to/root/certificate.pem /etc/ssl/certs/traefik_root_ca.crt
RUN set -eux \
    && apk add ca-certificates \
    && update-ca-certificates
```

### 🌐 DNS

For correct operation with "service" domains such as `*.local` or `*.internal`, you need to configure DNS at the host (machine) level.
Without this, Traefik will not be able to match the "host-ip" and a 404 error will always be displayed in the browser.

> [!TIP]
> It is recommended to additionally install and configure a local DNS.
> The most popular solution for Linux is `dnsmasq`.

The easiest option (without third-party DNS) is to edit the system `hosts` file.
Below is an example of registering mappings between local domains and IP _(127.0.0.1)_.

```text
127.0.0.1 localhost
127.0.0.1 traefik.docker
127.0.0.1 subdomain.traefik.docker
127.0.0.1 custom.docker
```

> [!NOTICE]
> I repeat, this method is NOT the best.
> This is the easiest solution without installing and configuring additional packages.

---

## 📜 License

This project is distributed under the [MIT](https://en.wikipedia.org/wiki/MIT_License) license.
The full text of the license can be read in the corresponding [file](LICENSE).
