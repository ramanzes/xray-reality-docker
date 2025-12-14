#!/bin/bash

echo "🩺 Xray Health Check"
echo "==================="

echo -e "\n📦 Docker:"
docker ps | grep xray || echo "❌ Xray container not running"

echo -e "\n🔌 Ports:"
ss -tulpen | grep 443 || echo "❌ Port 443 not listening"

echo -e "\n📡 IPv4 Connectivity:"
curl -4 -s https://api.ipify.org && echo " ✔ IPv4 OK" || echo " ❌ IPv4 FAIL"

echo -e "\n📡 IPv6 Connectivity:"
curl -6 -s https://api64.ipify.org && echo " ✔ IPv6 OK" || echo " ⚠ IPv6 not available"

echo -e "\n📄 Xray Config:"
docker exec xray jq empty /app/xray/config.json \
  && echo " ✔ config.json valid" \
  || echo " ❌ config.json invalid"

echo -e "\n👥 Clients:"
docker exec xray jq '
{
  active: [.inbounds[].settings.clients[]?.email],
  disabled: [.inbounds[].settings.disabled_clients[]?.email]
}
' /app/xray/config.json

echo -e "\n🌐 Reality Check:"
source .env
curl --resolve www.cloudflare.com:443:$SERVER_IPV4 https://www.cloudflare.com -I \
  && echo " ✔ Reality dest reachable" \
  || echo " ❌ Reality dest error"

