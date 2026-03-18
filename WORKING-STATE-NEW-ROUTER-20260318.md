# ✅ Зафиксированный рабочий результат (новый роутер)

Дата: **2026‑03‑18**

Эта заметка фиксирует “хорошее” состояние после подключения роутера **как клиента (WWAN)** через другую сеть и восстановления всех функций Podkop + sing-box, включая динамические внешние списки.

---

## Что было не так

### 1) WAN/интернет отсутствовал (NO‑CARRIER / нет дефолтного маршрута)
Из‑за отсутствия интернета `sing-box` мог падать при инициализации, например при загрузке удалённого ruleset `russia_inside.srs` с GitHub.

### 2) `sing-box` падал из‑за отсутствующего external ruleset в `/tmp`
Ошибка в логах:

- `open /tmp/sing-box/rulesets/main-external-domains-ruleset.json: no such file or directory`

Это критично, потому что `config.json.master` ссылается на ruleset по пути в `/tmp`, а файл должен быть скопирован туда до старта `sing-box`.

### 3) Возможный краш из‑за плейсхолдера short_id
Если в master‑конфиг попадал `short_id="YOUR_SHORT_ID"` (не hex) — `sing-box` падает на декодировании.

---

## Что сделано, чтобы “встало”

- **Применены конфиги/скрипты проекта** через `scripts/restore.sh` (включая `maxg-fetch-lists`, `telegram-subnets-fix`, rulesets, автозапуск).
- **Сгенерирован/обеспечен** `main-external-domains-ruleset.json` и **скопирован** в `/tmp/sing-box/rulesets/`.
- **Пропатчен** `/etc/sing-box/config.json.master` из текущего `podkop.main.proxy_string` (LuCI), при отсутствии `sid` short_id приводится к безопасному значению.
- **Правильный порядок рестартов**:
  - поднять `sing-box` (чтобы слушал `127.0.0.42:53`)
  - затем `dnsmasq` (который форвардит на `127.0.0.42`)
  - затем `podkop` + `telegram-subnets-fix`

---

## Контрольные проверки (прошли)

### 1) FakeIP работает
Проверка DNS через локальный resolver:

- `nslookup 2ip.ru 127.0.0.1` → **`198.18.x.x`** (FakeIP)

### 2) Прокси‑маршрут работает (FakeIP + TPROXY)
Проверка egress IP:

- `curl --resolve 2ip.ru:443:<fakeip> https://2ip.ru` → **`5.253.40.179`** (через прокси)
- `wget -qO- https://api.ipify.org` → **`91.215.60.44`** (direct)

IP различаются → значит маршрутизация реально идёт через `sing-box`.

### 3) Внешние списки подключены
- `maxg-fetch-lists` подтягивает:
  - `https://maxg.ch/domains.txt`
  - `https://maxg.ch/subnets.txt`
- ruleset присутствует в:
  - `/etc/podkop/rulesets/main-external-domains-ruleset.json`
  - `/tmp/sing-box/rulesets/main-external-domains-ruleset.json`

---

## Параметры Wi‑Fi (настройка “10”)

На роутере выставлено:

- **2.4 GHz**: `Groot10_2.4G`
- **5 GHz**: `Groot10_5G`

---

## Если снова “не встаёт”

1) Проверить, что `sing-box` слушает `127.0.0.42:53`:
- `netstat -nlp | grep 127.0.0.42:53`

2) Убедиться, что есть external ruleset в `/tmp`:
- `ls -la /tmp/sing-box/rulesets/main-external-domains-ruleset.json`

3) Перезапустить в правильном порядке:
- `service sing-box restart; service dnsmasq restart; service podkop restart; /usr/bin/telegram-subnets-fix`

