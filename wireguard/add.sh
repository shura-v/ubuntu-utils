#!/bin/bash

set -e

WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/wg0.conf"
IP=$(curl -s ipv4.icanhazip.com)
SERVER_ENDPOINT="$IP:41641"

# Проверка wg0.conf
if [ ! -f "$WG_CONF" ]; then
  echo "❌ Файл $WG_CONF не найден!"
  exit 1
fi

# Получение публичного ключа сервера
SERVER_PUB=$(wg pubkey < "$WG_DIR/privatekey")

# Ввод имени клиента
read -p "Введите имя клиента: " CLIENT_NAME
if [ -z "$CLIENT_NAME" ]; then
  echo "❌ Имя клиента не может быть пустым."
  exit 1
fi

# Проверка, существует ли уже конфиг или ключи с таким именем
if [ -f "$WG_DIR/$CLIENT_NAME-privatekey" ] || [ -f "$WG_DIR/$CLIENT_NAME-publickey" ] || [ -f "$WG_DIR/$CLIENT_NAME.conf" ]; then
  echo "❌ Клиент с именем '$CLIENT_NAME' уже существует. Удалите старые файлы или выберите другое имя."
  exit 1
fi

# Ввод IP клиента
read -p "Введите IP клиента (например: 10.0.0.3): " CLIENT_IP
if [ -z "$CLIENT_IP" ]; then
  echo "❌ IP клиента не может быть пустым."
  exit 1
fi

# Проверка, используется ли уже указанный IP
if grep -q "$CLIENT_IP/32" "$WG_CONF"; then
  echo "❌ IP $CLIENT_IP уже используется в $WG_CONF!"
  exit 1
fi

# Генерация ключей клиента
wg genkey | tee "$WG_DIR/$CLIENT_NAME-privatekey" | wg pubkey > "$WG_DIR/$CLIENT_NAME-publickey"

CLIENT_PRIV=$(cat "$WG_DIR/$CLIENT_NAME-privatekey")
CLIENT_PUB=$(cat "$WG_DIR/$CLIENT_NAME-publickey")

# Добавление клиента в конфиг
{
  echo "# client_$CLIENT_NAME"
  echo "[Peer]"
  echo "PublicKey = $CLIENT_PUB"
  echo "AllowedIPs = $CLIENT_IP/32"
} | sudo tee -a "$WG_CONF" > /dev/null

echo "✅ Добавлен в $WG_CONF"

# Перезапуск WireGuard
echo "🔄 Перезапускаем WireGuard..."
sudo systemctl restart wg-quick@wg0

# Вывод всей конфигурации для клиента
cat <<EOF > "$WG_DIR/$CLIENT_NAME.conf"
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP/32
DNS = 10.0.0.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

echo "📄 Конфигурация клиента сгенерирована для подключения к серверу."
echo "📁 Ключи: $WG_DIR/$CLIENT_NAME-privatekey и $WG_DIR/$CLIENT_NAME-publickey"
echo "📁 Файл конфигурации: $WG_DIR/$CLIENT_NAME.conf"
