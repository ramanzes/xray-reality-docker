#!/bin/bash
set -e

echo "🔥 Applying SAFE firewall rules (Docker-aware)"

### 1. Определяем SSH порт корректно
SSH_PORT=$(sshd -T | awk '/^port / {print $2}' | head -n1)

echo "🔐 SSH port detected: $SSH_PORT"

### 2. Получаем Xray порт из .env
#source .env
#XRAY_PORT="$SERVER_PORT"

XRAY_PORT="443"

# Определяем WAN интерфейс (автоматически)
WAN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$WAN_INTERFACE" ]; then
  WAN_INTERFACE=$(ip -4 addr show | grep -v "127.0.0.1" | grep -oP '(ens\d+|eth\d+|enp\d+s\d+|en[ox]\d+s\d+)' | head -1)
fi
echo "🌐 Using WAN interface: ${WAN_INTERFACE:-eth0}"

iptables -t nat -A POSTROUTING -o $WAN_INTERFACE -j MASQUERADE

### 3. Разрешаем loopback
iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || \
iptables -A INPUT -i lo -j ACCEPT

ip6tables -C INPUT -i lo -j ACCEPT 2>/dev/null || \
ip6tables -A INPUT -i lo -j ACCEPT

### 4. Разрешаем ESTABLISHED
iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

ip6tables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

### 5. SSH
iptables -C INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT 2>/dev/null || \
iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT

ip6tables -C INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT 2>/dev/null || \
ip6tables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT

### 6. Xray Reality
iptables -C INPUT -p tcp --dport "$XRAY_PORT" -j ACCEPT 2>/dev/null || \
iptables -A INPUT -p tcp --dport "$XRAY_PORT" -j ACCEPT

ip6tables -C INPUT -p tcp --dport "$XRAY_PORT" -j ACCEPT 2>/dev/null || \
ip6tables -A INPUT -p tcp --dport "$XRAY_PORT" -j ACCEPT

### 7. Docker traffic (КРИТИЧНО)
#iptables -C FORWARD -j DOCKER-USER 2>/dev/null || true

#iptables -C DOCKER-USER -j RETURN 2>/dev/null || \
#iptables -I DOCKER-USER -j RETURN

echo "✅ Firewall rules applied safely"
