#!/bin/bash
set -e

echo "▶ Инициализация Xray сервера (Reality hardened)..."

# --- Проверка root ---
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Запусти от root"
  exit 1
fi

# --- Пути ---
XRAY_CONFIG="/usr/local/etc/xray/config.json"
ENV_FILE="./.env"
XRAY_BIN="/usr/local/bin/xray"
XRAY_SERVICE="/etc/init.d/xray"

# --- Установка зависимостей ---
echo "▶ Установка зависимостей..."
apt update
apt install -y curl jq openssl git qrencode iptables iptables-persistent

# --- Установка Xray ---
if ! command -v xray >/dev/null 2>&1; then
  echo "▶ Устанавливаю Xray..."
  rm -rf Xray-install
  git clone https://github.com/XTLS/Xray-install.git
  bash Xray-install/install-release.sh
fi

# --- Проверка бинарника ---
if [ ! -x "$XRAY_BIN" ]; then
  echo "❌ Xray не установлен"
  exit 1
fi

# --- UUID администратора ---
UUID="$(xray uuid)"

# --- Reality ключи ---
KEYS="$(xray x25519)"
PRIVATE_KEY="$(echo "$KEYS" | awk '{for(i=1;i<=NF;i++) if($i=="PrivateKey:") print $(i+1)}')"
PUBLIC_KEY="$(echo "$KEYS" | awk '{for(i=1;i<=NF;i++) if($i=="Password:") print $(i+1)}')"

if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
  echo "❌ Ошибка генерации Reality ключей"
  echo "$KEYS"
  exit 1
fi

# --- Short IDs (3 случайных) ---
SID1="$(openssl rand -hex 3)"
SID2="$(openssl rand -hex 3)"
SID3="$(openssl rand -hex 3)"

# --- IP ---
IPV4="$(curl -4 -s https://api.ipify.org || true)"
IPV6="$(curl -6 -s https://api64.ipify.org || true)"

# --- Dest / SNI ---
DEST_DOMAIN="www.cloudflare.com"

# --- Конфиг Xray ---
mkdir -p /usr/local/etc/xray
cat > "$XRAY_CONFIG" <<EOF
{
  "log": { "loglevel": "info" },
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "flow": "xtls-rprx-vision",
        "email": "admin"
      }],
      "decryption": "none",
      "disabled_clients": []
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "$DEST_DOMAIN:443",
        "xver": 0,
        "serverNames": ["$DEST_DOMAIN"],
        "alpn": ["h2","http/1.1"],
        "privateKey": "$PRIVATE_KEY",
        "shortIds": ["$SID1","$SID2","$SID3"]
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# --- ENV ---
cat > "$ENV_FILE" <<EOF
SERVER_IPV4=$IPV4
SERVER_IPV6=$IPV6
SERVER_PORT=443
SNI=$DEST_DOMAIN
UUID_ADMIN=$UUID
REALITY_PRIVATE_KEY=$PRIVATE_KEY
REALITY_PUBLIC_KEY=$PUBLIC_KEY
REALITY_SHORT_IDS=$SID1,$SID2,$SID3
EOF
chmod 600 "$ENV_FILE"

# --- Запуск Xray ---
systemctl enable xray
systemctl restart xray

# --- Firewall ---
echo "▶ Настройка Firewall..."
iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -A INPUT -i lo -j ACCEPT
iptables -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || \
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

ip6tables -C INPUT -i lo -j ACCEPT 2>/dev/null || ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
ip6tables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || \
ip6tables -A INPUT -p tcp --dport 443 -j ACCEPT

# --- Сохраняем правила для iptables-persistent ---
netfilter-persistent save

echo "=============================="
echo "✅ Xray Reality сервер готов"
echo "IPv4: ${IPV4:-нет}"
echo "IPv6: ${IPV6:-нет}"
echo "UUID: $UUID"
echo "Public Key: $PUBLIC_KEY"
echo "Short IDs: $SID1 $SID2 $SID3"
echo "=============================="

