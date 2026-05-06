# Панель наказаний для Discord

Мини-сайт, где можно выдать, изменить и удалить наказание. Каждое действие отправляет уведомление в Discord-канал через webhook.

## Запуск

1. Создай файл `.env` рядом с `server.ps1` и вставь туда:

```bash
PORT=3000
DISCORD_WEBHOOK_URL=ССЫЛКА_ТВОЕГО_DISCORD_WEBHOOK
DISCORD_BOT_NAME=Punishment Panel
```

2. Запусти сайт в PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\server.ps1
```

3. Открой:

```text
http://localhost:3000
```

## Как взять webhook канала

В Discord открой настройки нужного канала, затем `Интеграции` -> `Вебхуки` -> `Новый вебхук`. Скопируй URL webhook и вставь его в `.env` как `DISCORD_WEBHOOK_URL`.

Важно: лучше давать сайту именно webhook URL, а не токен Discord-бота. Webhook привязан к одному каналу и безопаснее для такой задачи.

## Где лежат записи

Записи сохраняются в `data/punishments.json`. Этот файл создается автоматически после первого запуска.
