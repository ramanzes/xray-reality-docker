#!/bin/bash

if [ -z "$1" ]; then
  echo "❌ Использование: $0 client_name"
  exit 1
fi

FILE="clients/$1.txt"
CONFIG="/usr/local/etc/xray/config.json"

if [ ! -f "$FILE" ]; then
  echo "❌ Файл $FILE не найден"
  exit 1
fi

UUID=$(grep -oP 'vless://\K[^@]+' "$FILE")

if [ -z "$UUID" ]; then
  echo "❌ Не удалось извлечь UUID"
  exit 1
fi

# Проверяем, есть ли клиент в disabled_clients
EXISTS=$(jq --arg uuid "$UUID" '
  .inbounds[].settings.disabled_clients[]? | select(.id == $uuid)
' "$CONFIG")

if [ -z "$EXISTS" ]; then
  echo "❌ Клиент не найден в disabled_clients"
  exit 1
fi

# Возвращаем клиента обратно
jq --arg uuid "$UUID" '
  .inbounds[].settings |= (
    .clients +=
      [ .disabled_clients[] | select(.id == $uuid) ] |
    .disabled_clients |=
      map(select(.id != $uuid))
  )
' "$CONFIG" > /tmp/xray.json && mv /tmp/xray.json "$CONFIG"

systemctl restart xray

echo "▶️ Клиент возвращён в работу"
echo "UUID: $UUID"
