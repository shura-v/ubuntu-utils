#!/bin/bash

CONFIG="/usr/local/etc/xray/config.json"
PRIVATE_KEY=$(cat /etc/xray/private.key)
PUBLIC_KEY=$(cat /etc/xray/public.key)
SHORT_ID="12345678"
SERVER_NAME="www.cloudflare.com"

if [ ! -f "$CONFIG" ]; then
  echo "❌ Конфиг не найден. Установи Xray через ./cli.sh install"
  exit 1
fi

# Получение порта из конфига
PORT=$(jq -r '.inbounds[0].port' "$CONFIG")

UUID=$(cat /proc/sys/kernel/random/uuid)
read -p "Имя клиента (например: iphone): " NAME

apt-get install -y jq >/dev/null 2>&1
TMP=$(mktemp)
jq ".inbounds[0].settings.clients += [{\"id\":\"$UUID\",\"flow\":\"xtls-rprx-vision\",\"email\":\"$NAME\"}]" $CONFIG > "$TMP" && mv "$TMP" $CONFIG

systemctl restart xray

IP=$(curl -s ipv4.icanhazip.com)

# Сбор VLESS-ссылки
VLESS_LINK="vless://${UUID}@${IP}:${PORT}?encryption=none&security=reality&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&spx=%2F&type=tcp&flow=xtls-rprx-vision&sni=${SERVER_NAME}#${NAME}"

echo ""
echo "✅ Клиент '$NAME' добавлен!"
echo "📲 Строка для импорта:"
echo "$VLESS_LINK"
