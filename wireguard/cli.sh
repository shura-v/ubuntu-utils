#!/bin/bash

COMMAND=$1
ARG=$2
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

show_help() {
  echo ""
  echo "🧭 WireGuard CLI"
  echo ""
  echo "Использование:"
  echo "  ./cli.sh install     — установка WireGuard"
  echo "  ./cli.sh add         — добавить клиента"
  echo "  ./cli.sh list        — список клиентов"
  echo "  ./cli.sh remove      — удалить клиента"
  echo "  ./cli.sh config      — редактировать конфигурацию"
  echo "  ./cli.sh log         — показать логи"
  echo "  ./cli.sh status      — статус WireGuard"
  echo ""
}

case "$COMMAND" in
  install)
    bash "$SCRIPTS_DIR/install.sh"
    ;;
  add)
    bash "$SCRIPTS_DIR/add.sh"
    ;;
  list)
    bash "$SCRIPTS_DIR/list.sh"
    ;;
  remove)
    bash "$SCRIPTS_DIR/remove.sh" $ARG
    ;;
  config)
    nano /etc/wireguard/wg0.conf && systemctl restart wg-quick@wg0
    ;;
  log)
    journalctl -u wg-quick@wg0 -e
    ;;
  status)
    wg show
    ;;
  *)
    show_help
    ;;
esac
