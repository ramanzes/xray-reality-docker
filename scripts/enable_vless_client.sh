#!/bin/bash
set -e

# Проверка аргумента
if [ -z "$1" ]; then
  echo "❌ Использование: $0 client_name"
  exit 1
fi

CLIENT_NAME="$1"

# Пути (Docker)
CLIENT_FILE="/app/clients/${CLIENT_NAME}.txt"
CONFIG="/app/xray/config.json"

# Проверка файла клиента
if [ ! -f "$CLIENT_FILE" ]; then
  echo "❌ Файл клиента не найден: $CLIENT_FILE"
  exit 1
fi

# Извлекаем UUID из ссылки
UUID=$(grep -oP 'vless://\K[^@]+' "$CLIENT_FILE" | head -n1)

if [ -z "$UUID" ]; then
  echo "❌ Не удалось извлечь UUID"
  exit 1
fi

# Проверяем, есть ли disabled_clients
DISABLED_EXISTS=$(jq --arg uuid "$UUID" '
  .inbounds[].settings.disabled_clients[]? | select(.id == $uuid)
' "$CONFIG")

if [ -z "$DISABLED_EXISTS" ]; then
  echo "❌ Клиент не найден среди отключённых"
  exit 1
fi

# Перенос клиента обратно в clients
jq --arg uuid "$UUID" '
  .inbounds[].settings |= (
    .clients +=
      [ .disabled_clients[] | select(.id == $uuid) ] |
    .disabled_clients |=
      map(select(.id != $uuid))
  )
' "$CONFIG" > /tmp/xray.json && mv /tmp/xray.json "$CONFIG"

# Перезагрузка Xray (PID 1 в контейнере)
kill -HUP 1

echo "▶️ Клиент включён"
echo "Имя:  $CLIENT_NAME"
echo "UUID: $UUID"
