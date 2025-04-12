#!/bin/bash

COMMAND=$1

show_help() {
  echo ""
  echo "📊 VPS Stats CLI"
  echo ""
  echo "Использование:"
  echo "  ./cli.sh install   — установка зависимостей"
  echo "  ./cli.sh btop      — графики CPU/RAM/диск/сеть (ASCII, fancy)"
  echo "  ./cli.sh glances   — общая статистика, всё в одном"
  echo "  ./cli.sh nload     — трафик RX/TX"
  echo "  ./cli.sh iotop     — ввод/вывод на диске по процессам"
  echo "  ./cli.sh dstat     — детальная сводка по всем ресурсам"
  echo ""
}

install() {
  echo "📦 Проверка и установка зависимостей..."
  
  REQUIRED_PACKAGES=(btop glances nload iotop dstat)
  
  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      echo "📥 Устанавливаю $pkg..."
      sudo apt install -y "$pkg"
    else
      echo "✅ $pkg уже установлен"
    fi
  done    
}

case "$COMMAND" in
  install)
    install
    ;;
  btop)
    command -v btop >/dev/null && exec btop || echo "❌ btop не установлен"
    ;;
  glances)
    command -v glances >/dev/null && exec glances || echo "❌ glances не установлен"
    ;;
  nload)
    command -v nload >/dev/null && exec nload || echo "❌ nload не установлен"
    ;;
  iotop)
    sudo iotop
    ;;
  dstat)
    command -v dstat >/dev/null && exec dstat || echo "❌ dstat не установлен"
    ;;
  *)
    show_help
    ;;
esac
