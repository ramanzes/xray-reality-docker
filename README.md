# Xray Reality Docker Manager

Полностью автономная система управления Xray (VLESS + Reality) в Docker.

## Возможности

- Docker-контейнер с Xray
- Управление клиентами через CLI
- UUID + Reality ключи генерируются автоматически
- Клиенты хранятся в ./clients
- Включение / отключение без удаления

## Установка

```bash
git clone https://github.com/USERNAME/xray-reality-docker.git
cd xray-reality-docker
docker compose up -d --build

## Команды

```bash
./xrayctl add petya
./xrayctl disable petya
./xrayctl enable petya
./xrayctl list
./xrayctl show petya
```

## Где что хранится

- `clients/` — ссылки клиентов
    
- `.env` — ключи сервера
    
- `xray/config.json` — конфиг Xray
    

## Безопасность

- Private Key никогда не передаётся клиентам
    
- Reality работает через host network

## IPv6 Support
If your VPS has IPv6, links will be generated automatically.

Clients may use IPv4 or IPv6 transparently.

## Firewall
```bash
./firewall.sh
```

## Health Check

```bash
./xray-health.sh
```
---

## Who is this for?
- VPS owners
- Sysadmins
- Developers
- People who hate panels

## Who is this NOT for?
- Beginners
- People who want UI
- People afraid of CLI


---
## Design decisions

- No UI by design
- Docker host network for Reality
- Filesystem as source of truth
- jq instead of custom parsers


---

## VERSION
1.0.0

В будущем:

* `1.1.0` — новая функция
* `1.0.1` — фикс
* `2.0.0` — breaking change
