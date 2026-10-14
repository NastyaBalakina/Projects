#!/bin/bash
# Собирает приложение и ставит его в ~/Applications, затем запускает.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh

DEST="$HOME/Applications"
mkdir -p "$DEST"

# Если старая версия запущена — закрываем её перед заменой.
if pgrep -x FocusMetronome >/dev/null; then
  osascript -e 'quit app id "com.nastyabalakina.FocusMetronome"' >/dev/null 2>&1 || pkill -x FocusMetronome || true
  sleep 1
fi

rm -rf "$DEST/FocusMetronome.app"
cp -R build/FocusMetronome.app "$DEST/"
echo "✓ Установлено: $DEST/FocusMetronome.app"

open "$DEST/FocusMetronome.app"
echo "Иконка метронома появилась в строке меню справа вверху."
