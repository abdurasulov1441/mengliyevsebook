# BookHub — бэкенд

Сервер открытой книжной платформы BookHub: API для мобильного приложения, веб-панель администратора, конвертер книг (Word → формат для чтения на телефоне), оплата Payme/Click и ежемесячные выплаты авторам.

```
backend/
  src/routes/      API: auth, books (каталог/библиотека/чтение), studio (кабинет автора), orders (оплата), admin
  src/services/    platform.js — комиссия, начисления авторам, возвраты, выплаты, уведомления
  src/converter/   Word/EPUB/TXT → пакет книги (главы, оглавление, сноски, картинки) + EPUB
  src/openapi.js   описание API для Swagger
  public/admin/    веб-панель администратора (/admin)
  public/reader/   читалка (HTML/JS): та же, что в приложении
  scripts/         seed.js, convert.js, sync-reader.js, create-admin.js
  test/            сквозной тест всей платформы
  data/            база SQLite и файлы (создаётся сама, в git не попадает)
```

## Как устроена платформа

1. Любой пользователь входит по номеру телефона (SMS-код).
2. В профиле нажимает «Muallif bo'ling», заполняет имя, о себе и карту для выплат, принимает условия. После этого он автор.
3. Автор загружает `.docx` / `.epub` / `.txt` (+ обложку, цену или «бесплатно»). Сервер сам конвертирует файл, книга попадает в очередь модерации.
4. Админ читает книгу и нажимает «Tasdiqlash» (книга появляется в каталоге) или «Rad etish» с причиной (автор исправляет и отправляет снова).
5. Покупатель платит через Payme или Click. С каждой продажи платформа забирает комиссию (по умолчанию 30%), остальное начисляется автору. При возврате начисление списывается.
6. Раз в месяц админ создаёт выплаты за прошлый месяц («To'lovlar» → «… uchun to'lovlar»), переводит деньги на карты и отмечает «To'landi». Автор получает уведомление.
   Выплата создаётся, только если карта автора подтверждена админом и сумма не меньше минимальной (50 000 сум по умолчанию). Меньшая сумма переносится на следующий месяц.

Админ: номер **+998 90 096 17 04** (`ADMIN_PHONES` в `.env`). После входа по SMS в приложении появляется «Boshqaruv paneli». Тот же номер входит в веб-панель `/admin` по SMS-коду или паролю `ADMIN_PASSWORD`. Комиссия и минимальная выплата меняются в «Sozlamalar».

## Запуск (без Docker)

Нужен Node.js **22.13+** (лучше 24 LTS). Внешняя база не нужна: используется встроенный SQLite.

```bash
cd backend
npm install
cp .env.example .env        # заполнить (см. ниже)
npm run seed                # необязательно: демо-категории, 2 автора и 4 книги из seed-books/
npm start                   # http://localhost:3000
```

| Адрес | Что там |
|---|---|
| `http://localhost:3000/api/docs` | **Swagger**: все методы API, можно вызывать прямо из браузера |
| `http://localhost:3000/api/openapi.json` | спецификация OpenAPI 3 |
| `http://localhost:3000/admin/` | веб-панель администратора |
| `http://localhost:3000/api/health` | проверка, что сервер жив |

Как проверить API в Swagger:
1. `POST /api/auth/request-otp` с `{"phone": "998900961704"}`.
2. `POST /api/auth/verify` с `{"phone": "998900961704", "code": "111111"}`. В режиме разработки `DEV_OTP_CODE` подходит для любого номера. Скопируйте `accessToken`.
3. Нажмите **Authorize** вверху страницы и вставьте токен. Теперь доступны и методы автора, и методы админа.

Тест всей платформы: `npm test` (вход, заявка автора, загрузка, модерация, покупка, Payme и Click с подписями, возврат, комиссия, выплаты).

### На сервере (Linux)

```bash
git clone … && cd mengliyevsebook/backend
npm ci --omit=dev
cp .env.example .env && nano .env
npm start
```

Чтобы сервер работал постоянно и перезапускался сам, удобнее всего pm2:

```bash
npm i -g pm2
pm2 start src/server.js --name bookhub
pm2 save && pm2 startup
pm2 logs bookhub             # логи
```

Перед Node поставьте nginx или Caddy с HTTPS (Payme и Click требуют https) и `client_max_body_size 100m;` для загрузки книг. Резервная копия — это папка `data/` (или `DATA_DIR`).

Старые `.doc`, `.rtf` и `.odt` конвертируются полностью, если установлен LibreOffice (`apt install libreoffice-writer`). Без него из `.doc` извлекается только текст, а `.docx` работает всегда.

## `.env` для production

