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

# Имя клиента
read -p "Введите имя клиента для удаления (email, например: iphone): " NAME

# Проверка, существует ли такой пользователь
EXISTS=$(jq -r --arg name "$NAME" '.inbounds[0].settings.clients[] | select(.email == $name)' "$CONFIG")

if [ -z "$EXISTS" ]; then
  echo "❌ Клиент '$NAME' не найден в конфиге."
  exit 1
fi

# Удаление клиента
TMP=$(mktemp)
jq --arg name "$NAME" '(.inbounds[0].settings.clients) |= map(select(.email != $name))' "$CONFIG" > "$TMP"

mv "$TMP" "$CONFIG"
echo "🗑️ Клиент '$NAME' удалён."
systemctl restart xray
