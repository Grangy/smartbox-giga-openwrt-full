<p align="center">
  <img src="https://camo.githubusercontent.com/dddfc9fdf9140009ea06e288ab69f907bdab5d825ee3e3c54f00146055b31421/68747470733a2f2f6b616b747573612e72752f70686f746f732f696d6167655f313737323130333430353937302e706e67" alt="Beeline SmartBox GIGA" width="600"/>
</p>

<h1 align="center">Beeline SmartBox GIGA — OpenWrt + Podkop</h1>

<p align="center">
  <strong>Полная прошивка с маршрутизацией через VLESS</strong><br/>
  Cursor, Telegram, TikTok, OpenAI и другие сервисы через прокси
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OpenWrt-24.10-00CC00?style=for-the-badge&logo=openwrt&logoColor=white" alt="OpenWrt"/>
  <img src="https://img.shields.io/badge/Podkop-0.7.14-0066CC?style=for-the-badge" alt="Podkop"/>
  <img src="https://img.shields.io/badge/sing--box-1.12.0-00B4AB?style=for-the-badge" alt="sing-box"/>
  <img src="https://img.shields.io/badge/VLESS-Reality-8B5CF6?style=for-the-badge" alt="VLESS"/>
  <img src="https://img.shields.io/badge/ramips-mt7621-FF6B00?style=for-the-badge" alt="ramips"/>
  <img src="https://img.shields.io/badge/Beeline-SmartBox_GIGA-E30613?style=for-the-badge" alt="Beeline"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License"/>
  <img src="https://img.shields.io/badge/Release-2026--03--18-blue?style=flat-square" alt="Release"/>
</p>

---

## 📋 Описание

Готовая прошивка **Beeline SmartBox GIGA** на базе OpenWrt 24.10 с предустановленным **Podkop** и **sing-box**. Маршрутизация выбранных сервисов (Cursor, Telegram, TikTok и др.) через VLESS/Reality прокси.

### ✨ Возможности

| Сервис | Маршрутизация |
|--------|----------------|
| **Cursor** | cursor.lst → VLESS |
| **Telegram** | podkop_subnets + ruleset → VLESS |
| **TikTok** | main-tiktok-ruleset → VLESS |
| **OpenAI, GitHub, YouTube** | main-local-domains → VLESS |
| **2ip.ru, PlayStation, EA** | VLESS |
| **External (maxg.ch)** | domains.txt → FakeIP+VLESS, subnets.txt → podkop_subnets |

### 🔧 Технологии

- **OpenWrt 24.10** — прошивка роутера
- **Podkop** — управление маршрутизацией и правилами
- **sing-box** — VLESS/Reality клиент
- **LuCI** — веб-интерфейс (русский язык)

---

## 📦 Содержимое релиза

| Файл | Описание |
|------|----------|
| `openwrt-Beeline-SmartBox-GIGA-sysupgrade-20260318.tar.gz` | Конфиги (восстановление через sysupgrade) |
| `openwrt-beeline_smartbox-giga-mtd4-mtd6-firmware-20260318.bin` | Полный образ прошивки (~30 MB) |
| `config-backup/` | Конфиги: network, firewall, wireless, dhcp, podkop, cursor.lst |
| `etc/sing-box/` | config.json.master (полный конфиг sing-box) |
| `etc/podkop/rulesets/` | Правила: main-local, main-telegram, main-tiktok |
| `etc/maxg-fetch-lists` | Загрузка внешних списков `domains.txt/subnets.txt` + генерация ruleset |
| `packages/` | .ipk: podkop, sing-box, luci-app-podkop |
| `scripts/restore.sh` | Полное восстановление на роутер |
| `scripts/apply-fix.sh` | Ручное применение fix (если TG/Cursor не работают) |

### ⚙️ Разделение конфигов

- **sing-box** читает `/etc/sing-box/config.json.master` (наш полный конфиг)
- **podkop** пишет в `/etc/sing-box/config.json` (podkop перезаписывает conffile при каждом запуске)
- **telegram-subnets-fix** восстанавливает UCI и перезапускает sing-box после каждого podkop

### 🔐 Настройка VLESS (без утечек в репо)

