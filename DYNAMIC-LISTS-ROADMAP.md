# Dynamic external lists (domains + subnets)
ТЗ + Roadmap для двух внешних ссылок вида `maxg.ch/...`, которые можно редактировать динамически, а роутер будет подтягивать их после перезагрузки и по расписанию.

## Цель

Сделать 2 внешних источника:

1) **Домены** → маршрутизация по доменам через proxy (`main-out`) с устойчивым fakeip (`198.18.0.0/15`), чтобы правила работали через DNS/TPROXY.  
2) **IP/сети** → добавление в `nft` set (например `podkop_subnets`) для перехвата по destination IP.

Требование: после **reboot** и при последующих изменениях списков роутер **сам** подтягивает и применяет их (без ручных действий).

## Источники (URLs)

- **Domains list**: `https://maxg.ch/domains.txt`
- **Subnets list**: `https://maxg.ch/subnets.txt`

Рекомендация: отдать статикой с HTTP cache headers (ETag/Last-Modified) — это позволит роутеру делать `If-None-Match/If-Modified-Since` и не тратить трафик.

## Формат `domains.txt` (plain text)

Одна запись на строку.

Поддерживаемые варианты:
- `example.com` (домен)
- `api.example.com` (поддомен)
- `*.example.com` (wildcard) → конвертируется в `domain_suffix: "example.com"`

Комментарии/пустые:
- строки, начинающиеся с `#` или пустые — игнорируются

Нормализация:
- `trim`, `toLowerCase`
- убрать завершающую точку (`example.com.` → `example.com`)

Валидация:
- разрешить `[a-z0-9.-]` + `*.` в начале (для wildcard)
- отклонять строки с пробелами/URL/`/`/`:` и т.п.

## Формат `subnets.txt` (plain text)

Одна запись на строку:
- IPv4 CIDR: `149.154.160.0/20`
- (опционально позже) IPv6 CIDR: отдельным файлом `subnets6.txt`

Комментарии:
- `#` и пустые строки игнорируются

Валидация:
- IPv4 CIDR строго

## Где хранить на роутере

Предлагается хранить «последнюю успешную версию» в `/etc` (переживает reboot), а рабочую копию в `/tmp`:

- `/etc/podkop/external/domains.txt`
- `/etc/podkop/external/subnets.txt`
- `/tmp/podkop/external/domains.txt` (runtime)
- `/tmp/podkop/external/subnets.txt` (runtime)

## Конвертация доменов в ruleset sing-box

Сгенерировать локальный ruleset (format source, version 3):

- Путь: `/etc/podkop/rulesets/main-external-domains-ruleset.json`
- В рантайме копировать/держать в `/tmp/sing-box/rulesets/main-external-domains-ruleset.json`

Правила:
- wildcard `*.example.com` → `domain_suffix: ["example.com"]`
- обычный `api.example.com` → `domain: ["api.example.com"]`
- обычный `example.com` → можно:
  - либо `domain_suffix: ["example.com"]` (покрывает поддомены),
  - либо `domain: ["example.com"]` (строго).  
  Рекомендуется: **оба** (как делает часть существующих правил), либо конфиг-флагом выбрать поведение.

## Интеграция в sing-box (`etc/sing-box/config.json.master`)

Добавить:

1) `route.rule_set`:
- `tag`: `main-external-domains-ruleset`
- `type`: `local`
- `format`: `source`
- `path`: `/tmp/sing-box/rulesets/main-external-domains-ruleset.json`

2) `route.rules`:
- правило `action: route`, `outbound: main-out`, `rule_set: ["main-external-domains-ruleset"]`

3) `dns.rules` (fakeip):
- правило `action: route`, `server: fakeip-server`, `rewrite_ttl: 60`,
- `rule_set` должен включать `main-external-domains-ruleset`  
  (или отдельное правило `domain_suffix/domain` — но проще через rule_set).

Итого: домены из внешнего списка будут резолвиться в fakeip `198.18/15` → попадать в nft marking `198.18/15` → уходить в tproxy → `main-out`.

## Интеграция subnets в nft

Вариант A (минимальный): использовать существующий set `podkop_subnets`:

- в `telegram-subnets-fix` добавить шаг:
  - прочитать `subnets.txt`
  - `nft add element inet PodkopTable podkop_subnets { <CIDR...> }`

Вариант B (аккуратнее): отдельный nft set, чтобы не смешивать Telegram и внешние:
- создать `set external_subnets` и маркировать аналогично `podkop_subnets`

Рекомендация: **B** (проще сопровождать и дебажить).

## Скрипты (что добавить в проект)

### 1) `/usr/bin/maxg-fetch-lists`

Функции:
- скачать `domains.txt` и `subnets.txt` в `/tmp` (с таймаутами/ретраями)
- валидировать/нормализовать
- атомарно сохранить в `/etc/podkop/external/*` (через tmp+mv)
- сгенерировать `/etc/podkop/rulesets/main-external-domains-ruleset.json`

Требования:
- максимум зависимостей: `wget`/`curl`, `busybox ash`  
  (если `jq` есть — можно использовать для генерации JSON, но лучше без него)
- логирование: `logger -t maxg-lists`

### 2) Расширить `etc/telegram-subnets-fix`

Добавить перед рестартом `sing-box`:
- запуск `/usr/bin/maxg-fetch-lists` (best-effort)
- копирование `main-external-domains-ruleset.json` в `/tmp/sing-box/rulesets/`
- применение subnets в nft (в `external_subnets` или `podkop_subnets`)

### 3) Autostart / schedule

Использовать уже существующие механизмы:
- init `telegram-subnets` (после podkop)
- trigger `config.change podkop`
- `rc.local` (delayed)
- cron `*/2` или `*/5` (на усмотрение)

Дополнительно (опционально):
- отдельный cron для `maxg-fetch-lists` раз в 10–30 минут, чтобы списки обновлялись без рестартов.

## Тест‑план (авто-проверки)

Добавить/обновить selftest (аналог `podkop-sb-selftest`):

1) **DNS fakeip**:
- домен из `domains.txt` должен резолвиться в `198.18.x.x` через `127.0.0.1` (dnsmasq).

2) **TPROXY counters**:
- `nft` counters по `198.18/15` должны увеличиваться после запроса к домену из списка.

3) **Egress check**:
- запрос к `https://2ip.ru` через fakeip+tproxy должен возвращать IP, отличный от прямого `https://api.ipify.org`.

4) **Subnets**:
- для IP из `subnets.txt` (тестовый) трафик маркируется и уходит в tproxy.

## Этапы работ

1) Определить и поднять на `maxg.ch` два файла (`domains.txt`, `subnets.txt`) с cache headers.
2) Добавить в проект:
   - `/usr/bin/maxg-fetch-lists`
   - ruleset generator (встроенный в скрипт)
3) Обновить `etc/sing-box/config.json.master` под `main-external-domains-ruleset`.
4) Расширить `etc/telegram-subnets-fix` для fetch+apply.
5) Добавить selftest/healthcheck (cron) и документацию в README.

