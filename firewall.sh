#!/bin/bash
set -e

echo "🔥 Applying SAFE firewall rules (system + docker aware)"

BACKUP_DIR="./iptables_backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "💾 Backing up current iptables rules..."
iptables-save > "$BACKUP_DIR/iptables_v4.rules"
ip6tables-save > "$BACKUP_DIR/iptables_v6.rules"

cat > "$BACKUP_DIR/RESTORE.txt" <<EOF
To restore rules:
iptables-restore < iptables_v4.rules
ip6tables-restore < iptables_v6.rules
EOF

echo "🔥 Applying VPN-aware firewall rules"

### === Определяем интерфейс ===
WAN_INTERFACE=$(ip route | awk '/default/ {print $5}' | head -1)
[ -z "$WAN_INTERFACE" ] && WAN_INTERFACE="eth0"
echo "🌐 WAN interface: $WAN_INTERFACE"

### === SSH порт ===
SSH_PORT=$(sshd -T | awk '/^port / {print $2}' | head -n1)
echo "🔐 SSH port: $SSH_PORT"

### === VPN / Xray ===
XRAY_PORT=443
OPENVPN_PORT=1194

### === Очистка ===
iptables -F
iptables -t nat -F
iptables -X

### === Политики ===
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

### === Loopback ===
iptables -A INPUT -i lo -j ACCEPT

### === Established ===
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

### === SSH ===
iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT

### === VPN / Xray ===
iptables -A INPUT -p tcp --dport "$XRAY_PORT" -j ACCEPT
iptables -A INPUT -p udp --dport "$OPENVPN_PORT" -j ACCEPT

### === ICMP (важно для мобильных сетей) ===
iptables -A INPUT -p icmp -j ACCEPT

### === FORWARD для VPN сетей ===
iptables -A FORWARD -s 10.0.0.0/8 -j ACCEPT
iptables -A FORWARD -d 10.0.0.0/8 -j ACCEPT

### === NAT ===
iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o "$WAN_INTERFACE" -j MASQUERADE

### === Docker (если используется) ===
iptables -A FORWARD -i docker0 -j ACCEPT
iptables -A FORWARD -o docker0 -j ACCEPT

echo "✅ Firewall applied successfully"



systemctl restart iptables.service
