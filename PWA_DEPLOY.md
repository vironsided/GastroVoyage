# GastroVoyage — Бесплатный деплой PWA для iPhone

У тебя нет Mac → нативный App Store / TestFlight закрыт. Этот гайд проводит
через единственный полностью бесплатный путь: **Flutter Web → PWA**, доступный
на iPhone Safari через "Add to Home Screen".

После деплоя:
- открываешь URL в Safari на iPhone 16 Pro Max
- нажимаешь `Поделиться → На экран «Домой»`
- иконка появляется на главном экране, запускается в режиме standalone (без
  адресной строки) — выглядит как родное приложение

---

## Архитектура деплоя

```
iPhone Safari ──► Vercel (Flutter Web)
                   │
                   └──► Render (FastAPI) ──► Supabase
```

- **Frontend (Flutter Web)**: Vercel — бесплатно, 100 GB трафика/мес
- **Backend (FastAPI)**: Render — бесплатно, засыпает после 15 мин неактивности
  (первый запрос после сна — 30с холодный старт)
- **DB**: Supabase — у тебя уже есть, ничего менять не нужно

Альтернативы: Cloudflare Pages (frontend), Fly.io / Railway (backend).
Готовая конфигурация уже в репо: `mobile/vercel.json`, `backend/render.yaml`.

---

## Что НЕ работает в Web-версии

Эти фичи требуют нативных плагинов, недоступных в браузере:

| Фича | Поведение в web | Workaround |
|---|---|---|
| Камера | Только выбор файла из библиотеки фото | iOS дает выбрать из галереи через стандартный input — UX отличается |
| Google/Apple OAuth | Нужен отдельный web Client ID | Можно добавить позже — кнопки покажут "не настроено" |
| Push-уведомления | iOS Safari Web Push есть с 16.4+, но требует PWA-установки | После Add to Home Screen работает ограниченно |
| PDF passport export | Через web printing API — работает, но без share-sheet | Тап → download |
| Карты flutter_map | Работает, но WebGL может лагать на старых iPhone | iPhone 16 Pro Max справится |

Остальные ~95% фич — паспорт, журнал, Explore, Search, Wrapped, Social,
Stories, Notifications, Achievements, Couples Journey, Bucket list — работают
из коробки.

---

## Шаги деплоя

### 1. Запушить репо на GitHub

```bash
cd /mnt/c/Users/vusal/OneDrive/Desktop/GastroVoyage
git init
git add .
git commit -m "initial commit"
gh repo create gastrovoyage --private --source=. --push
# или вручную создай репо на github.com и git push
```

Render и Vercel оба умеют деплоить только из Git-репозитория.

### 2. Backend на Render

1. Зайти на [render.com](https://render.com) → "New +" → "Blueprint"
2. Подключить GitHub-репо `gastrovoyage`
3. Render найдет `backend/render.yaml` и предложит создать сервис
4. Заполнить переменные окружения (Render запросит их при создании):
   - `SUPABASE_URL` = `https://hhdcohovxegvildfetvy.supabase.co`
   - `SUPABASE_SERVICE_KEY` = (твой service key из `.env`)
   - `CORS_ORIGINS` = `https://gastrovoyage.vercel.app` (заменишь после шага 3)
5. Деплой запустится автоматически (~3–5 мин)
6. Запиши URL вида `https://gastrovoyage-api.onrender.com`

Проверь: `curl https://gastrovoyage-api.onrender.com/health` → `{"status":"ok"}`

### 3. Frontend на Vercel

1. Зайти на [vercel.com](https://vercel.com) → "Add New" → "Project"
2. Импортировать тот же GitHub-репо
3. **Root directory**: установить в `mobile`
4. **Framework preset**: Other (Vercel найдет `vercel.json`)
5. Environment Variables:
   - `API_URL` = URL из шага 2 (`https://gastrovoyage-api.onrender.com`)
6. Deploy (~5–8 мин — первая сборка качает Flutter SDK)
7. Запиши URL вида `https://gastrovoyage.vercel.app`

### 4. Обратно в Render — обновить CORS

В Render Dashboard → твой сервис → Environment → обновить `CORS_ORIGINS` на
финальный Vercel-URL → "Save Changes" (триггерит редеплой).

### 5. Открыть на iPhone

1. На iPhone 16 Pro Max открой Safari
2. Перейди на `https://gastrovoyage.vercel.app`
3. Нажми кнопку `Поделиться` в нижней панели Safari
4. Прокрути вниз → `На экран «Домой»`
5. Иконка GastroVoyage появится на главном экране
6. Тап по иконке → запускается в полноэкранном режиме без браузерной обёртки

---

## Cold start (первый запуск приложения)

Render free засыпает после 15 мин неактивности. Если ты открываешь приложение
после простоя — первый API-запрос будет грузиться ~30 секунд (пока Render
будит контейнер). Сам Flutter Web уже закэширован, так что приложение
рисуется мгновенно, но контент `Could not load. Is the backend running?`
покажется до пробуждения бэкенда.

**Решения:**
- Платный план Render ($7/мес) — нет сна
- Cron-job уведомлений раз в 10 мин (например через [cron-job.org](https://cron-job.org)) дёргать `/health` — держит бэкенд тёплым

---

## После первого деплоя — оптимизации

Когда приложение поедет на iPhone, фокус смещается на:

1. **Image caching** — Skia/CanvasKit агрессивно кэширует. Замерить размер
   cache, выставить maxByteSize на CachedNetworkImage.
2. **CanvasKit bundle** — сейчас 19 MB. Можно переключиться на html-renderer:
   `flutter build web --web-renderer html` — бандл становится ~5 MB вместо 27 MB,
   но scrapbook-эстетика (custom painters, gradients) может выглядеть иначе.
   Рекомендую сначала проверить дефолт.
3. **Service worker** — Flutter генерирует SW автоматически, кэширует все
   ассеты после первой загрузки. После Add to Home Screen первая страница
   открывается за 200мс.
4. **Lazy-load шрифтов** — Caveat/Playfair/Hanken/JetBrains грузятся через
   google_fonts на runtime. Можно встроить .ttf в assets и сразу `flutter_fonts`,
   быстрее на старте.

---

## Известные ограничения PWA на iOS Safari

- Memory cap: ~250 MB на PWA → большие списки визитов могут лагать после 100+ записей
- IndexedDB ограничен 50 MB → большие фото-кэши не пройдут
- Background fetch не работает → нельзя пре-загружать данные пока app закрыт
- App Switcher показывает иконку с заголовком как в Safari → не как нативка

Эти ограничения существенны только при тяжёлом использовании. Для
демонстрации/тестирования UI работают отлично.

---

## Версия с твоими личными данными

API_URL и Supabase URL коммитятся как environment variables — никогда в код.
`mobile/lib/core/network/api_client.dart:55` уже использует
`String.fromEnvironment('API_URL', defaultValue: ...)`, так что разные
окружения собираются одной командой:

```bash
flutter build web --release --dart-define=API_URL=https://prod-api.com
flutter build web --release --dart-define=API_URL=https://staging-api.com
```

Vercel передает `API_URL` из env vars автоматически через `vercel.json`.
