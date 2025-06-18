#!/bin/bash

COMMAND=$1
SCRIPTS_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CONFIG=/usr/local/etc/xray/config.json

show_help() {
  echo ""
  echo "🧭 Xray CLI"
  echo ""
  echo "Использование:"
  echo "  ./cli.sh install     — установка Xray (VLESS + REALITY)"
  echo "  ./cli.sh add         — добавить клиента"
  echo "  ./cli.sh list        — список клиентов"
  echo "  ./cli.sh remove      — удалить клиента"
  echo "  ./cli.sh restart     — перезапустить"
  echo "  ./cli.sh config      — редактировать конфигурацию"
  echo "  ./cli.sh log         — показать логи"
  echo "  ./cli.sh status      — статус xray"
  echo ""
}

install() {
  read -p "Введите порт для Xray [по умолчанию 8443]: " PORT
  PORT=${PORT:-8443}

  # Проверка порта на валидность
  if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "❌ Неверный формат порта. Пожалуйста, введите целое число."
    exit 1
  fi

  # Проверка на существующие ключи
  if [ -f /etc/xray/private.key ] || [ -f /etc/xray/public.key ]; then
    echo "❌ Ключи уже существуют. Перезапись невозможна."
    echo "rm /etc/xray/private.key /etc/xray/public.key"
    exit 1
  fi

  echo "🔧 Установка Xray-core..."
  bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

  echo "🔐 Генерация X25519 ключей..."
  KEYS=$(xray x25519)
  PRIVATE_KEY=$(echo "$KEYS" | grep "Private key" | awk '{print $3}')
  PUBLIC_KEY=$(echo "$KEYS" | grep "Public key" | awk '{print $3}')
  SHORT_ID=$(openssl rand -hex 4)

  mkdir -p /etc/xray
  echo "$PRIVATE_KEY" > /etc/xray/private.key
  echo "$PUBLIC_KEY" > /etc/xray/public.key

  cat <<EOF > $CONFIG
{
  "inbounds": [
    {
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "cdn.jsdelivr.net:443",
          "xver": 0,
          "serverNames": ["cdn.jsdelivr.net"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

  cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray REALITY Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xray -config /usr/local/etc/xray/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  sudo ufw allow $PORT/tcp
  systemctl daemon-reload
  systemctl enable xray
  systemctl restart xray

  echo ""
  echo "✅ Xray установлен с REALITY на порту $PORT!"
  echo "Public Key для клиента: $PUBLIC_KEY"
  echo "Теперь используй ./cli.sh add для добавления клиента"
}

check_config() {
  if [ ! -f "$CONFIG" ]; then
    echo "❌ Конфиг не найден: $CONFIG"
    exit 1
  fi

  # Проверка наличия jq
  if ! command -v jq >/dev/null 2>&1; then
    echo "🔧 Устанавливаю jq..."
    apt-get update && apt-get install -y jq
  fi
}

list() {
  # Извлечение списка клиентов
  CLIENTS=$(jq -r '.inbounds[0].settings.clients[] | "\(.email) \(.id)"' "$CONFIG")

  if [ -z "$CLIENTS" ]; then
    echo "🤷 Нет добавленных клиентов."
    return 0
  fi

  echo "📋 Список клиентов Xray:"
  echo "------------------------"
  echo "$CLIENTS" | while read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    UUID=$(echo "$line" | awk '{print $2}')
    echo "👤 $NAME"
    echo "   🔐 UUID: $UUID"
  done
}

add() {
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
}

remove() {
  if [[ "$1" == "--all" ]]; then
    read -p "❗ Ты точно хочешь удалить всех клиентов? [y/N]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
      TMP=$(mktemp)
      jq '.inbounds[0].settings.clients = []' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
      systemctl restart xray
      echo "🧹 Все клиенты удалены."
    else
      echo "🚫 Отменено."
    fi
    return
  fi

  if [ "$#" -lt 1 ]; then
    read -p "Введите имя клиента для удаления (например: iphone): " NAME
    set -- "$NAME"
  fi

  for CLIENT_NAME in "$@"; do
    EXISTS=$(jq -r --arg name "$CLIENT_NAME" '.inbounds[0].settings.clients[] | select(.email == $name)' "$CONFIG")

    if [ -z "$EXISTS" ]; then
      echo "⚠️  Клиент '$CLIENT_NAME' не найден."
    else
      TMP=$(mktemp)
      jq --arg name "$CLIENT_NAME" '(.inbounds[0].settings.clients) |= map(select(.email != $name))' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
      echo "🗑️ Клиент '$CLIENT_NAME' удалён."
    fi
  done

  systemctl restart xray
}

case "$COMMAND" in
  install)
    install
    ;;
  list)
    check_config;
    list
    ;;
  add)
    list;
    add
    ;;
  remove)
    check_config
    list
    shift
    remove "$@"
    ;;
  restart)
    systemctl restart xray
    ;;
  config)
    nano $CONFIG && systemctl restart xray
    ;;
  log)
    journalctl -u xray -e
    ;;
  status)
    systemctl status xray
    ;;
  *)
    show_help
    ;;
esac
