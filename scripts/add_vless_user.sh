#!/bin/bash
set -e

source /app/.env

if [ -z "$1" ]; then
  echo "❌ Использование: $0 client_name"
  exit 1
fi

CLIENT_NAME="$1"
CONFIG="/app/xray/config.json"
CLIENT_FILE="/app/clients/${CLIENT_NAME}.txt"

# Проверка, существует ли клиент
if jq -e --arg name "$CLIENT_NAME" \
  '.inbounds[].settings.clients[]?.email == $name' \
  "$CONFIG" >/dev/null; then
  echo "❌ Клиент с именем $CLIENT_NAME уже существует"
  exit 1
fi

# Генерация UUID для клиента
UUID_CLIENT=$(xray uuid)

# Формирование ссылок
LINK_V4="vless://${UUID_CLIENT}@${SERVER_IPV4}:${SERVER_PORT}?type=tcp&security=reality&encryption=none&flow=${FLOW}&sni=${SNI}&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}#${CLIENT_NAME}"

if [ -n "$SERVER_IPV6" ]; then
  LINK_V6="vless://${UUID_CLIENT}@[${SERVER_IPV6}]:${SERVER_PORT}?type=tcp&security=reality&encryption=none&flow=${FLOW}&sni=${SNI}&fp=chrome&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}#${CLIENT_NAME}"
fi

# Добавление клиента в config.json
jq --arg uuid "$UUID_CLIENT" \
   --arg email "$CLIENT_NAME" \
   --arg flow "$FLOW" \
  '
  .inbounds[].settings.clients += [{
    id: $uuid,
    flow: $flow,
    email: $email
  }]
  ' "$CONFIG" > /tmp/xray.json && mv /tmp/xray.json "$CONFIG"

# Сохранение клиента
{
  echo "# Client: $CLIENT_NAME"
  echo "# UUID: $UUID_CLIENT"
  echo
  echo "# IPv4"
  echo "$LINK_V4"
  if [ -n "$LINK_V6" ]; then
    echo
    echo "# IPv6"
    echo "$LINK_V6"
  fi
} > "$CLIENT_FILE"

# QR-код (ANSI, для терминала)
if command -v qrencode >/dev/null 2>&1; then
  echo
  echo "# QR (IPv4)"
  qrencode -t ANSIUTF9 "$LINK_V4" >> "$CLIENT_FILE"

  echo "# QR (IPv6)"
  qrencode -t ANSIUTF8 "$LINK_V6" >> "$CLIENT_FILE"
fi

echo "=============================="
echo "✅ Клиент добавлен"
echo "Имя:   $CLIENT_NAME"
echo "UUID:  $UUID_CLIENT"
echo "Файл:  clients/${CLIENT_NAME}.txt"
echo "=============================="
