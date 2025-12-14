#!/bin/bash
set -e

source .env_firewall

echo "🔥 Applying nftables firewall..."

# Проверка nft
if ! command -v nft >/dev/null; then
  echo "❌ nftables not installed"
  exit 1
fi

# Очистка старых правил ТОЛЬКО nft
nft flush ruleset

# Создаём таблицу
nft add table inet firewall

# INPUT
nft add chain inet firewall input \
  "{ type filter hook input priority 0; policy drop; }"

# FORWARD (Docker)
nft add chain inet firewall forward \
  "{ type filter hook forward priority 0; policy accept; }"

# OUTPUT
nft add chain inet firewall output \
  "{ type filter hook output priority 0; policy accept; }"

# Loopback
nft add rule inet firewall input iif lo accept

# Established / Related
nft add rule inet firewall input ct state established,related accept

# SSH
nft add rule inet firewall input tcp dport $SSH_PORT accept

# Xray Reality
nft add rule inet firewall input tcp dport $XRAY_PORT accept

# VPN UDP
for port in $VPN_UDP_PORTS; do
  nft add rule inet firewall input udp dport $port accept
done

# VPN TCP
for port in $VPN_TCP_PORTS; do
  nft add rule inet firewall input tcp dport $port accept
done

# Ping
if [ "$ALLOW_PING" = "yes" ]; then
  nft add rule inet firewall input ip protocol icmp accept
  nft add rule inet firewall input ip6 nexthdr icmpv6 accept
else
  nft add rule inet firewall input ip protocol icmp drop
  nft add rule inet firewall input ip6 nexthdr icmpv6 drop
fi

echo "✅ nftables firewall applied"
