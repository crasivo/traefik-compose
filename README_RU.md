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

Готовая и безопасная сборка [Traefik Proxy](https://traefik.io/traefik) для локальной разработки и развертывания Web-приложений в
Docker и Podman окружениях.

Данный стек базируется на **закаленном (hardened) Rootless-образе на базе Alpine Linux** с автоматической генерацией локального
PKI/OpenSSL и встроенными механизмами макро-бутстрапинга конфигурации.

---

## 🛠 Варианты запуска и сетевые режимы

В зависимости от требований безопасности вашей инфраструктуры и типа демона, проект поддерживает **4 архитектурных режима работы:

1. **TCP Rootless** — *Режим по умолчанию*. Максимальная изоляция: контейнер работает от имени
   `traefik` (UID 1000) и общается с Docker API по сети через TCP-порт `2375`, исключая монтирование сокетов.
2. **TCP Root** — Контейнер работает под `root`, но сохраняет сетевую изоляцию от файловой системы
   хоста через TCP.
3. **Socket Rootless** — Безопасное подключение через проброс сокета пространства
   пользователя (`/run/user/1000/docker.sock`).
4. **Socket Root** — Классический режим с монтированием стандартного `/var/run/docker.sock`.

> 💡 *Подробное описание каждого режима, особенности работы с Podman, а также инструкции по предварительной настройке
Systemd/Фаервола для TCP-режимов находятся в выделенной документации: [**docker/README_RU.md**](docker/README_RU.md).*

---

## 🚀 Быстрый старт

### Шаг 1: Создание внешней сети

Для взаимодействия прокси-сервера с другими вашими контейнерами необходимо создать общую внешнюю *(external)* сеть
`traefik_public`:

```shell
$ docker network create \
  --driver=bridge \
  --subnet=172.30.100.0/24 \
  --ip-range=172.30.100.0/24 \
  --gateway=172.30.100.1 \
  traefik_public
```

Дополнительно убедитесь, что порты `80` и `443` на хост-машине свободны (выключите локальные экземпляры Nginx, Apache или Caddy).

### Шаг 2: Выбор режима и запуск стека

Перейдите в директорию `docker/`, создайте символическую ссылку на нужную конфигурацию и запустите контейнер:

```shell
$ cd docker

# Выберите конфигурационный файл (например, tcp-rootless)
$ ln -sf docker-compose.tcp-rootless.yml docker-compose.yml

# Сборка и запуск
$ docker compose up -d --build
```

После успешного старта панель управления Traefik API/Dashboard будет доступна по адресам:

* http://localhost *(без DNS)*
* http://traefik.docker *(требуется настройка DNS/hosts)*

---

## 🕹️ Эксплуатация

Если вы впервые работаете с Traefik, рекомендуется ознакомиться
с [официальной документацией по Docker-провайдеру](https://doc.traefik.io/traefik/master/expose/docker/).

### 🔐 SSL сертификаты (Локальный PKI)

Сборка полностью отказывается от стандартных дефолтных заглушек Traefik. Вместо этого при каждом старте контейнера в рамках
`ENTRYPOINT` автоматически отрабатывает макро-скрипт `openssl-generate.sh`.

Скрипт разворачивает полноценный локальный центр сертификации (PKI) и генерирует валидные SSL-сертификаты прямо «на лету» под
следующие назначения:

* **Crasivo Root CA** — собственный доверенный корневой сертификат (генератор цепочки доверия).
* **Localhost** — для локального домена `localhost`.
* **Default / Fallback** — универсальный сертификат для запросов без сопоставленного хоста.
* **Динамический хост** — wildcard-сертификат, автоматически выпущенный под доменное имя, указанное в переменной окружения
  `VIRTUAL_HOST` (по умолчанию `*.traefik.docker`).

#### 📥 Как получить и установить корневой сертификат

Благодаря маппингу директории с сертификатами в compose-файлах, сгенерированный корневой сертификат хост-машина может легко
забрать из смонтированного тома:
👉 Путь на хосте: `./docker/volumes/traefik_certs/root/certificate.pem`

Чтобы операционная система, консольные утилиты (curl, wget) и внутренние контейнеры приложений не выдавали предупреждений о
безопасности (SSL Handshake Error), зарегистрируйте этот корневой сертификат **Crasivo Root CA** в системе:

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

#### Импорт в браузеры и графические ОС:

* **Apple macOS:** Дважды кликните по файлу `certificate.pem`, добавьте его в системную связку ключей (*Keychain Access*) и в
  свойствах сертификата принудительно выставьте параметр *«Всегда доверять» (Always Trust)*.
* **Microsoft Windows:** Откройте файл сертификата -> Нажмите *«Установить сертификат»* -> Выберите локальный компьютер ->
  Разместите его строго в хранилище *«Доверенные корневые центры сертификации»*.
* **Браузеры (Google Chrome, Firefox и др.):** Полноценные современные браузеры часто игнорируют общесистемное хранилище Linux.
  Для получения заветного «зеленого замочка» перейдите в настройки безопасности вашего браузера, найдите раздел *«Сертификаты ->
  Центры сертификации (Authorities)»* и импортируйте туда `certificate.pem` вручную.

Пример автоматического проброса и интеграции доверия к вашему локальному центру сертификации внутри кастомного `Dockerfile` (на
базе Alpine) для разрабатываемых приложений:

```dockerfile
FROM alpine
# Копируем сгенерированный сертификат из сборочного контекста
ADD ./docker/volumes/traefik_certs/root/certificate.pem /etc/ssl/certs/traefik_root_ca.crt
RUN set -eux \
    && apk add ca-certificates \
    && update-ca-certificates
```

### 🌐 DNS-маппинг

Чтобы служебные зоны (`*.docker`, `*.local`) корректно открывались в браузере, хост-машина должна знать, куда направлять этот
трафик.

1. **Рекомендуемый вариант (Инфраструктурный):** Установить и настроить локальный DNS-сервер, например `dnsmasq`, перенаправляющий
   все запросы с этих зон на `127.0.0.1`.
2. **Простой вариант (Ручной):** Добавить явные сопоставления доменов в системный файл `/etc/hosts` (или
   `C:\Windows\System32\drivers\etc\hosts` на Windows):

```text
127.0.0.1 localhost
127.0.0.1 traefik.docker
127.0.0.1 subdomain.traefik.docker
127.0.0.1 custom.docker
```

---

## 📜 Лицензия

Данный проект распространяется под лицензией [MIT](https://en.wikipedia.org/wiki/MIT_License). Полный текст лицензии находится в
файле [LICENSE](LICENSE) текущего репозитория.
