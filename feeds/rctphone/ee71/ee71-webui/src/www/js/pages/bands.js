;(function() {
    'use strict';
    var $ = App.$, escHtml = App.escHtml, actionAttr = App.actionAttr, t = App.t;

    // Диапазоны, доступные на EE71 (B1/B3/B7/B8/B20 — аппаратный набор EU).
    // Маска — 64-битная, бит (band-1) = 1.
    var BANDS = [
        { n: 1,  name: 'B1 (2100)' },
        { n: 3,  name: 'B3 (1800)' },
        { n: 7,  name: 'B7 (2600)' },
        { n: 8,  name: 'B8 (900)' },
        { n: 20, name: 'B20 (800)' }
    ];

    var _mask = null;   // BigInt нет в старых WebKit — работаем строками hex
    var _raw = '';

    function _maskToHex(maskStr) {
        // maskStr: строка из 64 '0'/'1', старший бит слева → 16 hex
        var hex = '';
        for (var i = 0; i < 64; i += 4) {
            hex += parseInt(maskStr.substr(i, 4), 2).toString(16);
        }
        return hex;
    }

    function _hexToMask(hex) {
        hex = (hex || '').toLowerCase().replace(/^0x/, '');
        while (hex.length < 16) hex = '0' + hex;
        if (hex.length > 16) hex = hex.substr(hex.length - 16);
        var bits = '';
        for (var i = 0; i < 16; i++) {
            var b = parseInt(hex[i], 16);
            bits += ((b >> 3) & 1) + '' + ((b >> 2) & 1) + '' + ((b >> 1) & 1) + '' + (b & 1);
        }
        return bits; // 64 символа, старший бит слева; band n = bits[64-n]
    }

    function _bit(mask, band) { return mask.charAt(64 - band) === '1'; }

    function _setBit(mask, band, on) {
        var i = 64 - band;
        return mask.substr(0, i) + (on ? '1' : '0') + mask.substr(i + 1);
    }

    function renderBands(container) {
        var boxes = BANDS.map(function(b) {
            return '<label style="display:inline-flex;align-items:center;gap:.35rem;margin-right:1rem">' +
                '<input type="checkbox" class="band-cb" data-band="' + b.n + '"> ' + escHtml(b.name) + '</label>';
        }).join('');

        container.innerHTML =
            '<div class="card">' +
                '<h3>' + escHtml(t('bands.title')) + '</h3>' +
                '<p class="page-hint">' + escHtml(t('bands.hint')) + '</p>' +
                '<div style="margin-bottom:1rem;display:flex;gap:.5rem;flex-wrap:wrap">' +
                    '<button class="btn-outline" data-action="bandsRead">' + escHtml(t('bands.read')) + '</button>' +
                    '<button class="btn-outline" data-action="bandsAll">' + escHtml(t('bands.all')) + '</button>' +
                '</div>' +
                '<div class="stat-row"><span class="label">' + escHtml(t('bands.current')) + '</span>' +
                '<span class="value" id="bands-current">—</span></div>' +
                '<div style="margin:1rem 0 .5rem"><span class="label">' + escHtml(t('bands.select')) + ':</span></div>' +
                '<div id="bands-boxes">' + boxes + '</div>' +
                '<div class="stat-row" style="margin-top:1rem"><span class="label">' + escHtml(t('bands.command')) + '</span>' +
                '<code class="value" id="bands-cmd" style="word-break:break-all">—</code></div>' +
                '<div style="margin-top:1rem;display:flex;gap:.5rem;flex-wrap:wrap">' +
                    '<button class="btn-primary" data-action="bandsApply">' + escHtml(t('bands.lock')) + '</button>' +
                '</div>' +
                '<div style="margin-top:1.5rem">' +
                    '<div class="stat-row"><span class="label">' + escHtml(t('bands.custom')) + '</span></div>' +
                    '<div style="display:flex;gap:.5rem;margin-top:.5rem">' +
                        '<input type="text" id="bands-custom" style="flex:1" placeholder="AT$QCBANDPREF=...">' +
                        '<button class="btn-outline" data-action="bandsCustom">' + escHtml(t('common.send')) + '</button>' +
                    '</div>' +
                    '<pre id="bands-custom-out" style="margin-top:.5rem;white-space:pre-wrap"></pre>' +
                '</div>' +
                '<pre id="bands-out" style="margin-top:1rem;white-space:pre-wrap"></pre>' +
            '</div>';

        $('#bands-boxes').addEventListener('change', _updateCmd);
        _read();
    }

    function _updateCmd() {
        var mask = _currentMask();
        $('#bands-cmd').textContent = mask ? '0x' + _maskToHex(mask) : '—';
    }

    function _currentMask() {
        var m = null;
        var cbs = document.querySelectorAll('.band-cb');
        cbs.forEach(function(cb) {
            var band = parseInt(cb.dataset.band, 10);
            if (m === null) m = _mask || _hexToMask('0');
            m = _setBit(m, band, cb.checked);
        });
        return m;
    }

    function _applyMaskToCheckboxes(mask) {
        document.querySelectorAll('.band-cb').forEach(function(cb) {
            cb.checked = _bit(mask, parseInt(cb.dataset.band, 10));
        });
    }

    function _read() {
        $('#bands-current').textContent = '…';
        API.cgiGet('bandpref.cgi', { action: 'get' }).then(function(r) {
            var out = (r && r.mask) || '';
            $('#bands-out').textContent = 'QMI NAS Get System Selection Preference -> LTE band mask: 0x' + out;
            var mask = _hexToMask(out);
            if (mask) {
                _mask = mask;
                _applyMaskToCheckboxes(mask);
                var hex = _maskToHex(mask);
                $('#bands-current').textContent = (hex === '0000000000000000' ? t('bands.allUnrestricted') : '0x' + hex);
            } else {
                $('#bands-current').textContent = '(unparsed — see raw below)';
            }
            _updateCmd();
        }).catch(function(e) {
            $('#bands-current').textContent = App.errorText(e);
        });
    }

    function _apply() {
        var mask = _currentMask();
        if (!mask) return;
        var hex = _maskToHex(mask);
        // confirmDialog — колбэковый API: (message, onYes, onNo, opts).
        App.confirmDialog(t('bands.warn'), function() {
            $('#bands-out').textContent = '> QMI set LTE band mask 0x' + hex + '\n…';
            API.cgiGet('bandpref.cgi', { action: 'set', mask: hex }).then(function(r) {
                if (r && r.ok) {
                    $('#bands-out').textContent = '> QMI set LTE band mask 0x' + hex + '\nOK';
                } else {
                    $('#bands-out').textContent = '> QMI set LTE band mask 0x' + hex + '\nERROR: ' + ((r && r.error) || 'unknown');
                }
                _read();
            }).catch(function(e) {
                $('#bands-out').textContent = '> QMI set LTE band mask 0x' + hex + '\nERROR: ' + App.errorText(e);
            });
        }, null, { danger: true, confirmText: t('bands.lock') });
    }

    function _custom() {
        var cmd = ($('#bands-custom') || {}).value || '';
        if (!cmd) return;
        API.cgiPost('at.cgi', { action: 'send', cmd: cmd }).then(function(r) {
            $('#bands-custom-out').textContent = ((r && r.output) || '(no response)');
        }).catch(function(e) {
            $('#bands-custom-out').textContent = 'ERROR: ' + App.errorText(e);
        });
    }

    App.registerPage('bands', renderBands);
    App._bandsRead = function() { _read(); };
    App._bandsAll = function() {
        var mask = _hexToMask('ffffffffffffffff');
        _mask = mask;
        _applyMaskToCheckboxes(mask);
        _updateCmd();
    };
    App._bandsApply = function() { _apply(); };
    App._bandsCustom = function() { _custom(); };
})();
