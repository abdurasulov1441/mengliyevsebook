'use strict';

// OpenAPI 3 description of the BookHub API, shown at /api/docs.
// How to test: POST /api/auth/request-otp -> POST /api/auth/verify (code
// 111111 in development) -> copy accessToken -> "Authorize" button.

const config = require('./config');

const ref = (name) => ({ $ref: `#/components/schemas/${name}` });
const json = (schema, example) => ({ content: { 'application/json': { schema, ...(example ? { example } : {}) } } });
const ok = (schema, description = 'OK') => ({ description, ...json(schema) });
const id = (name = 'id', description = 'ID') => ({ name, in: 'path', required: true, schema: { type: 'integer' }, description });
const qp = (name, description, schema = { type: 'string' }) => ({ name, in: 'query', required: false, schema, description });
const multipart = (props, required = []) => ({ content: { 'multipart/form-data': { schema: { type: 'object', properties: props, required } } } });
const file = (description) => ({ type: 'string', format: 'binary', description });

const paths = {};
function op(method, path, tag, summary, extra = {}) {
  const o = { tags: [tag], summary, responses: extra.responses || { 200: { description: 'OK' } } };
  if (extra.description) o.description = extra.description;
  if (extra.auth !== false && extra.auth !== 'optional') o.security = [{ bearer: [] }];
  if (extra.auth === 'optional') o.security = [{}, { bearer: [] }];
  if (extra.params) o.parameters = extra.params;
  if (extra.body) o.requestBody = extra.body;
  paths[path] = paths[path] || {};
  paths[path][method] = o;
}

// ------------------------------------------------------------------ auth
op('post', '/api/auth/request-otp', 'Авторизация', 'Отправить SMS-код (вход и регистрация)', {
  auth: false,
  description: 'Работает для любого номера. В режиме разработки SMS не отправляется, код печатается в логе сервера, а также подходит код 111111 (DEV_OTP_CODE).',
  body: json({ type: 'object', required: ['phone'], properties: { phone: { type: 'string' } } }, { phone: '+998 90 096 17 04' }),
});
op('post', '/api/auth/verify', 'Авторизация', 'Подтвердить код → токены', {
  auth: false,
  description: 'Новый номер получает аккаунт. Номера из ADMIN_PHONES (по умолчанию 998900961704) становятся администраторами. Если user.needs_name=true — попросите имя и отправьте PUT /api/me.',
  body: json({ type: 'object', required: ['phone', 'code'], properties: { phone: { type: 'string' }, code: { type: 'string' }, name: { type: 'string' }, fcm_token: { type: 'string' } } }, { phone: '+998 90 096 17 04', code: '111111', name: 'Admin' }),
  responses: { 200: ok(ref('Session')) },
});
op('post', '/api/auth/refresh', 'Авторизация', 'Новый access-токен по refresh-токену', { auth: false, body: json({ type: 'object', properties: { refreshToken: { type: 'string' } } }) });
op('post', '/api/auth/logout', 'Авторизация', 'Выход (отзыв refresh-токена)', { auth: false, body: json({ type: 'object', properties: { refreshToken: { type: 'string' } } }) });
op('post', '/api/auth/admin-login', 'Авторизация', 'Вход в веб-панель: телефон + пароль', { auth: false, body: json({ type: 'object', properties: { phone: { type: 'string' }, password: { type: 'string' } } }) });

op('get', '/api/me', 'Профиль', 'Текущий пользователь', { responses: { 200: ok(ref('Me')) } });
op('put', '/api/me', 'Профиль', 'Изменить имя / аватар', { body: multipart({ name: { type: 'string' }, avatar: file('Аватар') }) });
op('get', '/api/me/notifications', 'Профиль', 'Уведомления');
op('post', '/api/me/notifications/read', 'Профиль', 'Отметить все прочитанными');
op('post', '/api/me/fcm-token', 'Профиль', 'Сохранить FCM-токен для push', { body: json({ type: 'object', properties: { fcm_token: { type: 'string' } } }) });

