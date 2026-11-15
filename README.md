# EasyAI

Минимальный iOS-клиент для нейросети через OpenAI-совместимый API
`https://api.aikeysforyou.com/v1` (модель `deepseek-v4-flash`).

Написано на **SwiftUI** (iOS 17+). Сборка — **GitHub Actions** на macOS-раннере,
Xcode-проект генерируется из `project.yml` через [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Что умеет

- Ввод API-ключа на экране входа; ключ хранится в **Keychain** (не в UserDefaults, не в репозитории)
- Стриминг ответов (печать по словам), кнопка «Стоп»
- Несколько чатов с сохранением на устройстве, переименование/удаление
- Выбор модели (DeepSeek V4 Flash по умолчанию), системный промпт, температура
- Светлая/тёмная тема, аккуратный чат-UI, копирование ответов

## Структура

```
project.yml                     # описание проекта для XcodeGen
EasyAI/
  EasyAIApp.swift               # точка входа, гейт по API-ключу
  Info.plist
  Models/                       # ChatMessage, Conversation, ModelInfo
  Services/                     # APIClient, ChatStore, AppSettings, KeychainStore, LocalStore
  Views/                        # ChatView, ChatListView, ApiKeyView, SettingsView, MessageBubble
.github/workflows/ios-build.yml # сборка .ipa
.github/ExportOptions.plist     # параметры экспорта для подписанной сборки
scripts/make-icon.swift         # пересборка иконки приложения (macOS)
```

## Сборка через GitHub Actions

Workflow запускается на каждый push в `main` и вручную (Actions → iOS build → Run workflow).
Артефакт **`EasyAI-ipa`** содержит `.ipa`.

### Без секретов (неподписанный .ipa)

Если секреты не заданы, собирается **неподписанный** `EasyAI-unsigned.ipa`.
Его ставят на устройство через переподпись своим Apple ID:

- [Sideloadly](https://sideloadly.io) — Windows/macOS, самый простой путь;
- [AltStore](https://altstore.io) / [SideStore](https://sidestore.io) — установка по Wi-Fi, авто-refresh.

С бесплатным Apple ID приложение живёт 7 дней, затем переподписать; с платным
Developer Program — до 1 года.

### С подписью своим сертификатом

Добавь в **Settings → Secrets and variables → Actions** репозитория:

| Секрет | Что это |
|---|---|
| `IOS_CERT_P12` | сертификат `.p12` (Apple Distribution / Development), закодированный в base64 |
| `IOS_CERT_PASSWORD` | пароль от `.p12` |
| `IOS_PROFILE` | provisioning profile `.mobileprovision` в base64 |
| `IOS_TEAM_ID` | Team ID из developer.apple.com |

Закодировать файлы (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12")) | Set-Content cert.b64
[Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision")) | Set-Content profile.b64
```

Profile должен содержать `com.m9mory.easyai` и UDID твоего устройства.
Имя профиля попадёт в `.github/ExportOptions.plist` автоматически не подставляется —
если имя профиля отличается от `EasyAI Development`, обнови ключ `provisioningProfiles`
в этом файле.

## Локальная сборка (нужен macOS + Xcode)

```bash
brew install xcodegen
xcodegen generate
open EasyAI.xcodeproj
```

Дальше — обычный Run. Для установки на телефон задай свою Team в Signing & Capabilities.

## API

Клиент обращается к стандартным эндпоинтам OpenAI-формата:

- `GET /v1/models` — список моделей (используется для проверки ключа)
- `POST /v1/chat/completions` с `"stream": true` — SSE-стриминг

Код: [APIClient.swift](EasyAI/Services/APIClient.swift).