| Переменная | Значение |
|---|---|
| `NODE_ENV` | `production` (отключает `DEV_OTP_CODE` и демо-оплату) |
| `PUBLIC_URL` | адрес сервера, например `https://api.bookhub.uz` |
| `JWT_SECRET` | длинная случайная строка: `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"` |
| `ADMIN_PHONES` | номера админов через запятую (`998900961704`) |
| `ADMIN_PHONE`, `ADMIN_PASSWORD` | вход в веб-панель по паролю |
| `COMMISSION_PERCENT`, `PAYOUT_MIN` | значения по умолчанию, дальше меняются в панели |
| `SMS_LOGIN`, `SMS_PASSWORD`, `SMS_DRY_RUN=false` | GetSMS.uz. Сообщите им IP сервера, иначе SMS не уйдут |
| `PAYMENTS_DEMO` | `false` в production |
| `PAYME_*`, `CLICK_*` | ключи из кабинетов мерчанта (ниже) |

## Payme и Click

Кнопки Payme и Click появляются в приложении, как только заполнены их ключи. Кнопка «Demo to'lov» (покупка без денег, для проверки) показывается только при `PAYMENTS_DEMO=true`. Сейчас ключей нет, поэтому локально работает только она.

**Payme** (Merchant API). В кабинете business.payme.uz:
- endpoint: `https://<ваш-домен>/api/payments/payme`
- поле счёта: `order_id`
- в `.env`: `PAYME_MERCHANT_ID`, `PAYME_KEY` (для теста — ключ тестовой кассы и `PAYME_TEST=true`).

**Click** (SHOP API). В кабинете merchant.click.uz:
- Prepare URL: `https://<ваш-домен>/api/payments/click/prepare`
- Complete URL: `https://<ваш-домен>/api/payments/click/complete`
- в `.env`: `CLICK_SERVICE_ID`, `CLICK_MERCHANT_ID`, `CLICK_SECRET_KEY`.

После оплаты платёжная система возвращает пользователя на `/api/pay/return`. Приложение само проверяет статус заказа и открывает книгу.

Если оплата прошла, но заказ не закрылся (например, банковский перевод), админ может отметить его вручную: «Buyurtmalar» → «Kutilmoqda» → «To'landi».

## Основные разделы API

Полный список с параметрами есть в Swagger (`/api/docs`).

| Раздел | Пути |
|---|---|
| Вход | `POST /api/auth/request-otp`, `/auth/verify`, `/auth/refresh`, `/auth/logout`, `/auth/admin-login` |
| Профиль | `GET/PUT /api/me`, `/me/notifications`, `/me/orders`, `/me/library`, `/me/favorites` |
| Каталог | `GET /api/home`, `/books?q=&category_id=&is_free=&sort=`, `/books/:id`, `/categories`, `/authors/:id`, отзывы `/books/:id/reviews` |
| Чтение | `/books/:id/package.zip`, `/books/:id/preview.js` (бесплатный фрагмент), `/books/:id/reading` (синхронизация позиции) |
| Оплата | `POST /api/orders`, `GET /orders/:id`, колбэки `/payments/payme`, `/payments/click/*` |
| Кабинет автора | `/api/studio/profile`, `/studio/dashboard`, `/studio/books`, `/studio/earnings`, `/studio/payouts` |
| Админ | `/api/admin/stats`, `/admin/books` (+ approve/reject/unpublish), `/admin/authors`, `/admin/orders`, `/admin/payouts`, `/admin/settings`, `/admin/categories`, `/admin/users` |

## Конвертер

В Word-файлах авторов обычно нет стилей заголовков: главы набраны жирным, крупнее и по центру. Конвертер находит такие строки, ставит уровни заголовков по размеру шрифта и нумерации, склеивает «1» + «KIRISH», распознаёт титульный лист и ручное оглавление, переносит сноски в конец главы, сжимает картинки. Результат: `manifest.json` + `book.js` + `images/` + `book.epub` + `package.zip`.

Проверить файл без сервера: `npm run convert -- "C:\путь\книга.docx"`, затем открыть `backend/offline/index.html`.

## Читалка

Одна и та же в браузере и в приложении. Страницы или прокрутка, анимация перелистывания, шрифты, размер, интервал, поля, темы (светлая/сепия/тёмная/чёрная), оглавление, закладки, выделения с заметками, поиск, сноски, переносы узбекских слов. Позиция синхронизируется между устройствами. После правок в `public/reader` выполните `npm run sync-reader`: файлы скопируются в приложение (`assets/reader`).

## Мобильное приложение

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000             # эмулятор + сервер на этом ПК
flutter run --dart-define=API_URL=http://192.168.1.10:3000         # телефон в той же Wi-Fi
flutter build apk --release --dart-define=API_URL=https://api.bookhub.uz
```

Для push-уведомлений замените `android/app/google-services.json` и `lib/firebase_options.dart` файлами из своего проекта Firebase: текущий API-ключ недействителен. Без них приложение работает, только без push.