// ------------------------------------------------------------------ catalog
op('get', '/api/home', 'Каталог', 'Главная: подборки, категории, авторы', { auth: 'optional' });
op('get', '/api/books', 'Каталог', 'Поиск и фильтры', {
  auth: 'optional',
  params: [
    qp('q', 'Поиск по названию, автору, описанию'),
    qp('category_id', 'Категория', { type: 'integer' }),
    qp('author_user_id', 'Книги автора', { type: 'integer' }),
    qp('is_free', 'true — бесплатные, false — платные', { type: 'boolean' }),
    qp('sort', 'Сортировка', { type: 'string', enum: ['new', 'popular', 'rating', 'price_asc', 'price_desc', 'title'] }),
    qp('page', 'Страница', { type: 'integer', default: 1 }),
    qp('limit', 'На странице (до 100)', { type: 'integer', default: 30 }),
  ],
});
op('get', '/api/categories', 'Каталог', 'Категории', { auth: false });
op('get', '/api/books/{id}', 'Каталог', 'Страница книги (+ отзывы, другие книги автора, похожие)', { auth: 'optional', params: [id()], responses: { 200: ok(ref('Book')) } });
op('get', '/api/books/{id}/reviews', 'Каталог', 'Отзывы', { auth: false, params: [id()] });
op('post', '/api/books/{id}/reviews', 'Каталог', 'Оставить/изменить отзыв (книга должна быть в библиотеке)', { params: [id()], body: json({ type: 'object', properties: { rating: { type: 'integer', minimum: 1, maximum: 5 }, text: { type: 'string' } } }, { rating: 5, text: 'Juda foydali kitob!' }) });
op('delete', '/api/books/{id}/reviews', 'Каталог', 'Удалить свой отзыв', { params: [id()] });
op('get', '/api/authors/{userId}', 'Каталог', 'Публичная страница автора', { auth: 'optional', params: [id('userId', 'ID пользователя-автора')] });

op('get', '/api/me/library', 'Библиотека', 'Мои книги (купленные и бесплатные)');
op('post', '/api/books/{id}/get', 'Библиотека', 'Добавить бесплатную книгу в библиотеку', { params: [id()] });
op('delete', '/api/me/library/{id}', 'Библиотека', 'Убрать бесплатную книгу из библиотеки', { params: [id()] });
op('post', '/api/books/{id}/favorite', 'Библиотека', 'В избранное / убрать', { params: [id()] });
op('get', '/api/me/favorites', 'Библиотека', 'Избранное');

// ------------------------------------------------------------------ reading
op('get', '/api/books/{id}/preview.js', 'Чтение', 'Ознакомительный фрагмент (~15% книги), без авторизации', { auth: false, params: [id()] });
op('get', '/api/books/{id}/package.zip', 'Чтение', 'Пакет книги для офлайн-чтения в приложении', { params: [id()], description: 'Заголовок X-Package-Version — версия; если больше сохранённой, книгу нужно перекачать.' });
op('get', '/api/books/{id}/epub', 'Чтение', 'Скачать EPUB', { params: [id()] });
op('get', '/api/books/{id}/read-token', 'Чтение', 'Ссылка для чтения в браузере', { params: [id()] });
op('get', '/api/books/{id}/reading', 'Чтение', 'Позиция, закладки, выделения', { params: [id()] });
op('put', '/api/books/{id}/reading', 'Чтение', 'Сохранить позицию/закладки/выделения', { params: [id()], body: json({ type: 'object', properties: { position: { type: 'object' }, percent: { type: 'number' }, bookmarks: { type: 'array', items: {} }, highlights: { type: 'array', items: {} }, updatedAt: { type: 'integer' } } }) });

// ------------------------------------------------------------------ orders
op('get', '/api/payments/methods', 'Оплата', 'Доступные способы оплаты', { auth: false });
op('post', '/api/orders', 'Оплата', 'Создать заказ на платную книгу → ссылки Payme/Click', {
  body: json({ type: 'object', required: ['book_id'], properties: { book_id: { type: 'integer' } } }, { book_id: 1 }),
  responses: { 201: ok(ref('Order'), 'Заказ') },
});
op('get', '/api/orders/{id}', 'Оплата', 'Статус заказа (приложение опрашивает после возврата из Payme/Click)', { params: [id()], responses: { 200: ok(ref('Order')) } });
op('post', '/api/orders/{id}/demo-pay', 'Оплата', 'Демо-оплата (PAYMENTS_DEMO=true)', { params: [id()] });
op('get', '/api/me/orders', 'Оплата', 'История покупок');
op('post', '/api/payments/payme', 'Оплата (callbacks)', 'Payme Merchant API (JSON-RPC, Basic Paycom:KEY)', { auth: false, description: 'Вызывает Payme. Методы: CheckPerformTransaction, CreateTransaction, PerformTransaction, CancelTransaction, CheckTransaction, GetStatement. Поле счёта: order_id. Сумма в тийинах.' });
op('post', '/api/payments/click/prepare', 'Оплата (callbacks)', 'Click SHOP API — Prepare', { auth: false, description: 'Вызывает Click (application/x-www-form-urlencoded). merchant_trans_id = ID заказа.' });
op('post', '/api/payments/click/complete', 'Оплата (callbacks)', 'Click SHOP API — Complete', { auth: false });

