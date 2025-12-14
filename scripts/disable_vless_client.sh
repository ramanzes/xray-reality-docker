#!/bin/bash
set -e

source /app/.env

if [ -z "$1" ]; then
  echo "❌ Использование: $0 client_name"
  exit 1
fi

CLIENT_NAME="$1"
FILE="/app/clients/${CLIENT_NAME}.txt"
CONFIG="/app/xray/config.json"

if [ ! -f "$FILE" ]; then
  echo "❌ Файл клиента не найден: $FILE"
  exit 1
fi

UUID=$(grep -oP 'vless://\K[^@]+' "$FILE")

if [ -z "$UUID" ]; then
  echo "❌ Не удалось извлечь UUID"
  exit 1
fi

# Проверяем, что клиент активен
FOUND=$(jq --arg uuid "$UUID" '
  .inbounds[].settings.clients[]? | select(.id == $uuid)
' "$CONFIG")

if [ -z "$FOUND" ]; then
  echo "❌ Клиент не найден в active clients"
  exit 1
fi

# Гарантируем наличие disabled_clients
jq '
  .inbounds[].settings |=
    (if has("disabled_clients") then . else . + { "disabled_clients": [] } end)
' "$CONFIG" > /tmp/xray.json && mv /tmp/xray.json "$CONFIG"

# Перенос клиента
jq --arg uuid "$UUID" '
  .inbounds[].settings |= (
    .disabled_clients +=
      [ .clients[] | select(.id == $uuid) ] |
    .clients |=
      map(select(.id != $uuid))
  )
' "$CONFIG" > /tmp/xray.json && mv /tmp/xray.json "$CONFIG"

# Перечитываем конфиг
pkill -HUP xray || true

echo "⏸️ Клиент временно отключён"
echo "Имя: $CLIENT_NAME"
echo "UUID: $UUID"
