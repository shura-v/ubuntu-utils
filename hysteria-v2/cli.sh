#!/bin/bash

COMMAND=$1
SCRIPTS_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

show_help() {
  echo ""
  echo "🧭 Hysteria2 CLI"
  echo ""
  echo "Использование:"
  echo "  ./cli.sh install     — установка Hysteria2 (UDP)"
  echo "  ./cli.sh config      — редактировать конфигурацию"
  echo "  ./cli.sh log         — показать логи"
  echo "  ./cli.sh status      — статус hysteria"
  echo ""
}

install() {
  read -p "Введите порт для Hysteria [по умолчанию 443]: " PORT
  PORT=${PORT:-443}

  if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "❌ Неверный формат порта. Пожалуйста, введите целое число."
    exit 1
  fi

  read -p "Введите пароль для клиента (можно придумать любой): " PASSWORD

  echo "🔧 Установка Hysteria2..."
  curl -L -o /usr/local/bin/hysteria https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64
  chmod +x /usr/local/bin/hysteria

  mkdir -p /etc/hysteria
  cat <<EOF > /etc/hysteria/config.yaml
listen: :$PORT
protocol: udp
auth:
  type: password
  password: "$PASSWORD"
obfs:
  type: salamander
  salamander:
    enabled: true
bandwidth:
  up: 100 mbps
  down: 100 mbps
EOF

  cat <<EOF > /etc/systemd/system/hysteria.service
[Unit]
Description=Hysteria2 UDP Proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  sudo ufw allow $PORT/udp
  systemctl daemon-reload
  systemctl enable hysteria
  systemctl restart hysteria

  IP=$(curl -s https://api.ipify.org || echo "не удалось определить")

  echo ""
  echo "✅ Hysteria2 установлен на порту $PORT (UDP)"
  echo "🔐 Пароль: $PASSWORD"
  echo "🌍 IP-адрес сервера: $IP"
  echo "Добавь это в клиентский конфиг и в путь!"
}

case "$COMMAND" in
  install)
    install
    ;;
  config)
    nano /etc/hysteria/config.yaml && systemctl restart hysteria
    ;;
  log)
    journalctl -u hysteria -e
    ;;
  status)
    systemctl status hysteria
    ;;
  *)
    show_help
    ;;
esac
