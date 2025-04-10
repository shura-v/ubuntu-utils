#!/bin/bash

bash ./list.sh

set -e

WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/wg0.conf"

# Проверка наличия конфигурации WireGuard
if [ ! -f "$WG_CONF" ]; then
  echo "❌ Файл конфигурации WireGuard не найден: $WG_CONF"
  exit 1
fi

# Запрашиваем у пользователя имя клиента для удаления
if [ "$#" -eq 1 ]; then
  CLIENT_NAME=$1
else
  read -p "Введите имя клиента для удаления (без префикса 'client_'): " CLIENT_NAME
fi

FULL_CLIENT_NAME=$CLIENT_NAME
# Добавляем префикс client_ для имени, если его нет
if [[ ! "$CLIENT_NAME" =~ ^client_ ]]; then
  FULL_CLIENT_NAME="client_$CLIENT_NAME"
fi

# Проверяем, существует ли в конфиге комментарий с нужным именем клиента
CLIENT_COMMENT="# $FULL_CLIENT_NAME"
CLIENT_LINE=$(grep -n "$CLIENT_COMMENT" "$WG_CONF" | cut -d: -f1)

if [ -z "$CLIENT_LINE" ]; then
  echo "❌ Клиент '$CLIENT_NAME' не найден в конфигурации WireGuard!"
  exit 1
fi

# Находим все строки, начиная с строки комментария до следующего комментария или конца
echo "Удаление клиента '$CLIENT_NAME' с линии: $CLIENT_LINE"
sudo sed -i "${CLIENT_LINE},/^#/d" "$WG_CONF"

# Удаляем ключи и конфиг клиента
sudo rm -f "$WG_DIR/$CLIENT_NAME-privatekey"
sudo rm -f "$WG_DIR/$CLIENT_NAME-publickey"
sudo rm -f "$WG_DIR/$CLIENT_NAME.conf"

# Перезапуск WireGuard
echo "🔄 Перезапускаем WireGuard..."
sudo systemctl restart wg-quick@wg0

echo "✅ Клиент '$CLIENT_NAME' успешно удалён из конфигурации!"