// ------------------------------------------------------------------ studio
op('get', '/api/studio/rules', 'Кабинет автора', 'Условия: комиссия, минимум выплаты, форматы', { auth: false });
op('get', '/api/studio/profile', 'Кабинет автора', 'Мой профиль автора');
op('put', '/api/studio/profile', 'Кабинет автора', 'Стать автором / обновить профиль', {
  description: 'Первый вызов создаёт профиль (нужно accept_terms=true). Смена карты сбрасывает её подтверждение.',
  body: multipart({ display_name: { type: 'string' }, bio: { type: 'string' }, card_number: { type: 'string', example: '8600 1234 5678 9012' }, card_holder: { type: 'string' }, accept_terms: { type: 'boolean' }, photo: file('Фото') }),
});
op('get', '/api/studio/dashboard', 'Кабинет автора', 'Сводка: баланс, продажи, по месяцам');
op('get', '/api/studio/earnings', 'Кабинет автора', 'Начисления по продажам');
op('get', '/api/studio/payouts', 'Кабинет автора', 'Выплаты');
op('get', '/api/studio/books', 'Кабинет автора', 'Мои книги со статусами модерации');
op('post', '/api/studio/books', 'Кабинет автора', 'Загрузить книгу (Word/EPUB) → конвертация → модерация', {
  body: multipart({
    file: file('.docx .doc .epub .txt .rtf .odt'),
    cover: file('Обложка JPG/PNG'),
    title: { type: 'string', description: 'Пусто — возьмётся с титульного листа' },
    author_name: { type: 'string' },
    description: { type: 'string' },
    category_id: { type: 'integer' },
    is_free: { type: 'boolean' },
    price: { type: 'integer', description: "so'm, от 1000" },
  }, ['file']),
});
op('get', '/api/studio/books/{id}', 'Кабинет автора', 'Книга + продажи по месяцам', { params: [id()] });
op('put', '/api/studio/books/{id}', 'Кабинет автора', 'Изменить (новый файл/название → снова модерация)', { params: [id()], body: multipart({ title: { type: 'string' }, description: { type: 'string' }, price: { type: 'integer' }, is_free: { type: 'boolean' }, category_id: { type: 'integer' }, file: file('Новый файл'), cover: file('Новая обложка') }) });
op('post', '/api/studio/books/{id}/unpublish', 'Кабинет автора', 'Скрыть из магазина', { params: [id()] });
op('post', '/api/studio/books/{id}/publish', 'Кабинет автора', 'Вернуть в магазин', { params: [id()] });
op('delete', '/api/studio/books/{id}', 'Кабинет автора', 'Удалить (если нет покупок)', { params: [id()] });

// ------------------------------------------------------------------ admin
const A = 'Администрирование';
op('get', '/api/admin/stats', A, 'Сводка платформы');
op('get', '/api/admin/books', A, 'Книги / очередь модерации', { params: [qp('status', 'pending — очередь модерации', { type: 'string', enum: ['pending', 'approved', 'rejected', 'unpublished', 'draft'] }), qp('q', 'Поиск')] });
op('get', '/api/admin/books/{id}', A, 'Книга + профиль автора + отчёт конвертации', { params: [id()] });
op('post', '/api/admin/books/{id}/approve', A, 'Одобрить и опубликовать', { params: [id()] });
op('post', '/api/admin/books/{id}/reject', A, 'Отклонить с причиной', { params: [id()], body: json({ type: 'object', required: ['reason'], properties: { reason: { type: 'string' } } }, { reason: "Muqova sifati past. Iltimos, yuqori sifatli rasm yuklang." }) });
op('post', '/api/admin/books/{id}/unpublish', A, 'Снять с продажи', { params: [id()], body: json({ type: 'object', properties: { reason: { type: 'string' } } }) });
op('put', '/api/admin/books/{id}', A, 'Изменить цену/категорию', { params: [id()], body: json({ type: 'object', properties: { price: { type: 'integer' }, is_free: { type: 'boolean' }, category_id: { type: 'integer' } } }) });
op('post', '/api/admin/books/{id}/reconvert', A, 'Переконвертировать', { params: [id()] });
op('post', '/api/admin/books/{id}/grant', A, 'Подарить книгу пользователю', { params: [id()], body: json({ type: 'object', properties: { phone: { type: 'string' } } }) });
op('delete', '/api/admin/books/{id}', A, 'Удалить книгу', { params: [id()] });
op('get', '/api/admin/authors', A, 'Авторы (с балансом)', { params: [qp('unverified', 'Только с неподтверждённой картой', { type: 'boolean' }), qp('q', 'Поиск')] });
op('put', '/api/admin/authors/{userId}', A, 'Подтвердить карту / заблокировать', { params: [id('userId')], body: json({ type: 'object', properties: { card_verified: { type: 'boolean' }, status: { type: 'string', enum: ['active', 'blocked'] }, admin_note: { type: 'string' } } }) });
op('get', '/api/admin/orders', A, 'Заказы', { params: [qp('status', 'paid | created | cancelled | refunded')] });
op('post', '/api/admin/orders/{id}/mark-paid', A, 'Отметить заказ оплаченным вручную', { params: [id()] });
op('get', '/api/admin/payouts', A, 'Выплаты + накопленные суммы авторов');
op('post', '/api/admin/payouts/generate', A, 'Сформировать выплаты за месяц', { description: 'Всё, что заработано до указанного месяца включительно и ещё не выплачено, превращается в выплаты — если карта автора подтверждена и сумма ≥ payout_min. Иначе переносится.', body: json({ type: 'object', properties: { period: { type: 'string', example: '2026-10' } } }) });
op('post', '/api/admin/payouts/{id}/mark-paid', A, 'Отметить выплату переведённой', { params: [id()], body: json({ type: 'object', properties: { reference: { type: 'string' } } }) });
op('get', '/api/admin/settings', A, 'Настройки платформы');
op('put', '/api/admin/settings', A, 'Изменить комиссию / минимум выплаты', { body: json({ type: 'object', properties: { commission_percent: { type: 'number' }, payout_min: { type: 'integer' }, support_phone: { type: 'string' }, support_telegram: { type: 'string' } } }, { commission_percent: 30, payout_min: 50000 }) });
op('post', '/api/admin/categories', A, 'Создать категорию', { body: json({ type: 'object', properties: { name_uz: { type: 'string' }, name_ru: { type: 'string' }, name_en: { type: 'string' } } }) });
op('put', '/api/admin/categories/{id}', A, 'Изменить категорию', { params: [id()] });
op('delete', '/api/admin/categories/{id}', A, 'Удалить категорию', { params: [id()] });
op('get', '/api/admin/users', A, 'Пользователи', { params: [qp('q', 'Имя или телефон')] });
op('put', '/api/admin/users/{id}', A, 'Роль / блокировка / пароль для веб-панели', { params: [id()], body: json({ type: 'object', properties: { role_id: { type: 'integer', enum: [1, 2] }, is_blocked: { type: 'boolean' }, password: { type: 'string' } } }) });

