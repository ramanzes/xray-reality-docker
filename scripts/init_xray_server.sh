#!/bin/bash
set -e

echo "▶ Инициализация Xray сервера..."

### Проверка root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Запусти от root"
  exit 1
fi

### Пути
XRAY_CONFIG="/usr/local/etc/xray/config.json"
ENV_FILE=".env"

### Установка зависимостей
apt update -y
apt install -y curl jq

### Установка Xray (если не установлен)
if ! command -v xray >/dev/null 2>&1; then
  echo "▶ Устанавливаю Xray..."
  bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
fi

### Генерация UUID
UUID=$(xray uuid)

### Генерация Reality ключей
KEYS=$(xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | grep "Private key" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | grep "Public key" | awk '{print $3}')

### Short ID
SHORT_ID=$(openssl rand -hex 3)

### Внешний IP
SERVER_IP=$(curl -s https://api.ipify.org)
IPV4=$SERVER_IP
IPV6=$(curl -6 -s https://api64.ipify.org || true)



### SNI
SNI="www.cloudflare.com"

### Создание config.json
mkdir -p /usr/local/etc/xray

cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision",
            "email": "admin"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$SNI:443",
          "xver": 0,
          "serverNames": [
            "$SNI"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [
            "$SHORT_ID"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

### Сохраняем .env
cat > "$ENV_FILE" <<EOF
# Xray Reality Server ENV
SERVER_IPV4=$IPV4
SERVER_IPV6=$IPV6
SERVER_PORT=443
SNI=$SNI

UUID_ADMIN=$UUID

REALITY_PRIVATE_KEY=$PRIVATE_KEY
REALITY_PUBLIC_KEY=$PUBLIC_KEY
REALITY_SHORT_ID=$SHORT_ID
EOF

### Права
chmod 600 "$ENV_FILE"

### Запуск Xray
systemctl restart xray
systemctl enable xray

echo "=============================="
echo "✅ Xray сервер готов"
echo "IPv4: $IPV4"
echo "IPv6: $IPV6"
echo "UUID: $UUID"
echo "Public Key: $PUBLIC_KEY"
echo "Short ID: $SHORT_ID"
echo "ENV файл: $ENV_FILE"
echo "=============================="
