#!/bin/bash

set -e

WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/wg0.conf"

# Проверка наличия конфигурации WireGuard
if [ ! -f "$WG_CONF" ]; then
  echo "❌ Файл конфигурации WireGuard не найден: $WG_CONF"
  exit 1
fi

# Перечисление всех клиентов из конфигурации
echo "📋 Список клиентов WireGuard:"
echo "----------------------------"

grep -n '^# client_' "$WG_CONF" | while IFS=":" read -r LINE_NUM LINE_CONTENT; do
  CLIENT_NAME=$(echo "$LINE_CONTENT" | sed 's/^# client_//')
  # Следующие 5 строк после комментария — потенциальный блок клиента
  BLOCK=$(tail -n +"$((LINE_NUM+1))" "$WG_CONF" | head -n 5)

  # Извлекаем IP из блока
  CLIENT_IP=$(echo "$BLOCK" | grep -m1 '^AllowedIPs' | awk -F'=' '{print $2}' | xargs)

  echo "👤 Клиент: $CLIENT_NAME"
  echo "📡 IP:     $CLIENT_IP"
  echo "----------------------------"
done

echo "✅ Список клиентов завершён!"
