#!/bin/bash

# Абсолютный путь к текущему репозиторию
REPO_PATH="$(cd "$(dirname "$0")" && pwd)"

# Путь назначения для системных бинари
BIN_DIR="/usr/local/bin"

# Список пар: [target name] [source path]
declare -A links=(
  ["mywg"]="$REPO_PATH/wireguard/cli.sh"
  ["myxray"]="$REPO_PATH/xray/cli.sh"
  ["mystats"]="$REPO_PATH/stats/cli.sh"
)

for name in "${!links[@]}"; do
  src="${links[$name]}"
  dst="$BIN_DIR/$name"

  # Проверка наличия и перезапись
  if [ -L "$dst" ] || [ -f "$dst" ]; then
    echo "🔁 Обновляю $dst"
    sudo rm -f "$dst"
  else
    echo "🔗 Создаю ссылку $dst"
  fi

  sudo ln -s "$src" "$dst"
  sudo chmod +x "$src"

  echo "✅ Команда ${name} теперь доступна глобально."
done
