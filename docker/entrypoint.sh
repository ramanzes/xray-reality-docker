#!/bin/bash
set -e

if [ ! -f /app/.env ]; then
  echo "▶ Инициализация сервера..."
  /app/scripts/init_xray_server.sh
fi

echo "▶ Запуск Xray..."
exec xray run -config /app/xray/config.json
