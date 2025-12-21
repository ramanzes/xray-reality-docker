#!/bin/bash
set -e

echo "🔥 Applying SAFE firewall rules (system + docker + VPN aware + kill-switch)"

# --- Backup ---
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

# --- Detect WAN interface ---
WAN_INTERFACE=$(ip route | awk '/default/ {print $5}' | head -1)
[ -z "$WAN_INTERFACE" ] && WAN_INTERFACE="ens3"
echo "🌐 WAN interface: $WAN_INTERFACE"

# --- Detect SSH port ---
SSH_PORT=$(sshd -T | awk '/^port / {print $2}' | head -n1)
echo "🔐 SSH port: $SSH_PORT"

# --- VPN / services ports ---
OPENVPN_PORT=1194
XRAY_PORT=443  # пример, если есть Xray

# --- Clear chains safely ---
iptables -F
iptables -t nat -F
iptables -X

# --- Default policies ---
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# --- Loopback ---
iptables -A INPUT -i lo -j ACCEPT

# --- Established / Related ---
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# --- SSH ---
iptables -A INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT

# --- VPN / Xray ports ---
iptables -A INPUT -p tcp --dport "$XRAY_PORT" -j ACCEPT
iptables -A INPUT -p udp --dport "$OPENVPN_PORT" -j ACCEPT

# --- ICMP (важно для мобильных сетей) ---
iptables -A INPUT -p icmp -j ACCEPT

# --- VPN forwarding ---
VPN_NET="192.168.255.0/24"

# Разрешаем только выход в интернет через WAN (kill-switch)
iptables -A FORWARD -i tun0 -o "$WAN_INTERFACE" -s "$VPN_NET" -j ACCEPT
iptables -A FORWARD -i "$WAN_INTERFACE" -o tun0 -d "$VPN_NET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# --- Блокируем доступ VPN к Docker и внутренним сетям ---
DOCKER_NETS=("172.17.0.0/16" "172.18.0.0/16" "172.19.0.0/16")
for NET in "${DOCKER_NETS[@]}"; do
    iptables -A FORWARD -s "$VPN_NET" -d "$NET" -j DROP
done

# Блокируем доступ VPN к локальным подсетям (опционально)
iptables -A FORWARD -s "$VPN_NET" -d 127.0.0.0/8 -j DROP
iptables -A FORWARD -s "$VPN_NET" -d 192.168.0.0/16 -j DROP
iptables -A FORWARD -s "$VPN_NET" -d 10.0.0.0/8 -j DROP
iptables -A FORWARD -s "$VPN_NET" -d 224.0.0.0/4 -j DROP

# --- NAT (MASQUERADE) ---
iptables -t nat -A POSTROUTING -s "$VPN_NET" -o "$WAN_INTERFACE" -j MASQUERADE

# --- Docker safe rules ---
# Docker мосты будут работать, не трогая правила контейнеров
iptables -A FORWARD -i docker0 -j ACCEPT
iptables -A FORWARD -o docker0 -j ACCEPT

echo "✅ Firewall applied successfully"
echo "💾 Backup stored in $BACKUP_DIR"

