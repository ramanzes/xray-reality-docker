#!/bin/bash
set -e

source .env_firewall

echo "🔥 Applying nftables firewall for VPN chain..."

# Проверка nft
if ! command -v nft >/dev/null; then
  echo "❌ nftables not installed"
  exit 1
fi

INTERFACE=$(ip -4 addr show | grep -v "127.0.0.1" | grep -oP '(ens\d+|eth\d+|enp\d+s\d+)' | head -1)
# Затем везде используйте $INTERFACE вместо ens3

# Полностью очищаем ВСЁ
nft flush ruleset

# Создаём таблицы
nft add table inet firewall
nft add table ip nat
nft add table ip6 nat 2>/dev/null || true

# INPUT с политикой DROP
nft add chain inet firewall input \
  "{ type filter hook input priority 0; policy drop; }"

# FORWARD - ОЧЕНЬ ВАЖНО для VPN цепочки!
nft add chain inet firewall forward \
  "{ type filter hook forward priority 0; policy drop; }"  # сначала DROP

# OUTPUT
nft add chain inet firewall output \
  "{ type filter hook output priority 0; policy accept; }"

# === INPUT RULES ===
# Loopback
nft add rule inet firewall input iif lo accept

# Established / Related
nft add rule inet firewall input ct state {established, related} accept

# SSH
nft add rule inet firewall input tcp dport $SSH_PORT accept

# Xray Reality (VLESS)
nft add rule inet firewall input tcp dport $XRAY_PORT accept

# OpenVPN порты
nft add rule inet firewall input udp dport 1194 accept
nft add rule inet firewall input tcp dport 443 accept  # для OpenVPN over TCP

# === FORWARD RULES - КЛЮЧЕВЫЕ для VPN цепочки ===
# Разрешаем forward для established/related
nft add rule inet firewall forward ct state {established, related} accept

# Разрешаем forward между интерфейсами:
# 1. Из локальной сети/сервера в интернет через $INTERFACE
nft add rule inet firewall forward iifname { lo, tun0 } oifname $INTERFACE accept

# 2. Из интернета на локальные сервисы (если нужно)
nft add rule inet firewall forward iifname $INTERFACE oifname { lo, tun0 } ct state {new, established, related} accept

# 3. Между VPN интерфейсами (если несколько VPN)
nft add rule inet firewall forward iifname tun0 oifname tun0 accept

# Ping
if [ "$ALLOW_PING" = "yes" ]; then
  nft add rule inet firewall input ip protocol icmp accept
  nft add rule inet firewall input ip6 nexthdr icmpv6 accept
  nft add rule inet firewall forward ip protocol icmp accept
  nft add rule inet firewall forward ip6 nexthdr icmpv6 accept
fi

# === NAT / MASQUERADE - КРИТИЧНО для VPN ===
# IPv4 NAT chain
nft add chain ip nat postrouting \
  "{ type nat hook postrouting priority 100; policy accept; }"

# Masquerade для:
# 1. Основного интерфейса ($INTERFACE)
nft add rule ip nat postrouting oifname $INTERFACE masquerade

# 2. Для трафика из VPN туннеля
nft add rule ip nat postrouting oifname $INTERFACE ip saddr 10.8.0.0/24 masquerade

# 3. Для локального трафика (если нужно)
nft add rule ip nat postrouting ip saddr 192.168.0.0/16 oifname $INTERFACE masquerade

# IPv6 NAT (если используется)
if [ "$ENABLE_IPV6" = "true" ]; then
  nft add chain ip6 nat postrouting \
    "{ type nat hook postrouting priority 100; policy accept; }"
  nft add rule ip6 nat postrouting oifname $INTERFACE masquerade
fi

echo "✅ nftables firewall for VPN chain applied"

# Сохраняем правила
nft list ruleset > /etc/nftables.conf

# Включаем IP forwarding (ОБЯЗАТЕЛЬНО!)
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Сохраняем для перезагрузки
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf

systemctl restart nftables

echo "📋 Правила применены. Проверяем:"
nft list ruleset | head -50