- **В репозитории нет рабочих VLESS-ключей**: в `etc/sing-box/config.json.master` и `config-backup/podkop` стоят плейсхолдеры/пустые значения.
- **Ссылку VLESS задавайте в LuCI**: `Podkop → Основное → proxy_string` (URL вида `vless://...`).
- При каждом запуске `telegram-subnets-fix`:
  - **не трогает** `podkop.main.proxy_string` (то, что вы ввели в LuCI)
  - **патчит** outbound `main-out` (VLESS) внутри `/etc/sing-box/config.json.master` под текущую ссылку (включая `flow=xtls-rprx-vision`, `pbk`, `sid`, `sni`)
  - и перезапускает `sing-box`, чтобы он реально использовал обновлённый `config.json.master`

### 🛡️ Restore без перезаписи proxy_string

Скрипт `scripts/restore.sh` применяет `config-backup/podkop` **без** `proxy_string` и сохраняет текущий `podkop.main.proxy_string`, если он уже задан в системе.

### 🚀 Автозапуск fix

- **init** (START=100): fix сразу после podkop
- **trigger**: при изменении config podkop — fix перезапускается
- **rc.local**: fix через 45 сек после boot
- **cron**: `*/2 * * * *` — каждые 2 минуты

---

## 🌐 Динамические внешние списки (maxg.ch)

Можно хранить домены/подсети во внешних файлах и менять их “на лету” без перепрошивки.

### 1) Домены → FakeIP → VLESS

- **Источник**: `https://maxg.ch/domains.txt`
- **Формат**: 1 домен на строку, комментарии `#` разрешены.
  - пример:
    - `2ip.ru`
    - `api.ipify.org`
    - `example.com`
- **Как применяется**:
  - `/usr/bin/maxg-fetch-lists` скачивает список и генерирует ruleset `main-external-domains-ruleset`
  - `telegram-subnets-fix` гарантирует, что `sing-box` применяет этот ruleset в DNS (FakeIP) и в маршрутизации (VLESS)

### 2) Подсети → nft `podkop_subnets`

- **Источник**: `https://maxg.ch/subnets.txt`
- **Формат**: 1 CIDR на строку, комментарии `#` разрешены.
  - пример:
    - `203.0.113.0/24`
    - `198.51.100.0/24`
- **Как применяется**: `telegram-subnets-fix` добавляет элементы из `subnets.txt` в `inet PodkopTable podkop_subnets`

### 3) Автообновление

Списки обновляются автоматически, потому что `maxg-fetch-lists` вызывается из `telegram-subnets-fix`, а `telegram-subnets-fix` запускается через init/rc.local/cron.

---

## 🛠 Установка и восстановление

### A. Только конфиги (sysupgrade)

```bash
scp openwrt-Beeline-SmartBox-GIGA-sysupgrade-20260318.tar.gz root@192.168.23.1:/tmp/
ssh root@192.168.23.1 "sysupgrade -r /tmp/openwrt-Beeline-SmartBox-GIGA-sysupgrade-20260318.tar.gz"
```

### B. Полный образ (mtd)

```bash
scp openwrt-beeline_smartbox-giga-mtd4-mtd6-firmware-20260318.bin root@192.168.23.1:/tmp/
ssh root@192.168.23.1
dd if=/tmp/openwrt-beeline_smartbox-giga-mtd4-mtd6-firmware-20260318.bin of=/tmp/kernel.bin bs=1 count=6449664
dd if=/tmp/openwrt-beeline_smartbox-giga-mtd4-mtd6-firmware-20260318.bin of=/tmp/rootfs.bin bs=1 skip=6449664
mtd -r write /tmp/kernel.bin kernel
mtd -r write /tmp/rootfs.bin "File System 1"
```

### C. Ручное восстановление (restore.sh)

Требуется: OpenWrt 24.10, пакеты в `packages/*.ipk`, sshpass.

```bash
# macOS: brew install sshpass
ROUTER_IP=192.168.23.1 SSH_PASSWORD=REDACTED ./scripts/restore.sh
```

### 🔄 Если Telegram/Cursor не работают

```bash
ROUTER_IP=192.168.23.1 SSH_PASSWORD=REDACTED ./scripts/apply-fix.sh
```

---

## 🔐 Доступ

| Параметр | Значение |
|----------|----------|
| **LAN** | 192.168.23.1 |
| **LuCI** | http://192.168.23.1 |
| **SSH** | root / REDACTED |

---

## 📄 Лицензия

MIT
