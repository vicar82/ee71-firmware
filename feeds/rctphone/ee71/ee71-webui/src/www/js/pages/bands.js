;(function() {
    'use strict';
    var $ = App.$, escHtml = App.escHtml, t = App.t;

    // Диапазоны аппаратного набора EU (EE71).
    var BANDS = [
        { n: 1,  name: 'B1 (2100)' },
        { n: 3,  name: 'B3 (1800)' },
        { n: 7,  name: 'B7 (2600)' },
        { n: 8,  name: 'B8 (900)' },
        { n: 20, name: 'B20 (800)' },
        { n: 28, name: 'B28 (700)' },
        { n: 38, name: 'B38 (2600 TDD)' },
        { n: 40, name: 'B40 (2300 TDD)' }
    ];
    var AUTO_MASK = 'ffffffffffff';

    var _mask = null;   // 64 символа '0'/'1', старший бит слева

    function _maskToHex(maskStr) {
        var hex = '';
        for (var i = 0; i < 64; i += 4) {
            hex += parseInt(maskStr.substr(i, 4), 2).toString(16);
        }
        return hex.replace(/^0+/, '') || '0';
    }

    function _hexToMask(hex) {
        hex = (hex || '').toLowerCase().replace(/^0x/, '').replace(/^0+/, '');
        while (hex.length < 16) hex = '0' + hex;
        if (hex.length > 16) hex = hex.substr(hex.length - 16);
        var bits = '';
        for (var i = 0; i < 16; i++) {
            var b = parseInt(hex[i], 16);
            bits += ((b >> 3) & 1) + '' + ((b >> 2) & 1) + '' + ((b >> 1) & 1) + '' + (b & 1);
        }
        return bits;
    }

    function _bit(mask, band) { return mask.charAt(64 - band) === '1'; }

    function _setBit(mask, band, on) {
        var i = 64 - band;
        return mask.substr(0, i) + (on ? '1' : '0') + mask.substr(i + 1);
    }

    function _currentMask() {
        var m = _hexToMask('0');
        document.querySelectorAll('.band-cb').forEach(function(cb) {
            m = _setBit(m, parseInt(cb.dataset.band, 10), cb.checked);
        });
        return m;
    }

    function _applyMaskToCheckboxes(mask) {
        document.querySelectorAll('.band-cb').forEach(function(cb) {
            cb.checked = _bit(mask, parseInt(cb.dataset.band, 10));
        });
    }

    function _status(msg, isErr) {
        var el = $('#bands-status');
        if (!el) return;
        el.textContent = msg || '';
        el.style.color = isErr ? '#c0392b' : '#2e7d32';
    }

    function renderBands(container) {
        // Честная версия: кастомная блокировка диапазонов на этой прошивке
        // недостижима — набор диапазонов поставляет карьерный конфиг модема
        // (mcfg autoselect по ICCID) и перезаписывает любые записи при загрузке.
        // Страница показывает РЕАЛЬНО используемые диапазоны из данных кэмпинга.
        container.innerHTML =
            '<div class="card">' +
                '<h3>' + escHtml(t('bands.title')) + '</h3>' +
                '<p class="page-hint">Кастомная блокировка диапазонов недоступна: набор LTE-диапазонов управляется конфигурацией оператора (mcfg) и перезаписывается при каждой загрузке модема. Ниже — реально используемые диапазоны.</p>' +
                '<div class="stat-row"><span class="label">Используются сейчас</span>' +
                '<span class="value" id="bands-current">…</span></div>' +
                '<div class="stat-row"><span class="label">Агрегация (CA)</span>' +
                '<span class="value" id="bands-ca">…</span></div>' +
                '<div class="stat-row"><span class="label">Все ячейки</span>' +
                '<span class="value text-small" id="bands-cells" style="word-break:break-all">…</span></div>' +
                '<div style="margin-top:.75rem;display:flex;gap:.5rem">' +
                    '<button class="btn-outline" data-action="bandsRead">Обновить</button>' +
                '</div>' +
                '<div id="bands-status" style="margin-top:.75rem;font-size:.9rem"></div>' +
            '</div>';

        _read();
    }

    function _read() {
        $('#bands-current').textContent = '…';
        $('#bands-ca').textContent = '…';
        $('#bands-cells').textContent = '…';
        _status('');
        API.cgiGet('bandpref.cgi', { action: 'get' }).then(function(r) {
            if (!r || !r.ok) throw new Error((r && r.error) || 'get failed');
            var names = (r.live || []).map(function(b) { return 'B' + b; });
            $('#bands-current').textContent = names.length ? names.join(', ') : 'нет данных';
            $('#bands-ca').textContent = r.ca ? 'активна (' + (r.cells || 1) + ' несущих)' : 'нет';
            $('#bands-cells').textContent = (r.cells_list || []).map(function(c) {
                return (c.type === 'pcc' ? 'PCC ' : 'SCC ') + 'B' + c.band + ' (RSRP ' + (c.rsrp != null ? c.rsrp.toFixed(1) : '?') + ' dBm)';
            }).join(' · ') || '—';
        }).catch(function(e) {
            $('#bands-current').textContent = App.errorText(e);
        });
    }

    function _all() { _read(); }

    function _apply() {
        _status('Блокировка диапазонов недоступна: набор управляется конфигурацией оператора (mcfg).', true);
    }

    App.registerPage('bands', renderBands);
    App._bandsRead = _read;
    App._bandsAll = _all;
    App._bandsApply = _apply;
})();
