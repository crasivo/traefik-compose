🚢 Traefik Compose
===

Готовая сборка [Traefik Proxy](https://traefik.io/traefik) для разработки Web приложений в Docker/Podman окружении.

## 🚀 Быстрый старт

В первую очередь необходимо создать публичную _(external)_ сеть для Traefik.
Ниже приведен пример команды для создания публичной (external) сети `traefik_public`.
Вы можете указать любое наименование и подсеть IP адресов.

```shell
$ docker network create \
  --driver=bridge \
  --subnet=172.30.100.0/24 \
  --ip-range=172.30.100.0/24 \
  --gateway=172.30.100.1 \
  traefik_public
```

Также для корректной работы сервиса необходимы открытые порты `80` и `443`.
Если у вас запущен другой web сервер (nginx/apache/caddy), который может использовать их, то необходимо его выключить.

Пример команды для запуска сервиса:

```shell
$ cp -f ./docker-compose.example.yml ./docker-compose.yml
$ docker compose up -d
```

После успешного запуска и инициализации можно будет перейти в панель управления по одному из URL:

- http://localhost _(without DNS)_
- http://traefik.docker

## 🕹️ Эксплуатация

Если вы в первый раз используете Traefik, то рекомендуется перед началом работы изучить [официальную документацию](https://doc.traefik.io/traefik/master/expose/docker/).
Данный раздел предназначен для опытных пользователей и описывает некоторые особенности по работе с сервисом.

### 🔐 SSL сертификаты

Для защищенных HTTPS/SSL соединений Traefik использует собственный `Default` сертификат,
который никак не связан с доменом (один на всех).
Это может быть проблемой, т.к большинство приложений во время инициализации защищенного соединения проверяют наличие свойств типа "кем выдан" и "кому выдан".
Все универсальные (без домена) и неизвестные сертификаты сразу блокируются (red flag) на уровне системы или клиента.

Для таких случаев в сборке уже присутствуют несколько заранее сгенерированных (self-signed) SSL сертификатов,
которые отлично подходят для <u>локальной разработки</u>.

Список предустановленных сертификатов:

- `Localhost` — простой сертификат для локального домена `localhost`
- `Traefik Internal` — wildcard сертификат для всех служебных доменов `traefik.internal` и `*.traefik.internal`
- `Traefik Docker` — wildcard сертификат для всех служебных доменов `traefik.docker` и `*.traefik.docker`
- `Traefik Local` — wildcard сертификат для всех служебных доменов `traefik.local` и `*.traefik.local`
- `Traefik Default` — универсальный, для остальных случаев _(без хоста)_

> [!NOTICE]
> Последний сертификат используется по умолчанию, например, когда не удалось сопоставить доменное имя (host-cert).
> Напомню, что ни одно приложение или клиент НЕ будет считать его на 100% валидным (доверенным).

Для корректной работы HTTP/Socket клиентов с вашими сервисами необходимо зарегистрировать корневой сертификат _(Crasivo Root CA)_
на уровне хоста или другого контейнера.

Пример команды для регистрации сертификата в популярных UNIX/Linux системах:

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
> Путь к директории, где лежат сертификаты, может отличаться в зависимости от версий вашего дистрибутива,
> поэтому рекомендуется дополнительно уточнить информацию на оф.сайте вашей OS.

Для других операционных систем:

- Apple MacOS: Контроль осуществляется через [Keychain Access](https://support.apple.com/guide/keychain-access/welcome/mac)
- Microsoft Windows: Открыть `*.pem` файл сертификата > Нажать на кнопку "Импортировать"

Проверить корректность работы можно через `curl` команду:

```shell
$ curl -I https://localhost
# HTTP/2 405
```

Некоторые браузеры используют собственные хранилища доверенных SSL сертификатов,
т.е не учитывают системные (см.выше).
Для корректного отображения сайта в приложении (зеленая полоска) рекомендуется
проверить и при необходимости дополнительно зарегистрировать корневой сертификат _(Crasivo Root CA)_ через настройки.

- Google Chrome (Opera/Edge/etc): [chrome://certificate-manager/](chrome://certificate-manager/)
- Mozilla Firefox: Privacy & Security > Certificates > View Certificates > Import

Пример регистрации корневого сертификата в `Dockerfile` (alpine) вашего кастомного образа.

```dockerfile
FROM alpine
ADD /path/to/root/certificate.pem /etc/ssl/certs/traefik_root_ca.crt
RUN set -eux \
    && apk add ca-certificates \
    && update-ca-certificates
```

### 🌐 DNS

Для корректной работы со "служебными" доменами типа `*.local` или `*.internal` необходимо настроить DNS на уровне хоста (машины).
Без этого Traefik не сможет сопоставить "host-ip" и в браузере всегда будет отображаться 404 ошибка.

> [!TIP]
> Рекомендуется дополнительно установить и настроить локальный DNS.
> Самое популярное решение для Linux - `dnsmasq`.

Самым простым вариантом (без стороннего DNS) является редактирование системного файла `hosts`.
Ниже приведен пример регистрации сопоставлений между локальными доменами и IP _(127.0.0.1)_.

```text
127.0.0.1 localhost
127.0.0.1 traefik.docker
127.0.0.1 subdomain.traefik.docker
127.0.0.1 custom.docker
```

> [!NOTICE]
> Повторюсь, данный способ НЕ является лучшим.
> Это самое простое решение без установки и настройки дополнительных пакетов.

---

## 📜 Лицензия

Данный проект распространяется по лицензии [MIT](https://en.wikipedia.org/wiki/MIT_License).
Полный текст лицензии можно прочитать в соответствующем [файле](LICENSE).
