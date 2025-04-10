#!/bin/bash

set -e

# Проверка, что WireGuard ещё не установлен
if ! command -v wg &> /dev/null; then
  echo "🔧 Устанавливаем WireGuard..."
  sudo apt update
  sudo apt install -y wireguard wireguard-tools
else
  echo "🔧 WireGuard уже установлен!"
fi

# Генерация ключей для сервера
echo "🔐 Генерация ключей для сервера..."
sudo mkdir -p /etc/wireguard
wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
sudo systemctl enable wg-quick@wg0

PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
PUBLIC_KEY=$(cat /etc/wireguard/publickey)

# Порт, который будет использоваться для прослушивания
PORT=41641
sudo ufw allow $(echo $PORT)/udp
sudo ufw reload

# Генерация конфигурации для сервера
echo "🔧 Генерация конфигурации для сервера..."
WAN_IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
cat <<EOF | sudo tee /etc/wireguard/wg0.conf > /dev/null
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = $PORT

# Разрешаем форвард трафика
PostUp = ufw route allow in on wg0 out on $WAN_IFACE
PostUp = iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o $WAN_IFACE -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o $WAN_IFACE -j MASQUERADE

# Добавляем peer позже через add.sh
EOF


# Включение IP форвардинга
echo "🔧 Включаем IP форвардинг..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1

# Сохранение настроек
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf

cat /etc/wireguard/wg0.conf

# Запуск WireGuard
echo "🔧 Запускаем WireGuard..."
sudo systemctl start wg-quick@wg0

cat /etc/wireguard/wg0.conf

# Публичный ключ сервера
echo "✅ Генерация завершена!"
echo "🔑 Приватный ключ сервера: $PRIVATE_KEY"
echo "🔑 Публичный ключ сервера: $PUBLIC_KEY"

# Перезагрузка WireGuard
sudo systemctl restart wg-quick@wg0

cat /etc/wireguard/wg0.conf

echo "📄 Конфигурация для сервера сохранена в /etc/wireguard/wg0.conf"
echo "🚀 Не забудь добавить клиентов через ./add.sh"
