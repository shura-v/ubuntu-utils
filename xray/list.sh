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

# Извлечение списка клиентов
CLIENTS=$(jq -r '.inbounds[0].settings.clients[] | "\(.email) \(.id)"' "$CONFIG")

if [ -z "$CLIENTS" ]; then
  echo "🤷 Нет добавленных клиентов."
  exit 0
fi

echo "📋 Список клиентов Xray:"
echo "------------------------"
echo "$CLIENTS" | while read -r line; do
  NAME=$(echo "$line" | awk '{print $1}')
  UUID=$(echo "$line" | awk '{print $2}')
  echo "👤 $NAME"
  echo "   🔐 UUID: $UUID"
done

