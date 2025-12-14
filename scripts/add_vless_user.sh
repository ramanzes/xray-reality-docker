#!/bin/bash

source /app/.env

apt install jq qrencode -y

if [ -z "$1" ]; then
  echo "❌ Использование: $0 client_name"
  exit 1
fi
CLIENT_NAME="$1"

#SERVER_IP="37.46.16.212"
#PORT="443"
#SNI="www.cloudflare.com"
#SHORT_ID="123456"
#PUBLIC_KEY="hiLNbci89WD0R3bzmi1wV-8x4Ndx4ccWCeucsq0ZXBg"
#FLOW="xtls-rprx-vision"

#UUID=$(xray uuid)






#CONFIG="/usr/local/etc/xray/config.json"



LINK_V4="vless://$UUID@$SERVER_IPV4:443?encryption=none&security=reality&flow=xtls-rprx-vision&sni=www.cloudflare.com&fp=chrome&pbk=$PUBLIC_KEY&type=tcp#$CLIENT_NAME"

if [ -n "$SERVER_IPV6" ]; then
  LINK_V6="vless://$UUID@[${SERVER_IPV6}]:443?encryption=none&security=reality&flow=xtls-rprx-vision&sni=www.cloudflare.com&fp=chrome&pbk=$PUBLIC_KEY&type=tcp#$CLIENT_NAME"
fi


jq '.inbounds[0].settings.clients += [{
  "id": "'"$UUID"'",
  "flow": "'"$FLOW"'",
  "email": "'"$CLIENT_NAME"'"
}]' $CONFIG > /tmp/xray.json && mv /tmp/xray.json $CONFIG

systemctl restart xray

#LINK="vless://${UUID}@${SERVER_IP}:${PORT}?type=tcp&security=reality&flow=${FLOW}&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&alpn=h2,http/1.1#${CLIENT_NAME}"


#echo "$LINK" > "clients/${CLIENT_NAME}.txt"

{
  echo "# IPv4"
  echo "$LINK_V4"
  [ -n "$LINK_V6" ] && echo -e "\n# IPv6\n$LINK_V6"
} > "/app/clients/$CLIENT_NAME.txt"

echo "=============================="
echo "Клиент добавлен: $CLIENT_NAME"
echo "UUID: $UUID"
echo "Файл: ./clients/${CLIENT_NAME}.txt"
echo "QR в этом же код в файле"
echo "=============================="



qrencode -t ANSIUTF8 "$LINK" >> clients/${CLIENT_NAME}.txt

