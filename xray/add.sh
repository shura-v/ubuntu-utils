#!/bin/bash

CONFIG="/usr/local/etc/xray/config.json"

# Проверка наличия конфига
if [ ! -f "$CONFIG" ]; then
  echo "❌ Конфиг не найден: $CONFIG"
  exit 1
fi

# Проверка наличия jq
if ! command -v jq >/dev/null 2>&1; then
  echo "🔧 Устанавливаю jq..."
  apt-get update && apt-get install -y jq
fi

# Извлекаем параметры из конфига
PORT=$(jq -r '.inbounds[0].port' "$CONFIG")
SERVER_NAME=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$CONFIG")
SHORT_ID=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0]' "$CONFIG")
PUBLIC_KEY=$(cat /etc/xray/public.key)

UUID=$(cat /proc/sys/kernel/random/uuid)
read -p "Имя клиента (например: iphone): " NAME

# Добавляем клиента
TMP=$(mktemp)
jq ".inbounds[0].settings.clients += [{\"id\":\"$UUID\",\"flow\":\"xtls-rprx-vision\",\"email\":\"$NAME\"}]" "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
systemctl restart xray

IP=$(curl -s ipv4.icanhazip.com)
VLESS_LINK="vless://${UUID}@${IP}:${PORT}?encryption=none&security=reality&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&spx=%2F&type=tcp&flow=xtls-rprx-vision&sni=${SERVER_NAME}#${NAME}"

echo ""
echo "✅ Клиент '$NAME' добавлен!"
echo "📲 Ссылка для импорта:"
echo "$VLESS_LINK"