module.exports = () => ({
  openapi: '3.0.3',
  info: {
    title: `${config.platform.name} API`,
    version: '2.0.0',
    description:
      'Открытая платформа электронных книг. Любой пользователь может стать автором, загрузить книгу (Word/EPUB), пройти модерацию и получать ежемесячные выплаты за продажи за вычетом комиссии платформы.\n\n' +
      '**Как проверить:** 1) `POST /api/auth/request-otp` 2) `POST /api/auth/verify` с кодом `111111` (разработка) 3) скопируйте `accessToken` → кнопка **Authorize**.\n\n' +
      'Админ: номер `+998 90 096 17 04`.',
  },
  servers: [{ url: config.publicUrl || '/' }],
  tags: [
    { name: 'Авторизация' }, { name: 'Профиль' }, { name: 'Каталог' }, { name: 'Библиотека' }, { name: 'Чтение' },
    { name: 'Оплата' }, { name: 'Оплата (callbacks)' }, { name: 'Кабинет автора' }, { name: 'Администрирование' },
  ],
  paths,
  components: {
    securitySchemes: { bearer: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } },
    schemas: {
      Session: { type: 'object', properties: { accessToken: { type: 'string' }, refreshToken: { type: 'string' }, user: ref('Me') } },
      Me: {
        type: 'object',
        properties: {
          id: { type: 'integer' }, name: { type: 'string' }, phone: { type: 'string' }, role_id: { type: 'integer', description: '1 — админ, 2 — пользователь' },
          is_admin: { type: 'boolean' }, is_author: { type: 'boolean' }, author: { type: 'object', nullable: true }, unread_notifications: { type: 'integer' }, needs_name: { type: 'boolean' },
        },
      },
      Book: {
        type: 'object',
        properties: {
          id: { type: 'integer' }, title: { type: 'string' }, author_name: { type: 'string' }, description: { type: 'string' },
          price: { type: 'integer' }, is_free: { type: 'boolean' }, photo: { type: 'string', nullable: true }, rating: { type: 'number' }, rating_count: { type: 'integer' },
          sales_count: { type: 'integer' }, chapters: { type: 'integer' }, words: { type: 'integer' }, reading_minutes: { type: 'integer' }, status: { type: 'string' },
          package_version: { type: 'integer' }, has_access: { type: 'boolean' }, in_library: { type: 'boolean' }, is_favorite: { type: 'boolean' }, progress: { type: 'number' },
        },
      },
      Order: {
        type: 'object',
        properties: {
          id: { type: 'integer' }, book_id: { type: 'integer' }, amount: { type: 'integer' }, status: { type: 'string', enum: ['created', 'paid', 'cancelled', 'refunded'] },
          checkout: { type: 'object', properties: { payme: { type: 'string' }, click: { type: 'string' } } }, demo: { type: 'boolean' },
        },
      },
    },
  },
});
