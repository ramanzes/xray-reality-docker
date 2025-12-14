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

# Проверяем, есть ли клиент в clients
EXISTS=$(jq --arg uuid "$UUID" '
  .inbounds[].settings.clients[]? | select(.id == $uuid)
' "$CONFIG")

if [ -z "$EXISTS" ]; then
  echo "❌ Клиент не найден в active clients"
  exit 1
fi

# 1. Гарантируем наличие disabled_clients как массива
jq '
  .inbounds[].settings |=
    (if has("disabled_clients") then . else . + { "disabled_clients": [] } end)
' "$CONFIG" > /tmp/xray.json && mv /tmp/xray.json "$CONFIG"

# 2. Перенос клиента
jq --arg uuid "$UUID" '
  .inbounds[].settings |= (
    .disabled_clients +=
      [ .clients[] | select(.id == $uuid) ] |
    .clients |=
      map(select(.id != $uuid))
  )
' "$CONFIG" > /tmp/xray.json && mv /tmp/xray.json "$CONFIG"

systemctl restart xray

echo "⏸️ Клиент временно отключён"
echo "UUID: $UUID"
