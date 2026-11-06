/**
 * i18n.js — минимальный слой локализации (ru/en).
 *
 * Словари покрывают навигацию и затронутые страницы (dashboard, login,
 * at-terminal, ussd, bands, common). Страницы, не переведённые явно,
 * продолжают показывать английские строки — fallback на ключ.
 *
 * API:
 *   I18n.t('nav.dashboard')        — перевод
 *   I18n.locale()                  — текущая локаль
 *   I18n.setLocale('ru'|'en')      — переключить (сохраняет в localStorage)
 *   App.t(...)                     — алиас, доступен после загрузки модуля
 */
;(function() {
    'use strict';

    var DICTS = {
        en: {
            'nav.status': 'STATUS', 'nav.mobile': 'MOBILE', 'nav.network': 'NETWORK', 'nav.system': 'SYSTEM',
            'nav.dashboard': 'Dashboard', 'nav.clients': 'Clients', 'nav.connection': 'Connection',
            'nav.apn': 'APN', 'nav.at-terminal': 'AT Terminal', 'nav.mobile-settings': 'Settings',
            'nav.sms': 'SMS', 'nav.ussd': 'USSD', 'nav.bands': 'Bands', 'nav.wifi': 'WiFi',
            'nav.lan': 'LAN', 'nav.firewall': 'Firewall', 'nav.upnp': 'UPnP', 'nav.ttl-fix': 'TTL Fix',
            'nav.vpn': 'VPN', 'nav.diagnostics': 'Diagnostics', 'nav.speedtest': 'Speed Test',
            'nav.settings': 'Settings', 'nav.ssh': 'SSH', 'nav.backup': 'Backup', 'nav.about': 'About',

            'login.title': 'Sign in', 'login.password': 'Password', 'login.submit': 'Sign in',
            'login.error': 'Wrong password',

            'common.save': 'Save', 'common.apply': 'Apply', 'common.cancel': 'Cancel',
            'common.close': 'Close', 'common.send': 'Send', 'common.loading': 'Loading…',
            'common.error': 'Error', 'common.refresh': 'Refresh', 'common.enabled': 'Enabled',
            'common.disabled': 'Disabled', 'common.on': 'On', 'common.off': 'Off',
            'common.confirm': 'Are you sure?',

            'dash.operator': 'Operator', 'dash.technology': 'Technology', 'dash.signal': 'Signal',
            'dash.band': 'Band', 'dash.connection': 'Connection', 'dash.uptime': 'Uptime',
            'dash.clients': 'Clients', 'dash.traffic': 'Traffic', 'dash.ca.title': 'Carrier Aggregation',
            'dash.ca.none': 'No aggregation — single carrier',
            'dash.ca.cell': 'Cell', 'dash.ca.earfcn': 'EARFCN', 'dash.ca.band': 'Band',
            'dash.ca.pci': 'PCI', 'dash.ca.rsrp': 'RSRP', 'dash.sig-history': 'Signal history (5 min)',

            'at.quick': 'Quick commands', 'at.quick.signal': 'Signal', 'at.quick.cells': 'Cells',
            'at.quick.ca': 'CA info', 'at.quick.bands': 'Band pref', 'at.quick.reg': 'Registration',

            'ussd.title': 'USSD requests', 'ussd.hint': 'Balance and service codes straight to the modem.',
            'ussd.input': 'USSD code', 'ussd.send': 'Send', 'ussd.response': 'Response',
            'ussd.balance': 'Balance', 'ussd.traffic': 'Traffic left', 'ussd.number': 'My number',

            'bands.title': 'LTE band lock',
            'bands.hint': 'Which LTE bands the modem may use. Applied via AT$QCBANDPREF and kept in modem NV. Wrong lock can drop service — "All bands" always recovers.',
            'bands.read': 'Read current', 'bands.lock': 'Apply lock', 'bands.all': 'All bands',
            'bands.current': 'Current preference', 'bands.select': 'Allowed bands',
            'bands.command': 'Command to send', 'bands.custom': 'Custom AT command',
            'bands.warn': 'Band lock will be applied immediately. If the selected bands have no coverage, the device loses service until you revert to "All bands". Continue?'
        },
        ru: {
            'nav.status': 'СТАТУС', 'nav.mobile': 'СОТОВАЯ СЕТЬ', 'nav.network': 'СЕТЬ', 'nav.system': 'СИСТЕМА',
            'nav.dashboard': 'Дашборд', 'nav.clients': 'Клиенты', 'nav.connection': 'Соединение',
            'nav.apn': 'APN', 'nav.at-terminal': 'AT-терминал', 'nav.mobile-settings': 'Настройки',
            'nav.sms': 'SMS', 'nav.ussd': 'USSD', 'nav.bands': 'Диапазоны', 'nav.wifi': 'WiFi',
            'nav.lan': 'LAN', 'nav.firewall': 'Файрвол', 'nav.upnp': 'UPnP', 'nav.ttl-fix': 'TTL-фикс',
            'nav.vpn': 'VPN', 'nav.diagnostics': 'Диагностика', 'nav.speedtest': 'Тест скорости',
            'nav.settings': 'Настройки', 'nav.ssh': 'SSH', 'nav.backup': 'Бэкап', 'nav.about': 'О программе',

            'login.title': 'Вход', 'login.password': 'Пароль', 'login.submit': 'Войти',
            'login.error': 'Неверный пароль',

            'common.save': 'Сохранить', 'common.apply': 'Применить', 'common.cancel': 'Отмена',
            'common.close': 'Закрыть', 'common.send': 'Отправить', 'common.loading': 'Загрузка…',
            'common.error': 'Ошибка', 'common.refresh': 'Обновить', 'common.enabled': 'Включено',
            'common.disabled': 'Выключено', 'common.on': 'Вкл', 'common.off': 'Выкл',
            'common.confirm': 'Вы уверены?',

            'dash.operator': 'Оператор', 'dash.technology': 'Технология', 'dash.signal': 'Сигнал',
            'dash.band': 'Диапазон', 'dash.connection': 'Соединение', 'dash.uptime': 'Аптайм',
            'dash.clients': 'Клиенты', 'dash.traffic': 'Трафик', 'dash.ca.title': 'Агрегация несущих (CA)',
            'dash.ca.none': 'Агрегации нет — одна несущая',
            'dash.ca.cell': 'Ячейка', 'dash.ca.earfcn': 'EARFCN', 'dash.ca.band': 'Диапазон',
            'dash.ca.pci': 'PCI', 'dash.ca.rsrp': 'RSRP', 'dash.sig-history': 'История сигнала (5 мин)',

            'at.quick': 'Быстрые команды', 'at.quick.signal': 'Сигнал', 'at.quick.cells': 'Ячейки',
            'at.quick.ca': 'Инфо CA', 'at.quick.bands': 'Диапазоны', 'at.quick.reg': 'Регистрация',

            'ussd.title': 'USSD-запросы', 'ussd.hint': 'Баланс и сервисные коды — напрямую через модем.',
            'ussd.input': 'USSD-код', 'ussd.send': 'Отправить', 'ussd.response': 'Ответ',
            'ussd.balance': 'Баланс', 'ussd.traffic': 'Остаток трафика', 'ussd.number': 'Мой номер',

            'bands.title': 'Блокировка LTE-диапазонов',
            'bands.hint': 'Какие диапазоны LTE разрешено использовать модему. Применяется через AT$QCBANDPREF и хранится в NV модема. Ошибочная блокировка отрубит связь — «Все диапазоны» всегда лечит.',
            'bands.read': 'Прочитать текущее', 'bands.lock': 'Применить блокировку', 'bands.all': 'Все диапазоны',
            'bands.current': 'Текущие предпочтения', 'bands.select': 'Разрешённые диапазоны',
            'bands.command': 'Команда к отправке', 'bands.custom': 'Своя AT-команда',
            'bands.warn': 'Блокировка применится сразу. Если выбранные диапазоны не ловятся в вашей зоне, связь пропадёт, пока не вернёте «Все диапазоны». Продолжить?'
        }
    };

    var _locale = localStorage.getItem('ee71-lang');
    if (!_locale) {
        var nav = (navigator.language || navigator.userLanguage || 'en').toLowerCase();
        _locale = nav.indexOf('ru') === 0 ? 'ru' : 'en';
    }

    function t(key) {
        var d = DICTS[_locale] || {};
        if (Object.prototype.hasOwnProperty.call(d, key)) return d[key];
        return Object.prototype.hasOwnProperty.call(DICTS.en, key) ? DICTS.en[key] : key;
    }

    function setLocale(l) {
        if (l !== 'ru' && l !== 'en') return;
        _locale = l;
        localStorage.setItem('ee71-lang', l);
        document.documentElement.setAttribute('lang', l);
    }

    function toggle() { setLocale(_locale === 'ru' ? 'en' : 'ru'); }

    document.documentElement.setAttribute('lang', _locale);

    window.I18n = { t: t, setLocale: setLocale, toggle: toggle, locale: function() { return _locale; } };
    // Алиас для страниц
    if (window.App) window.App.t = t;
})();
